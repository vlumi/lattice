import Combine
import LatticeCore
import SwiftUI

/// App-wide state owned once by the platform `App` and shared by every scene —
/// the three game sessions, the sync controller, and board feedback. A single
/// owner lets the macOS Settings sheet reach the same `sync`/`feedback` the
/// game uses, and gives `selection` a home the app's View-menu commands drive.
@MainActor
public final class AppModel: ObservableObject {
    /// Main-window tabs. Settings is a tab on iOS; on macOS it's a modal sheet,
    /// so it's absent from this set there.
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
    /// The About sheet (macOS app menu, or the Settings row on both platforms).
    @Published public var isShowingAbout = false

    // Menu-command intents, routed to the active GameView (which observes and
    // acts). Counters, not Bools, so a repeated press fires each time. This is
    // how the app menu (LatticeCommands) drives the same actions as the chrome.
    @Published public var newGameRequested = 0
    @Published public var restartRequested = 0
    @Published public var undoRequested = 0
    @Published public var fitRequested = 0
    @Published public var nearbyRequested = 0
    @Published public var shareChallengeRequested = 0  // opens the code/QR popover
    @Published public var saveImageRequested = 0  // game-over PNG export

    // Availability for the menu (published so it enables/disables live).
    /// The active game is a seeded challenge (has a code to share).
    @Published public var canShareChallenge = false
    /// The active game is over (Save Image applies).
    @Published public var isGameOver = false

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
