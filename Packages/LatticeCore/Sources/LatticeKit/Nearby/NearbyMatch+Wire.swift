import Foundation
import LatticeCore
import MultipeerConnectivity

/// The wire protocol: encoding DuelMessages out and applying them on receipt.
/// The host relays — guests only ever talk to it (star topology).
extension NearbyMatch {
    // MARK: Send / receive

    func broadcast(_ message: DuelMessage) {
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
        case .results(let rows):
            // The host is the timekeeper; show exactly what it ranked.
            stopClocks()
            stage = .finished(standings: rows.map(Standing.init))
        case .backToLobby:
            // Host reset for another game — wait for the next start.
            stopClocks()
            match = nil
            stage = .waitingForHost
        }
    }

    func receivedJoinRequest(from peer: MCPeerID) {
        guard role == .hosting, !joinRequests.contains(where: { $0.peer == peer }),
            !acceptedPeers.contains(peer)
        else { return }
        joinRequests.append(.init(peer: peer, name: peerNames[peer] ?? peer.displayName))
    }

    func receivedMatchEvent(_ message: DuelMessage, from peer: MCPeerID) {
        // Route by the actor carried IN the message, not the physical sender —
        // relayed events arrive from the host but belong to another guest.
        let actor: String
        switch message {
        case .move(let from, _), .score(let from, _), .eliminated(let from): actor = from
        default: return
        }
        guard actor != selfTag, var m = match else { return }  // skip our own echo
        let actions: [DuelMatch.Action]
        switch message {
        case .move: actions = m.remoteMoved(actor)
        case .score(_, let score): actions = m.remoteScored(actor, score: score)
        case .eliminated: actions = m.remoteEliminated(actor)
        default: return
        }
        match = m  // assign + stamp before apply (see commitMove)
        stampReaches()
        apply(actions)
        // Star topology: guests connect only to the host, so the host relays
        // each guest's event to the OTHERS (the actor tag survives the hop).
        if role == .hosting { relay(message, from: peer) }
        // A remote move may have completed the round, opening our next turn —
        // if it has no legal move, we're out immediately.
        checkLocalDeadEnd()
    }

    /// Host-only: forward a guest's message to the other connected guests.
    func relay(_ message: DuelMessage, from sender: MCPeerID) {
        let others = session.connectedPeers.filter { $0 != sender }
        guard !others.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: others, with: .reliable)
    }
}
