import XCTest

@testable import LatticeCore

final class DailyTests: XCTestCase {
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ key: String) -> Date {
        DailyLog.date(of: key, calendar: utc)!
    }

    func testDateKeyFormat() {
        XCTAssertEqual(
            DailyChallenge.dateKey(for: date("2026-08-05"), calendar: utc), "2026-08-05")
        XCTAssertEqual(
            DailyChallenge.dateKey(for: date("2027-01-01"), calendar: utc), "2027-01-01")
    }

    func testBoardExistsFromEpoch() {
        XCTAssertNil(DailyChallenge.board(for: "2026-07-20"))
        // The classic-cross era: the epoch day itself.
        let board = DailyChallenge.board(for: DailyChallenge.epochKey)
        XCTAssertEqual(board?.rules, .fiveT)
        XCTAssertEqual(board?.start, StartingPattern.standardCross)
    }

    func testGeneratedDaysVary() {
        let first = DailyChallenge.board(for: "2026-07-22")
        let second = DailyChallenge.board(for: "2026-07-23")
        XCTAssertEqual(first?.rules, .fiveT)
        XCTAssertEqual(first?.start.count, 36)
        XCTAssertNotEqual(first?.start, second?.start)
        XCTAssertNotEqual(first?.start, StartingPattern.standardCross)
        // Deterministic: the same key is the same board.
        XCTAssertEqual(first?.start, DailyChallenge.board(for: "2026-07-22")?.start)
    }

    func testStreakCountsBackFromToday() {
        var log = DailyLog()
        log.record(.init(score: 10, finishedAt: date("2026-08-03")), for: "2026-08-03")
        log.record(.init(score: 12, finishedAt: date("2026-08-04")), for: "2026-08-04")
        log.record(.init(score: 9, finishedAt: date("2026-08-05")), for: "2026-08-05")
        XCTAssertEqual(log.streak(today: "2026-08-05", calendar: utc), 3)
    }

    func testUnplayedTodayFallsBackToYesterday() {
        var log = DailyLog()
        log.record(.init(score: 10, finishedAt: date("2026-08-03")), for: "2026-08-03")
        log.record(.init(score: 12, finishedAt: date("2026-08-04")), for: "2026-08-04")
        XCTAssertEqual(log.streak(today: "2026-08-05", calendar: utc), 2)
    }

    func testGapBreaksStreak() {
        var log = DailyLog()
        log.record(.init(score: 10, finishedAt: date("2026-08-01")), for: "2026-08-01")
        log.record(.init(score: 12, finishedAt: date("2026-08-03")), for: "2026-08-03")
        XCTAssertEqual(log.streak(today: "2026-08-03", calendar: utc), 1)
        XCTAssertEqual(log.streak(today: "2026-08-05", calendar: utc), 0)
    }

    func testMonthBoundaryStreak() {
        var log = DailyLog()
        log.record(.init(score: 10, finishedAt: date("2026-07-31")), for: "2026-07-31")
        log.record(.init(score: 12, finishedAt: date("2026-08-01")), for: "2026-08-01")
        XCTAssertEqual(log.streak(today: "2026-08-01", calendar: utc), 2)
    }

    func testDailyAttemptRoundTripAndDateBinding() {
        let store = LatticeStore.ephemeral()
        var game = Game()
        game.play(game.legalMoves().min { ($0.dot.x, $0.dot.y) < ($1.dot.x, $1.dot.y) }!)
        let attempt = DailyAttempt(
            dateKey: "2026-08-05", snapshot: GameSnapshot(game: game, id: UUID()))
        store.saveDailyAttempt(attempt)
        let loaded = store.loadDailyAttempt()
        XCTAssertEqual(loaded?.dateKey, "2026-08-05")
        XCTAssertEqual(loaded.flatMap { Game(snapshot: $0.snapshot) }, game)
        store.clearDailyAttempt()
        XCTAssertNil(store.loadDailyAttempt())
    }

    func testDailyLogPersistence() {
        let store = LatticeStore.ephemeral()
        var log = DailyLog()
        log.record(.init(score: 42, finishedAt: date("2026-08-05")), for: "2026-08-05")
        store.saveDailyLog(log)
        XCTAssertEqual(store.loadDailyLog(), log)
    }
}
