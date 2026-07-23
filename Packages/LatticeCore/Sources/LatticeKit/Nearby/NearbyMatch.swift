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

    enum Stage: Equatable {
        case lobby
        case waitingForHost  // guest: requested, waiting for start
        case dueling
        case finished(standings: [String])  // display names, winner-first
    }

    // Lobby state
    @Published private(set) var role: Role = .idle
    @Published private(set) var games: [AdvertisedGame] = []
    @Published private(set) var joinRequests: [JoinRequest] = []
    /// Accepted players in the host's lobby (display names), self first.
    @Published private(set) var lobbyNames: [String] = []

    // Match state
    @Published private(set) var stage: Stage = .lobby
    @Published private(set) var match: DuelMatch?
    /// Seconds left on each running clock, by player tag (lock-step HUD).
    @Published private(set) var clocks: [String: TimeInterval] = [:]

    static let service = "lattice-duel"

    private let myName: String
    private let myBests: BestScores
    private let myPeer: MCPeerID
    private let selfTag = UUID().uuidString.prefix(9).description
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private let browser: MCNearbyServiceBrowser

    /// Discovery tag per connected/known peer (their advertised "k").
    private var peerTags: [MCPeerID: String] = [:]
    /// Display name per peer (from their hello).
    private var peerNames: [MCPeerID: String] = [:]
    /// Host: peers accepted into the game, in acceptance order.
    private var acceptedPeers: [MCPeerID] = []

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
    }

    /// The local player committed a move in the duel UI.
    func commitMove(_ move: Move) {
        guard var m = match else { return }
        apply(m.localMove(move))
        match = m
    }

    /// The local player has no legal move (board exhausted for them).
    func localStuck() {
        guard var m = match else { return }
        apply(m.noLegalMoves(selfTag))
        match = m
    }

    private func apply(_ actions: [DuelMatch.Action]) {
        for action in actions {
            switch action {
            case .sendMove(let move): broadcast(.move(move))
            case .sendScore(let score): broadcast(.score(score))
            case .sendEliminated: broadcast(.eliminated)
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
        let names = standings.map { tag in match?.players[tag]?.name ?? tag }
        stage = .finished(standings: names)
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

    private func send(_ message: DuelMessage, to peer: MCPeerID) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func received(_ data: Data, from peer: MCPeerID) {
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
        guard var m = match, let tag = peerTags[peer] else { return }
        switch message {
        case .move: apply(m.remoteMoved(tag))
        case .score(let score): apply(m.remoteScored(tag, score: score))
        case .eliminated: apply(m.remoteEliminated(tag))
        default: return
        }
        match = m
        // Star topology: guests connect only to the host, not to each other, so
        // the host relays every guest's event to the OTHER guests.
        if role == .hosting { relay(message, from: peer) }
    }

    /// Host-only: forward a guest's message to the other connected guests.
    private func relay(_ message: DuelMessage, from sender: MCPeerID) {
        let others = session.connectedPeers.filter { $0 != sender }
        guard !others.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: others, with: .reliable)
    }
}

// MARK: - MCSession / discovery delegates (off-main → hop to main)

extension NearbyMatch: MCSessionDelegate {
    nonisolated func session(
        _ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState
    ) {
        Task { @MainActor in
            switch state {
            case .connected:
                // Exchange names; a guest that just connected asks to join.
                self.send(.hello(name: self.myName), to: peerID)
                if case .joining(let host) = self.role, host == peerID {
                    self.send(.requestJoin, to: peerID)
                }
            case .notConnected:
                self.peerLeft(peerID)
            default:
                break
            }
        }
    }

    nonisolated func session(
        _ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID
    ) {
        Task { @MainActor in self.received(data, from: peerID) }
    }

    nonisolated func session(
        _ session: MCSession, didReceive stream: InputStream, withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}
    nonisolated func session(
        _ session: MCSession, didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID, with progress: Progress
    ) {}
    nonisolated func session(
        _ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?
    ) {}

    private func peerLeft(_ peer: MCPeerID) {
        joinRequests.removeAll { $0.peer == peer }
        if let idx = acceptedPeers.firstIndex(of: peer) {
            acceptedPeers.remove(at: idx)
            lobbyNames = [myName] + acceptedPeers.map { peerNames[$0] ?? "?" }
        }
        if var m = match, let tag = peerTags[peer], stage == .dueling {
            apply(m.disconnected(tag))
            match = m
        }
    }
}

extension NearbyMatch: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            // Record the guest's tag from the invite context; accept the
            // transport connection (the in-app requestJoin gates the roster).
            if let tag = context.flatMap({ String(bytes: $0, encoding: .utf8) }) {
                self.peerTags[peerID] = tag
            }
            invitationHandler(self.role == .hosting, self.role == .hosting ? self.session : nil)
        }
    }
}

extension NearbyMatch: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            guard let info, info["k"] != self.selfTag, let game = Self.parse(peerID, info)
            else { return }
            self.peerTags[peerID] = info["k"]
            self.peerNames[peerID] = game.hostName
            if !self.games.contains(where: { $0.peer == peerID }) { self.games.append(game) }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.games.removeAll { $0.peer == peerID } }
    }

    /// Parse an advertised game out of discoveryInfo; nil if malformed.
    private static func parse(_ peer: MCPeerID, _ info: [String: String]) -> AdvertisedGame? {
        guard let variant = info["v"], let modeKey = info["m"] else { return nil }
        let mode: DuelMode
        switch modeKey {
        case "L": mode = .lockStep
        case "R":
            guard let tier = info["t"].flatMap(Int.init) else { return nil }
            mode = .race(tier: tier)
        default: return nil
        }
        return AdvertisedGame(
            peer: peer, hostName: info["n"] ?? peer.displayName, mode: mode, variantKey: variant)
    }
}
