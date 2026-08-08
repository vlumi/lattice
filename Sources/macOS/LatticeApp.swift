import LatticeKit
import SwiftUI

@main
struct LatticeApp: App {
    // A single-window game: closing the window should quit, not leave the app
    // running with no window (the macOS default).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 480, minHeight: 520)
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }
}
