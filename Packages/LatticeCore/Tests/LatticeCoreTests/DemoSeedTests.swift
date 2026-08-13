import LatticeCore
import XCTest

@testable import LatticeKit

/// The demo fixtures back the App Store screenshots, so they have to be
/// deterministic (same picture on every device) and — more importantly — unable
/// to reach real player data.
@MainActor
final class DemoSeedTests: XCTestCase {
    /// Without the launch args, demo mode is inert and the app uses the real
    /// container. This is the property that keeps a debug run from wiping the
    /// player's history, which has happened before.
    func testInertWithoutLaunchArguments() {
        XCTAssertFalse(DemoMode.isClean)
        XCTAssertFalse(DemoMode.isSeeded)
        XCTAssertTrue(DemoMode.defaults === UserDefaults.standard)
    }

    func testSeedFillsBestsRecordsAndStreak() {
        let store = LatticeStore.ephemeral()
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        DemoSeed.apply(store: store, defaults: defaults)

        let records = store.loadRecords()
        XCTAssertEqual(records.count, 8, "one record per fixture game")
        XCTAssertTrue(records.allSatisfy { $0.score > 0 }, "every game actually played")

        let bests = store.loadBests()
        XCTAssertNotNil(bests.best(forKey: "5T"), "classic pool has a best")

        let streak = store.loadDailyLog().streak(today: DailyChallenge.dateKey())
        XCTAssertEqual(streak, 5, "five days ending yesterday")
        XCTAssertNil(
            store.loadDailyLog().results[DailyChallenge.dateKey()],
            "today deliberately unplayed, so the Daily tab shows its fresh board")
    }

    /// Same fixtures twice must give the same scores, or the iPhone and iPad
    /// screenshots won't match.
    func testSeedIsDeterministic() {
        func scores() -> [Int] {
            let store = LatticeStore.ephemeral()
            DemoSeed.apply(
                store: store, defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
            return store.loadRecords().map(\.score).sorted()
        }
        XCTAssertEqual(scores(), scores(), "identical on every device")
    }

    /// The replays have to be scrubbable and chartable, not just score numbers.
    func testRecordsCarryRealMoves() {
        let store = LatticeStore.ephemeral()
        DemoSeed.apply(
            store: store, defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
        for record in store.loadRecords() {
            XCTAssertEqual(record.moves.count, record.score, "moves match the score")
            XCTAssertFalse(record.legalMoveCurve().isEmpty, "openness curve chartable")
        }
    }
}

extension DemoSeedTests {
    /// Report what the fixtures actually score, so a dead-end short of target is
    /// visible rather than silently shipping a weak-looking History chart.
    func testFixtureScoresReachTheirTargets() {
        let store = LatticeStore.ephemeral()
        DemoSeed.apply(
            store: store, defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
        let scores = store.loadRecords().map(\.score).sorted()
        print("demo fixture scores: \(scores)")
        print("total moves: \(store.loadRecords().reduce(0) { $0 + $1.moves.count })")
        XCTAssertGreaterThanOrEqual(scores.max() ?? 0, 40, "top game should look respectable")
    }
}

extension DemoSeedTests {
    /// The listing's lead shot is a mid-game board, so the demo has to open on
    /// one — and it must still have moves available.
    func testFreeBoardIsInProgressAndPlayable() {
        let store = LatticeStore.ephemeral()
        DemoSeed.apply(
            store: store, defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
        let snapshot = try? XCTUnwrap(store.loadCurrent())
        let game = try? XCTUnwrap(snapshot.flatMap(Game.init(snapshot:)))
        XCTAssertGreaterThan(game?.score ?? 0, 20, "reads as a played board")
        XCTAssertFalse(
            game?.legalMoves().isEmpty ?? true, "still playable — a dead board sells nothing")
    }

    /// Dates must not drift between captures on different days.
    func testHistoryDatesAreFixed() {
        func dates() -> [Date] {
            let store = LatticeStore.ephemeral()
            DemoSeed.apply(
                store: store, defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)
            return store.loadRecords().map(\.finishedAt).sorted()
        }
        XCTAssertEqual(dates(), dates(), "same dates every run, on every device")
        XCTAssertLessThan(
            dates().last!, Date(), "the demo's history is in the past, not the future")
    }
}

extension DemoSeedTests {
    /// The three screens the demo has to stage correctly, asserted together so
    /// the intent is visible in one place.
    func testDemoStagesFreeInProgressAndDailyFresh() throws {
        let store = LatticeStore.ephemeral()
        DemoSeed.apply(
            store: store, defaults: UserDefaults(suiteName: "t.\(UUID().uuidString)")!)

        // Free: partway through a real game.
        let current = try XCTUnwrap(store.loadCurrent())
        let free = try XCTUnwrap(Game(snapshot: current))
        XCTAssertGreaterThan(free.score, 20)

        // Daily: no attempt today, so the tab opens on the day's fresh board.
        XCTAssertNil(store.loadDailyAttempt(), "no attempt in progress")
        XCTAssertNil(
            store.loadDailyLog().results[DailyChallenge.dateKey()], "today unplayed")

        // …but the streak is live, because an unplayed today doesn't break it.
        XCTAssertEqual(store.loadDailyLog().streak(today: DailyChallenge.dateKey()), 5)
    }
}
