import Foundation
import LatticeCore
import MultipeerConnectivity

/// Live Nearby duel over MultipeerConnectivity — host-advertises model,
/// 2–8 players, both `DuelMode`s. Runs a pure `DuelMatch` over the session,
/// marshalling `DuelMessage`s and owning the per-player reactive clock timers
/// (the match stays pure — it only knows a clock is running or not).
///
/// Roles:
/// - **Host** configures a game (`host(config:)`), advertises it with the
///   config in `discoveryInfo`, receives join requests it shows accept/decline
///   for, and on `startMatch()` broadcasts `start` with the roster.
/// - **Guest** browses advertised games, taps one (`join(_:)`), connects,
///   requests to join, and waits for `start`.
///
/// Players trust each other (face-to-face) — no anti-cheat; only scores and
/// moves cross the wire, never a replicated board.
@MainActor
final class NearbyMatch: NSObject, ObservableObject {
    enum Role: Equatable {
        case idle
        case hosting
        case joining(MCPeerID)
    }

    /// A game another device is advertising, parsed from its discoveryInfo.
    struct AdvertisedGame: Identifiable, Equatable {
        let peer: MCPeerID
        let hostName: String
        let mode: DuelMode
        let variantKey: String
        var id: MCPeerID { peer }

        var label: String {
            switch mode {
            case .lockStep: return "\(hostName) — Lock-step \(variantKey)"
            case .race(let tier): return "\(hostName) — Race to \(tier), \(variantKey)"
            }
        }
    }

    /// The host's pending join requests, awaiting accept/decline.
    struct JoinRequest: Identifiable, Equatable {
        let peer: MCPeerID
        let name: String
        var id: MCPeerID { peer }
    }

    /// A final-standings row. In race, finishers rank by `reachTime` (seconds
    /// from match start to the target, host-timed); non-finishers have nil time
    /// and rank below by `score` (moves). Lock-step uses `score` only.
    struct Standing: Equatable {
        let name: String
        let score: Int
        var reachTime: TimeInterval?

        /// Wire form (ms) for broadcasting; and back.
        var wire: DuelMessage.ResultRow {
            .init(name: name, score: score, reachMillis: reachTime.map { Int($0 * 1000) })
        }
        init(name: String, score: Int, reachTime: TimeInterval? = nil) {
            self.name = name
            self.score = score
            self.reachTime = reachTime
        }
        init(_ row: DuelMessage.ResultRow) {
            name = row.name
            score = row.score
            reachTime = row.reachMillis.map { TimeInterval($0) / 1000 }
        }
    }

    enum Stage: Equatable {
        case lobby
        case waitingForHost  // guest: requested, waiting for start
        case dueling
        case finished(standings: [Standing])  // by score, highest first
        case hostLeft  // guest: the host disconnected — no result to await
    }

    // Lobby state. Setters are internal (not private) where the delegate
    // conformances in NearbyMatch+Delegates.swift mutate them.
    @Published private(set) var role: Role = .idle
    // Non-private set: mutated by the delegate conformances in the +Delegates
    // file (same module; a `final` class's internal members aren't public API).
    @Published var games: [AdvertisedGame] = []
    @Published var joinRequests: [JoinRequest] = []
    /// Accepted players in the host's lobby (display names), self first.
    @Published var lobbyNames: [String] = []

    // Match state
    @Published var stage: Stage = .lobby
    @Published var match: DuelMatch?
    /// Seconds left on each running clock, by player tag (lock-step HUD).
    /// Non-private set: written by the clock helpers in NearbyMatch+Clocks.swift.
    @Published var clocks: [String: TimeInterval] = [:]

    static let service = "lattice-duel"

    // Members marked non-private are reached by the delegate conformances in
    // NearbyMatch+Delegates.swift (same module; a `final` class's internal
    // members aren't part of LatticeKit's public API).
    // Editable in the guest lobby (rebuilds the peer identity — see rename in
    // NearbyMatch+Lobby.swift; hence these are non-private).
    @Published var myName: String
    private let myBests: BestScores
    var myPeer: MCPeerID
    let selfTag = UUID().uuidString.prefix(9).description
    var session: MCSession
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser

    /// Discovery tag per connected/known peer (their advertised "k").
    var peerTags: [MCPeerID: String] = [:]
    /// Display name per peer (from their hello).
    var peerNames: [MCPeerID: String] = [:]
    /// Host: peers accepted into the game, in acceptance order.
    @Published var acceptedPeers: [MCPeerID] = []

    // Host's chosen config, set in host(config:).
    private var hostMode: DuelMode?
    private var hostVariant: String?

    // Clock timers, one per running player (lock-step). Non-private: the clock
    // helpers live in NearbyMatch+Clocks.swift.
    var clockDeadlines: [String: Date] = [:]
    var clockTimer: Timer?

    // Race timekeeping (host only, the sole authority): when the match started,
    // and each player's elapsed time to first reach the target.
    var matchStart: Date?
    var reachTimes: [String: TimeInterval] = [:]

    init(name: String, bests: BestScores) {
        let cleaned = Self.clean(name)
        myName = cleaned
        myBests = bests
        let peer = MCPeerID(displayName: cleaned)
        myPeer = peer
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.service)
        super.init()
        session.delegate = self
        browser.delegate = self
    }

    static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Lattice player" : String(trimmed.prefix(60))
    }

    /// MCSession/browser/advertiser hold their delegate `unowned(unsafe)`, so a
    /// late callback after dealloc hits freed memory. Backstops app termination,
    /// which `onDisappear` misses. Inlined: `deinit` isn't main-actor isolated.
    deinit {
        clockTimer?.invalidate()
        advertiser?.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        session.delegate = nil
        browser.delegate = nil
        advertiser?.delegate = nil
    }

    /// Whether the local player is still in the match (not resigned / out).
    var localIsActive: Bool {
        guard let m = match else { return false }
        return m.players[m.local]?.status == .active
    }

    /// Host: still have accepted players to (re)start with? (Else Rematch no-ops.)
    var hasAcceptedPeers: Bool { !acceptedPeers.isEmpty }

    /// Offerable tiers for the host's config UI, gated on the host's own best.
    func offerableTiers(variantKey: String) -> [Int] {
        DuelTier.offerableTiers(variantKey: variantKey, best: myBests)
    }

    var eligibleVariants: [String] { DuelTier.eligibleVariants }

    /// Become the host: advertise the chosen game so guests can find it.
    func host(mode: DuelMode, variantKey: String) {
        role = .hosting
        hostMode = mode
        hostVariant = variantKey
        lobbyNames = [myName]
        acceptedPeers = []
        var info: [String: String] = [
            "k": selfTag, "n": myName, "v": variantKey,
        ]
        switch mode {
        case .lockStep: info["m"] = "L"
        case .race(let tier):
            info["m"] = "R"
            info["t"] = String(tier)
        }
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeer, discoveryInfo: info, serviceType: Self.service)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    /// Guest: request to join an advertised game.
    func join(_ game: AdvertisedGame) {
        role = .joining(game.peer)
        stage = .waitingForHost
        peerNames[game.peer] = game.hostName
        browser.invitePeer(
            game.peer, to: session, withContext: Data(selfTag.utf8), timeout: 30)
    }

    /// Host: accept a pending join request.
    func accept(_ request: JoinRequest) {
        guard role == .hosting, !acceptedPeers.contains(request.peer) else { return }
        acceptedPeers.append(request.peer)
        joinRequests.removeAll { $0.peer == request.peer }
        lobbyNames = [myName] + acceptedPeers.map { peerNames[$0] ?? "?" }
    }

    /// Host: decline a pending join request (drop the connection).
    func decline(_ request: JoinRequest) {
        joinRequests.removeAll { $0.peer == request.peer }
        session.cancelConnectPeer(request.peer)
    }

    /// Host: start the match with everyone accepted so far.
    func startMatch() {
        guard role == .hosting, let mode = hostMode, let variant = hostVariant,
            !acceptedPeers.isEmpty
        else { return }
        let seed = SeedCode.randomSeed()
        var roster: [DuelMessage.RosterEntry] = [.init(tag: selfTag, name: myName)]
        for peer in acceptedPeers {
            roster.append(.init(tag: peerTags[peer] ?? "?", name: peerNames[peer] ?? "?"))
        }
        broadcast(.start(seed: seed, mode: mode, variantKey: variant, roster: roster))
        advertiser?.stopAdvertisingPeer()
        beginMatch(seed: seed, mode: mode, variantKey: variant, roster: roster)
    }

    /// Host, after a match: play again with the same roster and config — a fresh
    /// `start` (new seed) to everyone still connected. Same primitive as the
    /// first Start.
    func rematch() {
        startMatch()
    }

    /// Host, after a match: return everyone to the lobby (keep the session and
    /// roster) to await another Start — lets late joiners in and the host tweak
    /// who's playing. Guests wait for the host.
    func backToLobby() {
        guard role == .hosting else { return }
        match = nil
        stage = .lobby
        broadcast(.backToLobby)
        advertiser?.startAdvertisingPeer()  // re-open discovery for new joiners
    }

    /// Guest: the host disconnected mid-flow (called from the session delegate).
    func hostDisconnected() {
        stopClocks()
        match = nil
        stage = .hostLeft
    }

    // MARK: Match

    func beginMatch(
        seed: UInt64, mode: DuelMode, variantKey: String, roster: [DuelMessage.RosterEntry]
    ) {
        match = DuelMatch(
            mode: mode, seed: seed, variantKey: variantKey, local: selfTag,
            roster: roster.map { ($0.tag, $0.name) })
        matchStart = Date()  // host is the race timekeeper; harmless on guests
        reachTimes = [:]
        stage = .dueling
        checkLocalDeadEnd()  // a starting board with no move (unlikely) still ends us
    }

    /// The local player committed a move in the duel UI.
    func commitMove(_ move: Move) {
        guard var m = match else { return }
        let actions = m.localMove(move)
        // Assign + stamp BEFORE applying: `apply` may run `.finish`, which reads
        // reachTimes to author the standings, so the reach must be recorded first.
        match = m
        stampReaches()
        apply(actions)
        checkLocalDeadEnd()
    }

    /// The local player resigned — they're out (others are told via
    /// `eliminated`; in a 2-player match that ends it).
    func resign() {
        guard var m = match, stage == .dueling else { return }
        apply(m.noLegalMoves(selfTag))
        match = m
    }

    /// If the local player's turn has opened with no legal move, eliminate them
    /// at once — a dead-end shouldn't have to wait out the 10s clock. Called
    /// after every event that can start a new local turn.
    func checkLocalDeadEnd() {
        guard var m = match, m.localHasNoMove else { return }
        apply(m.noLegalMoves(selfTag))
        match = m
    }

    func apply(_ actions: [DuelMatch.Action]) {
        for action in actions {
            switch action {
            case .sendMove(let move): broadcast(.move(from: selfTag, move))
            case .sendScore(let score): broadcast(.score(from: selfTag, score))
            case .sendEliminated: broadcast(.eliminated(from: selfTag))
            case .startClock(let tag, let seconds): startClock(tag, seconds)
            case .stopClock(let tag): stopClock(tag)
            case .finish(let standings): finish(standings)
            }
        }
    }

    /// The engine settled. The host is the timekeeper, so it authors the ranked
    /// standings and broadcasts them; guests show whatever the host sends (they
    /// wait for `.results` rather than ranking a copy without the reach-times).
    func finish(_ standings: [String]) {
        stopClocks()
        guard role == .hosting else { return }  // guests await `.results`
        let rows = rankedRows(order: standings)
        broadcast(.results(rows.map(\.wire)))
        stage = .finished(standings: rows)
    }

}
