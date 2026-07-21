import Foundation
import XCTest

@testable import LatticeCore

final class AnalysisTests: XCTestCase {
    private func finishedRecord() -> GameRecord {
        var game = Game()
        while let move = game.legalMoves().min(by: Self.moveOrder) {
            game.play(move)
        }
        return GameRecord(game: game, id: UUID(), finishedAt: Date(timeIntervalSince1970: 0))
    }

    private static func moveOrder(_ a: Move, _ b: Move) -> Bool {
        (a.dot.x, a.dot.y, a.line.origin.x, a.line.origin.y)
            < (b.dot.x, b.dot.y, b.line.origin.x, b.line.origin.y)
    }

    func testCurveShape() {
        let record = finishedRecord()
        let curve = record.legalMoveCurve()
        XCTAssertEqual(curve.count, record.moves.count + 1)
        XCTAssertEqual(curve.first, 28, "the standard cross opens with 28 moves")
        XCTAssertEqual(curve.last, 0, "a finished game ends with none")
        XCTAssertGreaterThanOrEqual(curve.max() ?? 0, 28, "the peak is at least the start")
    }

    func testCurveOnCorruptRecordStopsEarly() throws {
        let record = finishedRecord()
        var json =
            try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(record)) as? [String: Any])
        var moves =
            try XCTUnwrap(
                JSONSerialization.jsonObject(with: JSONEncoder().encode(record.moves))
                    as? [[String: Any]])
        moves.swapAt(0, moves.count - 1)  // out-of-order moves become illegal
        json["moves"] = moves
        let corrupt = try JSONDecoder().decode(
            GameRecord.self,
            from: JSONSerialization.data(withJSONObject: json))
        let curve = corrupt.legalMoveCurve()
        XCTAssertLessThan(curve.count, corrupt.moves.count + 1)
    }
}
