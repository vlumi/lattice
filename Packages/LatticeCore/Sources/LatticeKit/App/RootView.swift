import LatticeCore
import SwiftUI

/// The app root: the game tabs (and, on iOS, Settings) over one shared
/// `AppModel` — sessions keep their state alive across tab switches. On macOS
/// Settings is a modal sheet (not a tab), and the tabs are also reachable from
/// the native View menu (which drives `model.selection` directly).
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
        TabView(selection: $model.selection) {
            GameView(
                session: model.freeSession, model: model, tab: .free,
                showShortcuts: $showShortcuts
            )
            .tabItem { tabLabel("Free", "circle.grid.3x3") }
            .tag(AppModel.Tab.free)
            GameView(
                session: model.dailySession, model: model, tab: .daily,
                showShortcuts: $showShortcuts
            )
            .tabItem { tabLabel("Daily", "calendar") }
            .tag(AppModel.Tab.daily)
            GameView(
                session: model.versusSession, model: model, tab: .versus,
                showShortcuts: $showShortcuts
            )
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
        .background(ShortcutToggle(showShortcuts: $showShortcuts))
        // Board feedback (sound + haptics) available to the board views.
        .environmentObject(model.feedback)
        // Arriving at History (a tab tap, ⌘4, or the View menu — any route that
        // changes selection) always lands on the list, not a parked replay.
        .onChangeCompat(of: model.selection) { newValue in
            if newValue == .history { historyPath = NavigationPath() }
        }
        // macOS: Settings is a modal sheet on the game window (⌘, from the app
        // menu, via the app's command). A sheet can't be orphaned or outlive
        // the game, unlike a separate Settings window. iOS uses the tab above.
        #if os(macOS)
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsScene(model: model, done: { model.isShowingSettings = false })
        }
        #endif
        // About: the macOS app menu opens it here; the Settings row on both
        // platforms presents its own copy from inside that sheet/tab.
        .sheet(isPresented: $model.isShowingAbout) {
            AboutSheet(dismiss: { model.isShowingAbout = false })
        }
        // Help: the macOS Help menu (⌘?) and the iOS Settings row both land here.
        .sheet(isPresented: $model.isShowingHowTo) {
            HowToPlaySheet(dismiss: { model.isShowingHowTo = false })
        }
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

    // A plain tab item. (Tab shortcuts are shown in the "?" cheatsheet — native
    // tab items can't carry a floating badge.)
    private func tabLabel(_ title: LocalizedStringKey, _ icon: String) -> some View {
        Label {
            Text(title, bundle: .module)
        } icon: {
            Image(systemName: icon)
        }
    }

}
