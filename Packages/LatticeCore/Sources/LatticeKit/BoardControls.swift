import SwiftUI

/// The floating controls over the board (bottom-trailing): Undo always, Fit
/// only when the camera has moved. Subtle circular buttons on a faint material
/// so they read as controls without competing with the board. Extracted from
/// GameView; the board reserves this corner (see Layout.controlsClearInset).
struct BoardControls: View {
    @ObservedObject var session: GameSession
    @ObservedObject var camera: BoardCamera
    /// "?" is on — show each button's keyboard-shortcut badge.
    var showShortcuts = false

    var body: some View {
        VStack(spacing: 10) {
            if !camera.isIdentity {
                button(
                    systemName: "viewfinder", label: Text("Fit", bundle: .module), shortcut: "⌘0"
                ) {
                    camera.reset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            button(
                systemName: "arrow.uturn.backward", label: Text("Undo", bundle: .module),
                shortcut: "⌘Z", enabled: session.undoAllowed
            ) {
                session.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!session.undoAllowed)
        }
        .padding(12)
    }

    private func button(
        systemName: String, label: Text, shortcut: String, enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .overlay(alignment: .topLeading) {
            if showShortcuts { ShortcutBadge(shortcut) }
        }
    }
}

/// A small key-combo badge pinned to a control while the cheatsheet is on.
struct ShortcutBadge: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(verbatim: text)
            .font(.caption2.monospaced().weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.tint, in: Capsule())
            .foregroundStyle(.white)
            .fixedSize()
    }
}
