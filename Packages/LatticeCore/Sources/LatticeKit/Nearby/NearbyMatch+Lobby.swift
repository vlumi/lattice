import MultipeerConnectivity

extension NearbyMatch {
    /// Guest lobby only (idle, no connection yet): change the display name. This
    /// rebuilds the MCPeerID/session/browser so the new name is the real peer
    /// identity others see on the network — only safe before hosting/joining.
    func rename(_ name: String) {
        let cleaned = Self.clean(name)
        guard cleaned != myName, role == .idle else { return }
        browser.stopBrowsingForPeers()
        session.disconnect()
        games = []
        myName = cleaned
        myPeer = MCPeerID(displayName: cleaned)
        session = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
        browser = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.service)
        session.delegate = self
        browser.delegate = self
        browser.startBrowsingForPeers()
    }
}
