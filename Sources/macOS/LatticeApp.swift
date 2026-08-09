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
        .commands {
            LatticeCommands(model: model)
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }
}
