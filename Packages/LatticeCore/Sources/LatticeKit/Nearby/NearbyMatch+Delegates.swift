import Foundation
import LatticeCore
import MultipeerConnectivity

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
