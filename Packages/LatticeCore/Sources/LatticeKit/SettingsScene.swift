import SwiftUI

/// The macOS Settings sheet's content — the same `SettingsView` the iOS tab
/// shows, wrapped as a modal sheet with a title bar + Done (and Esc to close).
/// Presented on the game window (see RootView) rather than a separate window,
/// so it can't be orphaned. SettingsView itself stays internal to the package.
public struct SettingsScene: View {
    @ObservedObject private var model: AppModel
    private let done: () -> Void

    public init(model: AppModel, done: @escaping () -> Void) {
        self.model = model
        self.done = done
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings", bundle: .module).font(.headline)
                Spacer()
                Button(action: done) {
                    Text("Done", bundle: .module)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            SettingsView(sync: model.sync, feedback: model.feedback, onClose: done)
        }
        .frame(width: 460)  // compact, like a standard settings pane
    }
}
