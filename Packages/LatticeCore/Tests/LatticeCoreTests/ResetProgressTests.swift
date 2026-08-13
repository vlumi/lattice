import LatticeCore
import XCTest

@testable import LatticeKit

/// Resetting progress is destructive and, with sync on, reaches other devices —
/// so pin down exactly what it clears, what it keeps, and that the cloud copy
/// can't resurrect it.
final class ResetProgressTests: XCTestCase {
    private func store() -> LatticeStore {
        .ephemeral()
    }

    func testWipeClearsBestsRecordsAndDaily() throws {
        let store = store()
        var bests = BestScores()
        _ = bests.register(42, forKey: "5T")
        store.saveBests(bests)
        var log = DailyLog()
        log.record(DailyLog.Result(score: 30, finishedAt: Date()), for: "2026-08-13")
        store.saveDailyLog(log)
        let game = Game(rules: .fiveT)
        store.saveRecord(GameRecord(game: game, id: UUID(), finishedAt: Date()))
        store.saveCurrent(GameSnapshot(game: game, id: UUID(), seed: nil))

        XCTAssertNotNil(store.loadBests().best(forKey: "5T"))
        XCTAssertEqual(store.loadRecords().count, 1)
        XCTAssertNotNil(store.loadCurrent())

        store.wipeAllProgress()

        XCTAssertNil(store.loadBests().best(forKey: "5T"), "bests gone")
        XCTAssertTrue(store.loadRecords().isEmpty, "replays gone")
        XCTAssertNil(store.loadCurrent(), "in-progress game gone")
        XCTAssertTrue(store.loadDailyLog().results.isEmpty, "daily log gone")
    }

    /// Records live in a directory the store recreates — saving after a wipe has
    /// to keep working, not fail because the directory vanished.
    func testStoreStillUsableAfterWipe() {
        let store = store()
        store.wipeAllProgress()
        let game = Game(rules: .fiveT)
        store.saveRecord(GameRecord(game: game, id: UUID(), finishedAt: Date()))
        XCTAssertEqual(store.loadRecords().count, 1, "the store works after a wipe")
    }

    /// The reason order matters: with a stale cloud blob, the next merge takes
    /// max-of-bests and brings the wiped scores straight back.
    func testCloudBlobWouldResurrectBestsIfLeftBehind() {
        let cloud = FakeCloudStore()
        var old = BestScores()
        _ = old.register(99, forKey: "5T")
        cloud.inject(SyncedState(bests: old, dailyLog: DailyLog()).encoded()!)

        let store = store()
        let bridge = StoreBridgeStub(store: store)
        let coordinator = SyncCoordinator(local: bridge, cloud: cloud, enabled: true)

        // Local wipe only, cloud left alone — the merge resurrects it.
        store.wipeAllProgress()
        coordinator.localDidChange()
        XCTAssertEqual(store.loadBests().best(forKey: "5T"), 99, "resurrected, as feared")

        // Now wipe the cloud first, as resetAllProgress does.
        XCTAssertTrue(coordinator.wipeCloud())
        store.wipeAllProgress()
        coordinator.localDidChange()
        XCTAssertNil(store.loadBests().best(forKey: "5T"), "stays gone")
    }

    /// Sync off (or iCloud away) means the cloud is deliberately untouched, and
    /// the UI must say the reset is this-device-only.
    func testWipeCloudReportsFalseWhenSyncIsOff() {
        let cloud = FakeCloudStore()
        let coordinator = SyncCoordinator(
            local: StoreBridgeStub(store: store()), cloud: cloud, enabled: false)
        XCTAssertFalse(coordinator.wipeCloud())
    }

    private final class StoreBridgeStub: SyncCoordinator.LocalState {
        let store: LatticeStore
        init(store: LatticeStore) { self.store = store }
        func load() -> SyncedState { store.loadSyncedState() }
        func save(_ state: SyncedState) { store.saveSyncedState(state) }
    }
}
