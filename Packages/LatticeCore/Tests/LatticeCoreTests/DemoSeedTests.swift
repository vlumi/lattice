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
        XCTAssertEqual(streak, 6, "six days including today")
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
