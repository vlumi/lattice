import Foundation

/// The per-player reactive countdown clocks (lock-step). Transport-owned so the
/// pure DuelMatch stays clock-free — it only knows a clock is running or not.
extension NearbyMatch {
    /// Start browsing for advertised games (guest default on appear).
    func start() {
        browser.startBrowsingForPeers()
    }

    /// Idempotent: `onDisappear` and `deinit` may both run it.
    func stop() {
        clockTimer?.invalidate()
        clockTimer = nil
        advertiser?.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    func stopClocks() {
        clockTimer?.invalidate()
        clockTimer = nil
        clockDeadlines = [:]
        clocks = [:]
    }

    func startClock(_ tag: String, _ seconds: TimeInterval) {
        clockDeadlines[tag] = Date().addingTimeInterval(seconds)
        clocks[tag] = seconds
        ensureClockTimer()
    }

    func stopClock(_ tag: String) {
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
}
