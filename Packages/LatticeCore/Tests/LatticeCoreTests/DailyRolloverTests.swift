import LatticeCore
import XCTest

@testable import LatticeKit

/// The daily session outlives a date change when the app stays alive — it has
/// to move on to the new day's board, not keep showing yesterday's.
final class DailyRolloverTests: XCTestCase {
    private let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

    func testFinishedDailyRollsOverToTheNewDay() throws {
        let store = LatticeStore.ephemeral()
        var log = DailyLog()
        log.record(DailyLog.Result(score: 30, finishedAt: Date()), for: DailyChallenge.dateKey())
        store.saveDailyLog(log)
        let session = GameSession(mode: .daily, store: store)
        XCTAssertTrue(session.dailyDone)

        session.rollOverDay(now: tomorrow)

        let key = DailyChallenge.dateKey(for: tomorrow)
        XCTAssertEqual(session.dailyKey, key)
        XCTAssertFalse(session.dailyDone, "the new day is playable")
        XCTAssertEqual(session.game.start, try XCTUnwrap(DailyChallenge.board(for: key)).start)
        XCTAssertTrue(session.game.moves.isEmpty)
        XCTAssertEqual(store.loadDailyAttempt()?.dateKey, key, "the new attempt is the one saved")
    }

    func testSameDayIsANoOp() throws {
        let session = GameSession(mode: .daily, store: .ephemeral())
        let move = try XCTUnwrap(session.movesByDot.values.first?.first)
        session.commit(move)

        session.rollOverDay(now: Date())

        XCTAssertEqual(session.game.moves.count, 1, "nothing to roll over to")
    }

    /// Midnight is a hard deadline: an unfinished board goes with its day,
    /// unrecorded — it never counts toward the streak.
    func testMidnightEndsAnAttemptInProgress() throws {
        let store = LatticeStore.ephemeral()
        let session = GameSession(mode: .daily, store: store)
        let move = try XCTUnwrap(session.movesByDot.values.first?.first)
        session.commit(move)

        session.rollOverDay(now: tomorrow)

        XCTAssertEqual(session.dailyKey, DailyChallenge.dateKey(for: tomorrow))
        XCTAssertTrue(session.game.moves.isEmpty)
        XCTAssertFalse(session.undoAllowed, "yesterday's armed undo doesn't carry over")
        XCTAssertTrue(store.loadDailyLog().results.isEmpty, "the unfinished day isn't recorded")
        XCTAssertTrue(store.loadRecords().isEmpty)
    }

    func testDeadlineFollowsTheBoardsDay() throws {
        let session = GameSession(mode: .daily, store: .ephemeral())
        session.rollOverDay(now: tomorrow)
        let deadline = try XCTUnwrap(session.dailyDeadline)
        XCTAssertGreaterThan(deadline, tomorrow)
        XCTAssertLessThanOrEqual(deadline.timeIntervalSince(tomorrow), 25 * 3600)
        XCTAssertNil(GameSession(mode: .free, store: .ephemeral()).dailyDeadline)
    }

    func testOtherModesIgnoreTheDate() throws {
        let session = GameSession(mode: .free, store: .ephemeral())
        let move = try XCTUnwrap(session.movesByDot.values.first?.first)
        session.commit(move)

        session.rollOverDay(now: tomorrow)

        XCTAssertEqual(session.game.moves.count, 1)
    }
}
