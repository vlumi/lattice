#if os(iOS)
import UIKit
#endif

/// Board haptics: a picker-style detent as the scrub highlight cycles between
/// candidate lines, a firmer tap when a line commits, and a neutral
/// notification when the game ends. iOS-only; a no-op elsewhere. Copy-adapted
/// from Donpa's `HapticPlayer` (plumbing kept in sync with the sibling app).
@MainActor
final class HapticPlayer {
    /// On by default (silent, ambient) — set from the Settings toggle.
    var isEnabled = true

    #if os(iOS)
    // `prepare()` right after firing keeps the next hit's latency low without
    // holding the Taptic Engine on indefinitely.
    private let selection = UISelectionFeedbackGenerator()
    private let commitImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    /// The scrub highlight moved to a different candidate line — the
    /// purpose-built "value changed" detent, so choosing between overlapping
    /// lines is tactile. Fire only on an actual change.
    func select() {
        #if os(iOS)
        guard isEnabled else { return }
        selection.selectionChanged()
        selection.prepare()
        #endif
    }

    /// A line was committed.
    func place() {
        #if os(iOS)
        guard isEnabled else { return }
        commitImpact.impactOccurred()
        commitImpact.prepare()
        #endif
    }

    /// The game ended (no moves left) — a single neutral notification, clearly
    /// noticeable without reading as success or failure.
    func gameOver() {
        #if os(iOS)
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
        #endif
    }
}
