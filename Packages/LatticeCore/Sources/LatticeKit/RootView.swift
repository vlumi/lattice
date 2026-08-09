import LatticeCore
import SwiftUI

/// The app root: Free, Daily, and History as tabs — the game tabs keep
/// their sessions and cameras alive across switches, all over one store.
public struct RootView: View {
    private enum Tab {
        case free
        case daily
        case versus
        case history
        case settings
    }

    private static let store = LatticeStore.appSupport()

    @StateObject private var freeSession = GameSession(mode: .free, store: store)
    @StateObject private var dailySession = GameSession(mode: .daily, store: store)
    @StateObject private var versusSession = GameSession(mode: .passAndPlay, store: store)
    @StateObject private var sync = SyncController(store: store, cloud: Self.makeCloud())
    @StateObject private var feedback = Feedback()
    @State private var selection: Tab = .free
    @State private var historyPath = NavigationPath()
    /// "?" reveals keyboard shortcuts app-wide (the board cheatsheet + the
    /// floating-control badges in GameView).
    @State private var showShortcuts = false

    public init() {}

    private static func makeCloud() -> CloudStore {
        #if os(Linux)
        return FakeCloudStore(isAvailable: false)
        #else
        return UbiquitousCloudStore()
        #endif
    }

    public var body: some View {
        // Arriving at the History tab (or re-tapping it, where the platform
        // reports that) always lands on the list, not a parked replay.
        let selectionResettingHistory = Binding(
            get: { selection },
            set: { (newValue: Tab) in
                if newValue == .history { historyPath = NavigationPath() }
                selection = newValue
            })
        TabView(selection: selectionResettingHistory) {
            GameView(session: freeSession, showShortcuts: $showShortcuts)
                .tabItem { tabLabel("Free", "circle.grid.3x3") }
                .tag(Tab.free)
            GameView(session: dailySession, showShortcuts: $showShortcuts)
                .tabItem { tabLabel("Daily", "calendar") }
                .tag(Tab.daily)
            GameView(session: versusSession, showShortcuts: $showShortcuts)
                .tabItem { tabLabel("Versus", "person.2") }
                .tag(Tab.versus)
            HistoryView(store: Self.store, path: $historyPath)
                .tabItem { tabLabel("History", "clock.arrow.circlepath") }
                .tag(Tab.history)
            SettingsView(sync: sync, feedback: feedback)
                .tabItem { tabLabel("Settings", "gearshape") }
                .tag(Tab.settings)
        }
        .background(tabShortcuts(selectionResettingHistory))
        .background(
            ShortcutToggle(showShortcuts: $showShortcuts)
        )
        // Board feedback (sound + haptics) available to the board views.
        .environmentObject(feedback)
        // Universal Links: a challenge link starts its board in Free.
        .onOpenURL { url in
            guard let seed = ChallengeLink.seed(from: url) else { return }
            freeSession.newChallenge(seed: seed)
            selection = .free
        }
        // Route finished-game persistence into sync (no-op when sync is off).
        .onAppear {
            freeSession.onSyncedChange = { [weak sync] in sync?.localDidChange() }
            dailySession.onSyncedChange = { [weak sync] in sync?.localDidChange() }
        }
        // A cloud pull changed local bests/daily — refresh the live sessions.
        // onChangeCompat bridges the iOS-16 floor without the macOS-14
        // deprecation (copied from Donpa; see Support/OnChangeCompat).
        .onChangeCompat(of: sync.revision) { _ in
            freeSession.reloadSyncedState()
            dailySession.reloadSyncedState()
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

    // Keyboard tab switching: ⌘1–⌘5 select the tabs; ⌘, also opens Settings
    // (the macOS Preferences convention). Hidden buttons — the iOS-16-safe
    // pattern; the binding resets History to its list like a tap does.
    private func tabShortcuts(_ selection: Binding<Tab>) -> some View {
        let tabs: [(KeyEquivalent, Tab)] = [
            ("1", .free), ("2", .daily), ("3", .versus), ("4", .history), ("5", .settings),
        ]
        return Group {
            ForEach(Array(tabs.enumerated()), id: \.offset) { _, entry in
                Button {
                    selection.wrappedValue = entry.1
                } label: {
                    Color.clear.frame(width: 1, height: 1)
                }
                .keyboardShortcut(entry.0, modifiers: .command)
            }
            Button {
                selection.wrappedValue = .settings
            } label: {
                Color.clear.frame(width: 1, height: 1)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}
