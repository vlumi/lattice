import Foundation
import LatticeCore
import MultipeerConnectivity
import OSLog

/// Match diagnostics — `log stream --predicate 'subsystem == "fi.misaki.lattice"
/// && category == "match"'`. Temporary while the redesigned transport is being
/// verified on real devices.
let matchLog = Logger(subsystem: "fi.misaki.lattice", category: "match")

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

    /// A final-standings row: the player's name and their final move count.
    struct Standing: Equatable {
        let name: String
        let score: Int
    }

    enum Stage: Equatable {
        case lobby
        case waitingForHost  // guest: requested, waiting for start
        case dueling
        case finished(standings: [Standing])  // by score, highest first
    }

    // Lobby state. Setters are internal (not private) where the delegate
    // conformances in NearbyMatch+Delegates.swift mutate them.
    @Published private(set) var role: Role = .idle
    @Published internal(set) var games: [AdvertisedGame] = []
    @Published internal(set) var joinRequests: [JoinRequest] = []
    /// Accepted players in the host's lobby (display names), self first.
    @Published internal(set) var lobbyNames: [String] = []

    // Match state
    @Published private(set) var stage: Stage = .lobby
    @Published internal(set) var match: DuelMatch?
    /// Seconds left on each running clock, by player tag (lock-step HUD).
    @Published private(set) var clocks: [String: TimeInterval] = [:]

    static let service = "lattice-duel"

    // Members marked non-private are reached by the delegate conformances in
    // NearbyMatch+Delegates.swift (same module; a `final` class's internal
    // members aren't part of LatticeKit's public API).
    let myName: String
    private let myBests: BestScores
    private let myPeer: MCPeerID
    let selfTag = UUID().uuidString.prefix(9).description
    var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private let browser: MCNearbyServiceBrowser

    /// Discovery tag per connected/known peer (their advertised "k").
    var peerTags: [MCPeerID: String] = [:]
    /// Display name per peer (from their hello).
    var peerNames: [MCPeerID: String] = [:]
    /// Host: peers accepted into the game, in acceptance order.
    var acceptedPeers: [MCPeerID] = []

    // Host's chosen config, set in host(config:).
    private var hostMode: DuelMode?
    private var hostVariant: String?

    // Clock timers, one per running player (lock-step).
    private var clockDeadlines: [String: Date] = [:]
    private var clockTimer: Timer?

    init(name: String, bests: BestScores) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        myName = trimmed.isEmpty ? "Lattice player" : String(trimmed.prefix(60))
        myBests = bests
        myPeer = MCPeerID(displayName: myName)
        session = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
        browser = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.service)
        super.init()
        session.delegate = self
        browser.delegate = self
    }

    // MARK: Lobby lifecycle

    /// Start browsing for advertised games (guest default on appear).
    func start() {
        browser.startBrowsingForPeers()
    }

    func stop() {
        clockTimer?.invalidate()
        advertiser?.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

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

    // MARK: Match

    private func beginMatch(
        seed: UInt64, mode: DuelMode, variantKey: String, roster: [DuelMessage.RosterEntry]
    ) {
        match = DuelMatch(
            mode: mode, seed: seed, variantKey: variantKey, local: selfTag,
            roster: roster.map { ($0.tag, $0.name) })
        stage = .dueling
        checkLocalDeadEnd()  // a starting board with no move (unlikely) still ends us
    }

    /// The local player committed a move in the duel UI.
    func commitMove(_ move: Move) {
        guard var m = match else { return }
        let actions = m.localMove(move)
        let wait = m.localWaitingForRound
        matchLog.info(
            "localMove \(self.selfTag, privacy: .public) n=\(actions.count) wait=\(wait)")
        apply(actions)
        match = m
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
        matchLog.info("localDeadEnd \(self.selfTag, privacy: .public)")
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

    private func finish(_ standings: [String]) {
        clockTimer?.invalidate()
        clockTimer = nil
        clockDeadlines = [:]
        clocks = [:]
        let rows = standings.map { tag in
            Standing(
                name: match?.players[tag]?.name ?? tag,
                score: match?.players[tag]?.score ?? 0)
        }
        stage = .finished(standings: rows)
    }

    // MARK: Per-player reactive clocks (transport-owned; match stays pure)

    private func startClock(_ tag: String, _ seconds: TimeInterval) {
        clockDeadlines[tag] = Date().addingTimeInterval(seconds)
        clocks[tag] = seconds
        ensureClockTimer()
    }

    private func stopClock(_ tag: String) {
        clockDeadlines[tag] = nil
        clocks[tag] = nil
        if clockDeadlines.isEmpty {
            clockTimer?.invalidate()
            clockTimer = nil
        }
    }

    private func ensureClockTimer() {
        guard clockTimer == nil else { return }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickClocks() }
        }
    }

    private func tickClocks() {
        guard var m = match else { return }
        var localExpired = false
        for (tag, deadline) in clockDeadlines {
            let left = deadline.timeIntervalSinceNow
            clocks[tag] = max(0, left)
            // Each device only DECIDES its own clock's expiry (and reports it via
            // `eliminated`); remote clocks tick for the HUD but their expiry is
            // owned by that player — no cross-device timer divergence.
            if left <= 0, tag == selfTag { localExpired = true }
        }
        if localExpired {
            matchLog.info("localClockExpired \(self.selfTag, privacy: .public)")
            stopClock(selfTag)
            apply(m.clockExpired(selfTag))
            match = m
        }
    }

    // MARK: Send / receive

    private func broadcast(_ message: DuelMessage) {
        let peers = session.connectedPeers
        guard !peers.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    func send(_ message: DuelMessage, to peer: MCPeerID) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    func received(_ data: Data, from peer: MCPeerID) {
        guard let message = try? JSONDecoder().decode(DuelMessage.self, from: data) else { return }
        switch message {
        case .hello(let name):
            peerNames[peer] = name
        case .requestJoin:
            receivedJoinRequest(from: peer)
        case .start(let seed, let mode, let variantKey, let roster):
            // The host set our tag from our discovery context; the roster
            // carries it, so `local: selfTag` finds us in it.
            beginMatch(seed: seed, mode: mode, variantKey: variantKey, roster: roster)
        case .move, .score, .eliminated:
            receivedMatchEvent(message, from: peer)
        }
    }

    private func receivedJoinRequest(from peer: MCPeerID) {
        guard role == .hosting, !joinRequests.contains(where: { $0.peer == peer }),
            !acceptedPeers.contains(peer)
        else { return }
        joinRequests.append(.init(peer: peer, name: peerNames[peer] ?? peer.displayName))
    }

    private func receivedMatchEvent(_ message: DuelMessage, from peer: MCPeerID) {
        // Route by the actor carried IN the message, not the physical sender —
        // relayed events arrive from the host but belong to another guest.
        let actor: String
        switch message {
        case .move(let from, _), .score(let from, _), .eliminated(let from): actor = from
        default: return
        }
        guard actor != selfTag, var m = match else { return }  // skip our own echo
        let hosting = role == .hosting
        matchLog.info("recv actor=\(actor, privacy: .public) host=\(hosting)")
        switch message {
        case .move: apply(m.remoteMoved(actor))
        case .score(_, let score): apply(m.remoteScored(actor, score: score))
        case .eliminated: apply(m.remoteEliminated(actor))
        default: return
        }
        match = m
        // Star topology: guests connect only to the host, so the host relays
        // each guest's event to the OTHERS (the actor tag survives the hop).
        if role == .hosting { relay(message, from: peer) }
        // A remote move may have completed the round, opening our next turn —
        // if it has no legal move, we're out immediately.
        checkLocalDeadEnd()
    }

    /// Host-only: forward a guest's message to the other connected guests.
    private func relay(_ message: DuelMessage, from sender: MCPeerID) {
        let others = session.connectedPeers.filter { $0 != sender }
        guard !others.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: others, with: .reliable)
    }
}
