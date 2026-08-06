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
            GameView(session: freeSession)
                .tabItem {
                    Label {
                        Text("Free", bundle: .module)
                    } icon: {
                        Image(systemName: "circle.grid.3x3")
                    }
                }
                .tag(Tab.free)
            GameView(session: dailySession)
                .tabItem {
                    Label {
                        Text("Daily", bundle: .module)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
                .tag(Tab.daily)
            GameView(session: versusSession)
                .tabItem {
                    Label {
                        Text("Versus", bundle: .module)
                    } icon: {
                        Image(systemName: "person.2")
                    }
                }
                .tag(Tab.versus)
            HistoryView(store: Self.store, path: $historyPath)
                .tabItem {
                    Label {
                        Text("History", bundle: .module)
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                .tag(Tab.history)
            SettingsView(sync: sync, feedback: feedback)
                .tabItem {
                    Label {
                        Text("Settings", bundle: .module)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
                .tag(Tab.settings)
        }
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
}
