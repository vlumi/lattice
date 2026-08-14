import XCTest

@testable import LatticeCore

final class GameRecordDailyTests: XCTestCase {
    private func record(dailyDateKey: String?) -> GameRecord {
        GameRecord(
            game: Game(rules: .fiveT), id: UUID(), finishedAt: Date(),
            dailyDateKey: dailyDateKey)
    }

    func testStampedRecordIsDaily() {
        let rec = record(dailyDateKey: "2026-08-06")
        XCTAssertTrue(rec.isDaily)
        XCTAssertEqual(rec.dailyDateKey, "2026-08-06")
    }

    func testUnstampedRecordIsNotDaily() {
        XCTAssertFalse(record(dailyDateKey: nil).isDaily)
    }

    /// The stamp is display only — a daily still scores in its shared pool.
    func testDailyKeepsItsScoringPool() {
        let board = DailyChallenge.board(for: "2026-08-06")!
        let rec = GameRecord(
            game: Game(rules: board.rules, start: board.start), id: UUID(),
            finishedAt: Date(), dailyDateKey: "2026-08-06")
        XCTAssertEqual(rec.variantKey, "5T#")
    }

    /// Records written before the field existed must still decode.
    func testDecodesLegacyRecordWithoutTheField() throws {
        let legacy = """
            {"version":1,"id":"\(UUID().uuidString)","rules":{"lineLength":5,\
            "overlap":"T","linked":true},"start":[],"moves":[],"score":7,\
            "finishedAt":0}
            """
        let rec = try JSONDecoder().decode(GameRecord.self, from: Data(legacy.utf8))
        XCTAssertNil(rec.dailyDateKey)
        XCTAssertFalse(rec.isDaily)
        XCTAssertEqual(rec.score, 7)
    }
}
