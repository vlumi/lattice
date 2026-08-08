import SwiftUI

/// The floating controls over the board (bottom-trailing): Undo always, Fit
/// only when the camera has moved. Subtle circular buttons on a faint material
/// so they read as controls without competing with the board. Extracted from
/// GameView; the board reserves this corner (see Layout.controlsClearInset).
struct BoardControls: View {
    @ObservedObject var session: GameSession
    @ObservedObject var camera: BoardCamera

    var body: some View {
        VStack(spacing: 10) {
            if !camera.isIdentity {
                button(systemName: "viewfinder", label: Text("Fit", bundle: .module)) {
                    camera.reset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            button(
                systemName: "arrow.uturn.backward", label: Text("Undo", bundle: .module),
                enabled: session.undoAllowed
            ) {
                session.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!session.undoAllowed)
        }
        .padding(12)
    }

    private func button(
        systemName: String, label: Text, enabled: Bool = true, action: @escaping () -> Void
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
    }
}
