import LatticeCore
import SwiftUI

/// The app root: the game tabs (and, on iOS, Settings) over one shared
/// `AppModel` — sessions keep their state alive across tab switches. On macOS
/// Settings is a separate window (the `Settings` scene), not a tab.
public struct RootView: View {
    @ObservedObject private var model: AppModel
    @State private var historyPath = NavigationPath()
    /// "?" reveals keyboard shortcuts app-wide (the board cheatsheet + the
    /// floating-control badges in GameView).
    @State private var showShortcuts = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        TabView(selection: selectionResettingHistory) {
            GameView(session: model.freeSession, showShortcuts: $showShortcuts)
                .tabItem { tabLabel("Free", "circle.grid.3x3") }
                .tag(AppModel.Tab.free)
            GameView(session: model.dailySession, showShortcuts: $showShortcuts)
                .tabItem { tabLabel("Daily", "calendar") }
                .tag(AppModel.Tab.daily)
            GameView(session: model.versusSession, showShortcuts: $showShortcuts)
                .tabItem { tabLabel("Versus", "person.2") }
                .tag(AppModel.Tab.versus)
            HistoryView(store: model.store, path: $historyPath)
                .tabItem { tabLabel("History", "clock.arrow.circlepath") }
                .tag(AppModel.Tab.history)
            #if !os(macOS)
            // iOS keeps Settings as a tab; on macOS it's the standard Settings
            // window instead (see the app's `Settings` scene).
            SettingsView(sync: model.sync, feedback: model.feedback)
                .tabItem { tabLabel("Settings", "gearshape") }
                .tag(AppModel.Tab.settings)
            #endif
        }
        .background(tabShortcuts(selectionResettingHistory))
        .background(ShortcutToggle(showShortcuts: $showShortcuts))
        // Board feedback (sound + haptics) available to the board views.
        .environmentObject(model.feedback)
        // macOS: Settings is a modal sheet on the game window (⌘, from the app
        // menu, via the app's command). A sheet can't be orphaned or outlive
        // the game, unlike a separate Settings window. iOS uses the tab above.
        #if os(macOS)
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsScene(model: model, done: { model.isShowingSettings = false })
        }
        #endif
        // Universal Links: a challenge link starts its board in Free.
        .onOpenURL { url in
            guard let seed = ChallengeLink.seed(from: url) else { return }
            model.openChallenge(seed: seed)
        }
        // A cloud pull changed local bests/daily — refresh the live sessions.
        // onChangeCompat bridges the iOS-16 floor without the macOS-14
        // deprecation (copied from Donpa; see Support/OnChangeCompat).
        .onChangeCompat(of: model.sync.revision) { _ in
            model.reloadSyncedState()
        }
    }

    // Arriving at the History tab (or re-tapping it, where the platform reports
    // that) always lands on the list, not a parked replay.
    private var selectionResettingHistory: Binding<AppModel.Tab> {
        Binding(
            get: { model.selection },
            set: { newValue in
                if newValue == .history { historyPath = NavigationPath() }
                model.selection = newValue
            })
    }

    // A plain tab item. (Tab shortcuts are shown in the "?" cheatsheet — native
    // tab items can't carry a floating badge.)
    private func tabLabel(_ title: LocalizedStringKey, _ icon: String) -> some View {
        Label {
            Text(title, bundle: .module)
        } icon: {
            Image(systemName: icon)
        }
    }

    // Keyboard tab switching via hidden buttons (the iOS-16-safe pattern; the
    // binding resets History to its list like a tap does). On macOS, Settings
    // is a window with its own native ⌘, — the tabs are ⌘1–⌘4. On iOS Settings
    // is the ⌘5 tab.
    private func tabShortcuts(_ selection: Binding<AppModel.Tab>) -> some View {
        var tabs: [(KeyEquivalent, AppModel.Tab)] = [
            ("1", .free), ("2", .daily), ("3", .versus), ("4", .history),
        ]
        #if !os(macOS)
        tabs.append(("5", .settings))
        #endif
        return Group {
            ForEach(Array(tabs.enumerated()), id: \.offset) { _, entry in
                Button {
                    selection.wrappedValue = entry.1
                } label: {
                    Color.clear.frame(width: 1, height: 1)
                }
                .keyboardShortcut(entry.0, modifiers: .command)
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}
