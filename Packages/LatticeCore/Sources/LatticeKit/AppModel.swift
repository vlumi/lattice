import Combine
import LatticeCore
import SwiftUI

/// App-wide state owned once by the platform `App` and shared by every scene —
/// the three game sessions, the sync controller, and board feedback. Having a
/// single owner lets the macOS Settings scene (a sibling window of the main
/// one) reach the same `sync`/`feedback` the game window uses, and gives the
/// selected tab a home the app's menu commands can drive.
@MainActor
public final class AppModel: ObservableObject {
    /// Main-window tabs. Settings is a tab on iOS; on macOS it's a separate
    /// Settings window, so it's absent from this set there.
    public enum Tab: Hashable {
        case free
        case daily
        case versus
        case history
        #if !os(macOS)
        case settings
        #endif
    }

    public let store: LatticeStore
    public let freeSession: GameSession
    public let dailySession: GameSession
    public let versusSession: GameSession
    public let sync: SyncController
    // Internal: Feedback isn't public, and only in-package views (SettingsScene,
    // RootView's environmentObject) read it.
    let feedback: Feedback

    @Published public var selection: Tab = .free
    /// macOS: whether the Settings sheet is shown (opened by the app's ⌘,
    /// command). iOS has Settings as a tab instead, so this is unused there.
    @Published public var isShowingSettings = false

    public init(store: LatticeStore = .appSupport()) {
        self.store = store
        freeSession = GameSession(mode: .free, store: store)
        dailySession = GameSession(mode: .daily, store: store)
        versusSession = GameSession(mode: .passAndPlay, store: store)
        sync = SyncController(store: store, cloud: Self.makeCloud())
        feedback = Feedback()

        // Route finished-game persistence into sync (no-op when sync is off).
        freeSession.onSyncedChange = { [weak sync] in sync?.localDidChange() }
        dailySession.onSyncedChange = { [weak sync] in sync?.localDidChange() }
    }

    /// A cloud pull changed local bests/daily — refresh the live sessions.
    public func reloadSyncedState() {
        freeSession.reloadSyncedState()
        dailySession.reloadSyncedState()
    }

    /// A challenge universal-link: start its board in Free and switch there.
    public func openChallenge(seed: UInt64) {
        freeSession.newChallenge(seed: seed)
        selection = .free
    }

    private static func makeCloud() -> CloudStore {
        #if os(Linux)
        return FakeCloudStore(isAvailable: false)
        #else
        return UbiquitousCloudStore()
        #endif
    }
}
