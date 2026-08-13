import SwiftUI

/// The shared menu-bar command vocabulary (macOS menus; iPad hold-⌘ HUD) — the
/// single, discoverable home for every ⌘-shortcut. Commands set intents on the
/// `AppModel`; the active GameView / RootView observe and act. Menu titles are
/// explicit `Text(...)` so the string extractor picks them up.
public struct LatticeCommands: Commands {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    /// A menu shortcut mustn't act on the game while a modal covers it.
    private var modalOpen: Bool {
        model.isShowingSettings || model.isShowingAbout || model.isShowingHowTo
    }

    public var body: some Commands {
        // Mac-menu only. iPadOS 26 builds a real menu bar from these commands
        // too, and UIKit's UIMenuBuilder raises on `.appInfo`/`.help` — it has
        // no such replaceable groups — which crashed the app on launch (a bug
        // that shipped in build 8 via `.appSettings`, before About/Help
        // existed). iOS reaches all three from Settings instead: the tab
        // itself, and rows inside it.
        #if os(macOS)
        CommandGroup(replacing: .appInfo) {
            Button {
                model.isShowingAbout = true
            } label: {
                Text("About Lattice Five", bundle: .module)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button {
                model.isShowingSettings = true
            } label: {
                Text("Settings…", bundle: .module)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button {
                model.isShowingHowTo = true
            } label: {
                Text("Lattice Five Help", bundle: .module)
            }
            .keyboardShortcut("?", modifiers: .command)
        }
        #endif

        CommandGroup(replacing: .newItem) {
            Button {
                model.newGameRequested &+= 1
            } label: {
                Text("New Game…", bundle: .module)
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(modalOpen)
            Button {
                model.restartRequested &+= 1
            } label: {
                Text("Restart", bundle: .module)
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(modalOpen)
        }

        CommandGroup(after: .undoRedo) {
            Button {
                model.undoRequested &+= 1
            } label: {
                Text("Undo Move", bundle: .module)
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(modalOpen)
        }

        // Tab switching lives in the existing View menu (⌘1–⌘4 + a checkmark on
        // the current tab); plus Fit, Nearby, and the shortcut cheatsheet.
        CommandGroup(after: .sidebar) {
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
            Divider()
            Button {
                model.fitRequested &+= 1
            } label: {
                Text("Fit Board", bundle: .module)
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(modalOpen)
            Divider()
        }

        CommandMenu(Text("Game", bundle: .module)) {
            Button {
                model.nearbyRequested &+= 1
            } label: {
                Text("Nearby Duel…", bundle: .module)
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(modalOpen || model.selection != .versus)

            Divider()

            Button {
                model.shareChallengeRequested &+= 1
            } label: {
                Text("Share Challenge…", bundle: .module)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(modalOpen || !model.canShareChallenge)
            Button {
                model.saveImageRequested &+= 1
            } label: {
                Text("Save Image…", bundle: .module)
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(modalOpen || !model.isGameOver)
        }
    }

    private struct Tab {
        let tab: AppModel.Tab
        let title: String
        let key: KeyEquivalent
    }
    private static let tabs: [Tab] = [
        Tab(tab: .free, title: "Free", key: "1"),
        Tab(tab: .daily, title: "Daily", key: "2"),
        Tab(tab: .versus, title: "Versus", key: "3"),
        Tab(tab: .history, title: "History", key: "4"),
    ]
}
