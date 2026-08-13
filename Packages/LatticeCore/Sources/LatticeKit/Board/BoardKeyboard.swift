import SwiftUI

/// Invisible buttons whose shortcuts drive keyboard play — the iOS-16-safe
/// pattern (onKeyPress needs iOS 17), same as ReplayView's transport. Arrows
/// move the cursor / cycle candidates; Enter+Space place/commit; Tab cycles;
/// Backspace undoes; Escape cancels. Sits behind the board as a background.
struct BoardKeyboard: View {
    @ObservedObject var session: GameSession
    @EnvironmentObject private var feedback: Feedback
    /// Off while an overlay (cheatsheet / New Game modal) is up, so its Esc and
    /// other keys don't compete with the board's.
    var enabled = true

    var body: some View {
        // macOS: hidden shortcut buttons. iOS: a first-responder UIView reading
        // pressesBegan, since those buttons never fire here. Same commands.
        #if os(macOS)
        if enabled { keys }
        #else
        BoardKeyCatcher(enabled: enabled, perform: perform)
        #endif
    }

    #if os(macOS)
    private var keys: some View {
        Group {
            // Model y grows upward, screen y downward — Up increases model y.
            // WASD mirror the arrows (same cursor moves / candidate cycle).
            key(.upArrow) { perform(.move(dx: 0, dy: 1)) }
            key(.downArrow) { perform(.move(dx: 0, dy: -1)) }
            key(.leftArrow) { perform(.move(dx: -1, dy: 0)) }
            key(.rightArrow) { perform(.move(dx: 1, dy: 0)) }
            key("w") { perform(.move(dx: 0, dy: 1)) }
            key("s") { perform(.move(dx: 0, dy: -1)) }
            key("a") { perform(.move(dx: -1, dy: 0)) }
            key("d") { perform(.move(dx: 1, dy: 0)) }
            key(.return) { perform(.activate) }
            key(.space) { perform(.activate) }
            key(.tab) { perform(.cycleCandidate) }
            key(.delete) { perform(.undo) }
            key(.escape) { perform(.cancel) }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func key(_ shortcut: KeyEquivalent, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Color.clear.frame(width: 1, height: 1) }
            .keyboardShortcut(shortcut, modifiers: [])
    }
    #endif

    /// Runs a command. Shared by both platforms' key maps — macOS's hidden
    /// shortcut buttons above, and the iPad's `pressesBegan` (BoardKeyCatcher).
    func perform(_ command: BoardKeyCommand) {
        switch command {
        case .move(let dx, let dy):
            // Horizontal cycles candidates once a dot is tentative.
            if dx != 0, session.tentative != nil {
                session.cycleCandidate(by: dx)
            } else {
                move(dx: dx, dy: dy)
            }
        case .activate: activate()
        case .cycleCandidate: session.cycleCandidate(by: 1)
        case .undo: session.undo()
        case .cancel: session.cancel()
        }
    }

    /// Every cursor move goes through here so the roaming cue fires once per
    /// actual move — a press that only bumps the clamp stays silent rather than
    /// re-ticking the same point.
    private func move(dx: Int, dy: Int) {
        let before = session.keyboardCursor
        session.moveCursor(dx: dx, dy: dy)
        guard session.keyboardCursor != before else { return }
        feedback.cursorMoved(session.cursorState)
    }

    private func activate() {
        if session.tentative == nil {
            session.cursorSelect()
        } else {
            session.commitHighlighted()
        }
    }
}
