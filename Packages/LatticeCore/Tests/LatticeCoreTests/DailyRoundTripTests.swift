import XCTest

@testable import LatticeCore

/// The stamp has to survive the real store, not just an in-memory struct:
/// History reads records back off disk.
final class DailyRoundTripTests: XCTestCase {
    func testStampSurvivesSaveAndLoad() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let store = LatticeStore(directory: dir)
        let board = try XCTUnwrap(DailyChallenge.board(for: "2026-08-06"))

        store.saveRecord(
            GameRecord(
                game: Game(rules: board.rules, start: board.start), id: UUID(),
                finishedAt: Date(), dailyDateKey: "2026-08-06"))
        store.saveRecord(
            GameRecord(game: Game(rules: .fiveT), id: UUID(), finishedAt: Date()))

        let loaded = store.loadRecords()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.filter(\.isDaily).count, 1, "exactly one row should read as Daily")
        let daily = try XCTUnwrap(loaded.first(where: \.isDaily))
        XCTAssertEqual(daily.dailyDateKey, "2026-08-06")
        XCTAssertEqual(daily.variantKey, "5T#", "still scores in its shared pool")
        try? FileManager.default.removeItem(at: dir)
    }
}
