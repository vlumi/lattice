import LatticeCore

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
    /// `.rigid` reads as a crisp tick at low intensity — the cursor cue fires on
    /// every arrow press, so it has to stay well under the commit tap.
    private let cursorImpact = UIImpactFeedbackGenerator(style: .rigid)
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

    /// The keyboard cursor moved onto a point of this kind. Intensity carries
    /// the meaning, strongest for the placeable point being hunted; empty
    /// lattice is a barely-there tick so sweeping dead space doesn't buzz.
    func cursor(_ state: CursorState) {
        #if os(iOS)
        guard isEnabled else { return }
        let intensity: CGFloat
        switch state {
        case .placeable: intensity = 0.55
        case .dot: intensity = 0.35
        case .empty: intensity = 0.18
        }
        cursorImpact.impactOccurred(intensity: intensity)
        cursorImpact.prepare()
        #endif
    }

    /// A tap that can't become a move. A soft "nope" — clearly not the crisp
    /// commit tap, and gentler than the game-over notification: a mis-tap is a
    /// normal part of learning the board, not an error to scold.
    func rejected() {
        #if os(iOS)
        guard isEnabled else { return }
        cursorImpact.impactOccurred(intensity: 0.4)
        cursorImpact.prepare()
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
