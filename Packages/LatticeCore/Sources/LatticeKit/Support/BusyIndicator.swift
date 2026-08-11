import SwiftUI

/// Drives a "working…" indicator so it never flashes: it appears only if the
/// work is STILL running after a grace period, and once shown it stays a
/// minimum duration. Only the *visual* waits — gate input on the real state.
///
/// Copied from Donpa's processing overlay (GameContent.driveProcessingOverlay).
@MainActor
final class BusyIndicator: ObservableObject {
    /// Whether to show the indicator right now.
    @Published private(set) var isVisible = false

    private let grace: TimeInterval
    private let minVisible: TimeInterval
    private var shownAt: Date?
    private var task: Task<Void, Never>?

    init(grace: TimeInterval = 0.12, minVisible: TimeInterval = 0.3) {
        self.grace = grace
        self.minVisible = minVisible
    }

    /// Feed the real busy state on every change; the indicator lags it per the
    /// grace / minimum-visible rules.
    func update(busy: Bool) {
        task?.cancel()
        task = Task { [self] in
            if busy {
                try? await Task.sleep(nanoseconds: UInt64(grace * 1e9))
                guard !Task.isCancelled, !isVisible else { return }
                isVisible = true
                shownAt = Date()
            } else if isVisible {
                let elapsed = shownAt.map { Date().timeIntervalSince($0) } ?? minVisible
                let remaining = minVisible - elapsed
                if remaining > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1e9))
                }
                guard !Task.isCancelled else { return }
                isVisible = false
                shownAt = nil
            }
        }
    }
}
