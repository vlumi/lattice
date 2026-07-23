import Foundation
import LatticeCore
import MultipeerConnectivity
import OSLog

/// Connection diagnostics — visible in Console.app / `log stream` filtered to
/// subsystem "fi.misaki.lattice", category "nearby". Temporary while the live
/// transport is being verified on real devices.
private let nearbyLog = Logger(subsystem: "fi.misaki.lattice", category: "nearby")

/// Live Nearby duel over MultipeerConnectivity. Discovery + mutual-consent
/// handshake are copy-adapted from Donpa's `NearbyExchange` (plumbing kept in
/// sync); once connected, this runs a `DuelProtocol` over the live session,
/// marshalling `DuelMessage`s both ways and driving the 10s reactive clock.
///
/// The host (decided by the crossed-invite tie-break at connect) picks the
/// agreed seed + variant + tier from the two players' exchanged bests and
/// sends `setup`; both `accept` to start. Then each side plays its own board;
/// moves, tier-reach, and resign cross the wire, and `DuelProtocol` decides
/// the outcome.
@MainActor
final class NearbyDuel: NSObject, ObservableObject {
    enum Stage: Equatable {
        case connecting
        case choosingTier(variants: [String])  // host picks; guest waits
        case awaitingAccept
        case dueling
        case finished(DuelProtocol.Outcome)
        case failed
    }

    @Published private(set) var peers: [MCPeerID] = []
    @Published private(set) var handshakePhase: NearbyFlow<MCPeerID>.Phase = .browsing
    @Published private(set) var stage: Stage?
    @Published private(set) var opponentName: String?
    /// Seconds left on our reactive clock while it runs (nil = not running).
    @Published private(set) var clockRemaining: TimeInterval?
    /// The live duel, once started — the board the UI renders and drives.
    @Published private(set) var duel: DuelProtocol?

    static let service = "lattice-duel"

    private let myName: String
    private let myBests: BestScores
    private let myPeer: MCPeerID
    private var session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var flow = NearbyFlow<MCPeerID>()
    private let selfTag: String
    private var peerTags: [MCPeerID: String] = [:]

    private var connectedPeer: MCPeerID?
    private var opponentBests: BestScores?
    private var isHost = false
    private var agreedSetup: DuelSetup?
    private var clockDeadline: Date?
    private var clockTimer: Timer?

    init(name: String, bests: BestScores) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        myName = trimmed.isEmpty ? "Lattice player" : String(trimmed.prefix(60))
        myBests = bests
        myPeer = MCPeerID(displayName: myName)
        selfTag = UUID().uuidString.prefix(9).description
        session = Self.makeSession(for: myPeer)
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeer, discoveryInfo: ["k": selfTag], serviceType: Self.service)
        browser = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.service)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    private static func makeSession(for peer: MCPeerID) -> MCSession {
        MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        clockTimer?.invalidate()
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    /// The local player tapped a peer to duel.
    func invite(_ peer: MCPeerID) {
        nearbyLog.info(
            "tapped \(peer.displayName, privacy: .public); selfTag=\(self.selfTag, privacy: .public)")
        stage = .connecting
        perform(flow.userTapped(peer))
    }

    // MARK: Handshake actions → MCC

    private func perform(_ actions: [NearbyFlow<MCPeerID>.Action]) {
        for action in actions {
            switch action {
            case .invite(let peer):
                nearbyLog.info("invite → \(peer.displayName, privacy: .public)")
                browser.invitePeer(
                    peer, to: session, withContext: Data(selfTag.utf8), timeout: 30)
            case .sendReady(let peer):
                send(.init(kind: .ready), to: peer)
            case .sendHello(let peer):
                connectedPeer = peer
                send(
                    .init(
                        kind: .duel(
                            .hello(name: myName, bests: myBests, clock: now()))), to: peer)
                flowHelloSent(to: peer)
            case .retry(let peer, let attempt):
                remakeSession()
                let delay = Double(min(attempt, 3))
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    guard let self else { return }
                    self.perform(self.flow.retryFired(for: peer))
                }
            }
        }
        handshakePhase = flow.phase
        nearbyLog.info("flow phase → \(String(describing: self.flow.phase), privacy: .public)")
    }

    private func flowHelloSent(to peer: MCPeerID) {
        perform(flow.helloSent(to: peer))
    }

    // MARK: Duel lifecycle

    /// Both sides consented + exchanged hello. The host resolves the agreed
    /// setup and offers tier choices; the guest waits for `setup`.
    private func handshakeDone(with peer: MCPeerID) {
        guard opponentBests != nil else { return }
        // Deterministic host: lower tag hosts (same rule as the crossed-invite
        // tie-break, so both agree without negotiation).
        isHost = selfTag < (peerTags[peer] ?? "")
        if isHost {
            stage = .choosingTier(variants: DuelTier.eligibleVariants)
        } else {
            stage = .awaitingAccept
        }
    }

    /// Host committed the match parameters (variant + tier); tell the guest
    /// and start locally.
    func hostChoose(variantKey: String, tier: Int) {
        guard isHost, let peer = connectedPeer else { return }
        let seed = SeedCode.randomSeed()
        agreedSetup = DuelSetup(seed: seed, variantKey: variantKey, tier: tier)
        send(.init(kind: .duel(.setup(seed: seed, variantKey: variantKey, tier: tier))), to: peer)
        beginDuel()
    }

    func offerableTiers(variantKey: String) -> [Int] {
        guard let theirs = opponentBests else { return [] }
        return DuelTier.offerableTiers(variantKey: variantKey, mine: myBests, theirs: theirs)
    }

    private func beginDuel() {
        guard let setup = agreedSetup else { return }
        duel = DuelProtocol(seed: setup.seed, variantKey: setup.variantKey, tier: setup.tier)
        stage = .dueling
    }

    /// The local player committed a move in the duel UI.
    func commitMove(_ move: Move) {
        guard var d = duel, let peer = connectedPeer else { return }
        applyDuel(d.localMove(move, clock: now()), to: peer)
        duel = d
    }

    private func applyDuel(_ actions: [DuelProtocol.Action], to peer: MCPeerID) {
        for action in actions {
            switch action {
            case .sendMove(let move, let clock):
                send(.init(kind: .duel(.move(move, clock: clock))), to: peer)
            case .startLocalClock(let seconds):
                startClock(seconds)
            case .stopLocalClock:
                stopClock()
            case .sendReachedTier:
                send(.init(kind: .duel(.reachedTier)), to: peer)
            case .sendResign:
                send(.init(kind: .duel(.resign)), to: peer)
            case .finish(let outcome):
                stopClock()
                stage = .finished(outcome)
            }
        }
    }

    // MARK: Reactive clock (transport-owned; protocol only knows running/not)

    private func startClock(_ seconds: TimeInterval) {
        clockDeadline = Date().addingTimeInterval(seconds)
        clockRemaining = seconds
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickClock() }
        }
    }

    private func tickClock() {
        guard let deadline = clockDeadline, let peer = connectedPeer, var d = duel else { return }
        let left = deadline.timeIntervalSinceNow
        clockRemaining = max(0, left)
        if left <= 0 {
            stopClock()
            applyDuel(d.localClockExpired(), to: peer)
            duel = d
        }
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
        clockDeadline = nil
        clockRemaining = nil
    }

    // MARK: Send / receive

    @discardableResult
    private func send(_ message: WireMessage, to peer: MCPeerID) -> Bool {
        guard let data = try? JSONEncoder().encode(message) else { return false }
        do {
            try session.send(data, toPeers: [peer], with: .reliable)
            return true
        } catch {
            perform(flow.linkFailed(with: peer))
            return false
        }
    }

    private func received(_ data: Data, from peer: MCPeerID) {
        guard let message = try? JSONDecoder().decode(WireMessage.self, from: data) else { return }
        switch message.kind {
        case .ready:
            perform(flow.receivedReady(from: peer))
        case .duel(let duelMessage):
            receivedDuel(duelMessage, from: peer)
        }
    }

    private func receivedDuel(_ message: DuelMessage, from peer: MCPeerID) {
        switch message {
        case .hello(let name, let bests, _):
            opponentName = name
            opponentBests = bests
            perform(flow.receivedHello(from: peer))
        case .setup(let seed, let variantKey, let tier):
            agreedSetup = DuelSetup(seed: seed, variantKey: variantKey, tier: tier)
            send(.init(kind: .duel(.accept)), to: peer)
            beginDuel()
        case .accept:
            break  // host already began on send
        case .move(_, let clock):
            guard var d = duel else { return }
            applyDuel(d.remoteMoved(clock: clock), to: peer)
            duel = d
        case .reachedTier:
            guard var d = duel else { return }
            applyDuel(d.remoteReachedTier(), to: peer)
            duel = d
        case .resign:
            guard var d = duel else { return }
            applyDuel(d.remoteResigned(), to: peer)
            duel = d
        }
    }

    private func remakeSession() {
        session.disconnect()
        session = Self.makeSession(for: myPeer)
        session.delegate = self
    }

    private func now() -> TimeInterval { Date().timeIntervalSinceReferenceDate }
}

/// The agreed match parameters (host-chosen, guest-echoed).
private struct DuelSetup {
    let seed: UInt64
    let variantKey: String
    let tier: Int
}

/// Envelope so the READY handshake marker and duel messages share one channel.
struct WireMessage: Codable {
    enum Kind: Codable {
        case ready
        case duel(DuelMessage)
    }
    let kind: Kind
}

// MARK: - MCSession / discovery delegates (off-main → hop to main)

extension NearbyDuel: MCSessionDelegate {
    nonisolated func session(
        _ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState
    ) {
        let name = peerID.displayName
        nearbyLog.info(
            "state \(name, privacy: .public) → \(state.rawValue, privacy: .public) (0=off 1=…ing 2=on)")
        Task { @MainActor in
            switch state {
            case .connected:
                self.perform(self.flow.connected(to: peerID))
                if case .done = self.flow.phase { self.handshakeDone(with: peerID) }
            case .notConnected:
                if case .dueling = self.stage {
                    if var d = self.duel {
                        self.applyDuel(d.disconnected(), to: peerID)
                        self.duel = d
                    }
                } else {
                    self.perform(self.flow.linkFailed(with: peerID))
                    if case .failed = self.flow.phase { self.stage = .failed }
                }
            default: break
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
}

extension NearbyDuel: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        nearbyLog.info("invitation from \(peerID.displayName, privacy: .public)")
        Task { @MainActor in
            let theirTag =
                context.flatMap { String(bytes: $0, encoding: .utf8) }
                ?? self.peerTags[peerID] ?? ""
            let crossed: Bool
            if case .connecting(let invited) = self.flow.phase, invited == peerID {
                crossed = true
            } else {
                crossed = false
            }
            if crossed,
                !NearbyFlow<MCPeerID>.acceptsCrossedInvite(
                    myTag: self.selfTag, theirTag: theirTag)
            {
                let tags = "mine=\(self.selfTag) theirs=\(theirTag)"
                nearbyLog.info("reject crossed: \(tags, privacy: .public)")
                invitationHandler(false, nil)
                return
            }
            nearbyLog.info(
                "accept \(peerID.displayName, privacy: .public) crossed=\(crossed, privacy: .public)")
            invitationHandler(true, self.session)
        }
    }
}

extension NearbyDuel: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            guard info?["k"] != self.selfTag else { return }
            self.peerTags[peerID] = info?["k"] ?? ""
            if !self.peers.contains(peerID) { self.peers.append(peerID) }
            nearbyLog.info(
                "found \(peerID.displayName, privacy: .public) tag=\(info?["k"] ?? "?", privacy: .public)")
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in self.peers.removeAll { $0 == peerID } }
    }
}
