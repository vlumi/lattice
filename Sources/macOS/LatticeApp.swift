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
            // Tab switching in the *existing* View menu (⌘1–⌘4, a checkmark on
            // the current one) — `.sidebar` items live in View, so `after:` it
            // appends there instead of adding a second View menu. The tab strip
            // stays; this is the Mac-conventional, discoverable route.
            CommandGroup(after: .sidebar) {
                ViewMenu(model: model)
                Divider()
            }
        }
    }
}

/// The View menu's tab items — each switches `model.selection`, shows its
/// ⌘-number, and checks the current tab. Buttons (not a Picker) so each can
/// carry its own ⌘-number; a leading checkmark image marks the current tab.
private struct ViewMenu: View {
    @ObservedObject var model: AppModel

    private struct Item {
        let tab: AppModel.Tab
        let title: String
        let key: KeyEquivalent
    }

    private static let tabs: [Item] = [
        Item(tab: .free, title: "Free", key: "1"),
        Item(tab: .daily, title: "Daily", key: "2"),
        Item(tab: .versus, title: "Versus", key: "3"),
        Item(tab: .history, title: "History", key: "4"),
    ]

    var body: some View {
        ForEach(Array(Self.tabs.enumerated()), id: \.offset) { _, item in
            Button {
                model.selection = item.tab
            } label: {
                if model.selection == item.tab {
                    Label(item.title, systemImage: "checkmark")
                } else {
                    Text(verbatim: item.title)
                }
            }
            .keyboardShortcut(item.key, modifiers: .command)
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }
}
