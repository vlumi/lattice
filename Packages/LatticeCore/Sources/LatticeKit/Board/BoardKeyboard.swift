import SwiftUI

/// Invisible buttons whose shortcuts drive keyboard play — the iOS-16-safe
/// pattern (onKeyPress needs iOS 17), same as ReplayView's transport. Arrows
/// move the cursor / cycle candidates; Enter+Space place/commit; Tab cycles;
/// Backspace undoes; Escape cancels. Sits behind the board as a background.
struct BoardKeyboard: View {
    @ObservedObject var session: GameSession
    /// Off while an overlay (cheatsheet / New Game modal) is up, so its Esc and
    /// other keys don't compete with the board's.
    var enabled = true

    var body: some View {
        if enabled { keys }
    }

    private var keys: some View {
        Group {
            // Model y grows upward, screen y downward — Up increases model y.
            // WASD mirror the arrows (same cursor moves / candidate cycle).
            key(.upArrow) { session.moveCursor(dx: 0, dy: 1) }
            key(.downArrow) { session.moveCursor(dx: 0, dy: -1) }
            key(.leftArrow) { horizontal(-1) }
            key(.rightArrow) { horizontal(1) }
            key("w") { session.moveCursor(dx: 0, dy: 1) }
            key("s") { session.moveCursor(dx: 0, dy: -1) }
            key("a") { horizontal(-1) }
            key("d") { horizontal(1) }
            key(.return) { activate() }
            key(.space) { activate() }
            key(.tab) { session.cycleCandidate(by: 1) }
            key(.delete) { session.undo() }
            key(.escape) { session.cancel() }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func key(_ shortcut: KeyEquivalent, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Color.clear.frame(width: 1, height: 1) }
            .keyboardShortcut(shortcut, modifiers: [])
    }

    // Left/right move the cursor while placing a dot, but cycle candidate lines
    // once a dot is tentative.
    private func horizontal(_ dir: Int) {
        if session.tentative == nil {
            session.moveCursor(dx: dir, dy: 0)
        } else {
            session.cycleCandidate(by: dir)
        }
    }

    private func activate() {
        if session.tentative == nil {
            session.cursorSelect()
        } else {
            session.commitHighlighted()
        }
    }
}
