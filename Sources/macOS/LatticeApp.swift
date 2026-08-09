import LatticeKit
import SwiftUI

@main
struct LatticeApp: App {
    // A single-window game: closing the window should quit, not leave the app
    // running with no window (the macOS default).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .frame(minWidth: 480, minHeight: 520)
        }
        // Settings opens as a modal sheet on the game window (⌘,), not as a
        // separate window — so it can't be orphaned or outlive the game. The
        // menu command lives here; RootView presents the sheet off `model`.
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button {
                    model.isShowingSettings = true
                } label: {
                    Text(verbatim: "Settings…")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }
}
