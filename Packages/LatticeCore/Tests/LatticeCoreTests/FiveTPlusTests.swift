import Foundation
import XCTest

@testable import LatticeCore

final class FiveTPlusTests: XCTestCase {
    // Five dots already in a row — a free line under "+" rules.
    private let row: Set<Point> = [
        Point(0, 0), Point(1, 0), Point(2, 0), Point(3, 0), Point(4, 0),
    ]
    private let rowLine = Line(origin: Point(0, 0), axis: .horizontal, length: 5)

    func testStorageKeysAndDecoding() throws {
        XCTAssertEqual(Rules.fiveTPlus.storageKey, "5T+")
        XCTAssertEqual(Rules.fiveT.storageKey, "5T")
        XCTAssertEqual(
            Rules.fiveTPlus.variantKey(forStart: StartingPattern.standardCross), "5T+")
        // Older saves have no `linked` field — they decode as classic.
        let legacy = try JSONDecoder().decode(
            Rules.self, from: Data(#"{"lineLength":5,"overlap":"T"}"#.utf8))
        XCTAssertEqual(legacy, .fiveT)
        XCTAssertTrue(legacy.linked)
    }

    func testFreeLineLegalOnlyWhenUnlinked() {
        let far = Point(10, 10)
        let freeMove = Move(dot: far, line: rowLine)
        var plus = Game(rules: .fiveTPlus, start: row)
        XCTAssertEqual(plus.freeLines(), [rowLine])
        XCTAssertTrue(plus.play(freeMove))
        XCTAssertEqual(plus.score, 1)

        var classic = Game(rules: .fiveT, start: row)
        XCTAssertTrue(classic.freeLines().isEmpty)
        XCTAssertFalse(classic.play(freeMove))
    }

    func testThroughDotMovesStillWork() {
        var plus = Game(
            rules: .fiveTPlus,
            start: [Point(1, 0), Point(2, 0), Point(3, 0), Point(4, 0)])
        // (1,0)…(4,0) exist; placing (5,0) completes a through-dot line.
        let move = Move(
            dot: Point(5, 0), line: Line(origin: Point(1, 0), axis: .horizontal, length: 5))
        XCTAssertTrue(plus.isLegal(move))
        XCTAssertTrue(plus.play(move))
    }

    func testEnumerationRepresentsFreeLines() {
        let plus = Game(rules: .fiveTPlus, start: row)
        XCTAssertFalse(plus.isOver)
        let moves = plus.legalMoves()
        XCTAssertTrue(
            moves.contains { $0.line == rowLine && !$0.line.points.contains($0.dot) },
            "a representative free-line move is enumerated")
        // Every enumerated move must be legal.
        for move in moves {
            XCTAssertTrue(plus.isLegal(move), "\(move)")
        }
    }

    func testSegmentReuseStillBinds() {
        var plus = Game(rules: .fiveTPlus, start: row)
        XCTAssertTrue(plus.play(Move(dot: Point(10, 10), line: rowLine)))
        // The same free line can't be drawn twice — its segments are spent.
        XCTAssertFalse(plus.isLegal(Move(dot: Point(11, 11), line: rowLine)))
        XCTAssertTrue(plus.freeLines().isEmpty)
    }

    func testOpennessCurveCountsRepresentatives() {
        var plus = Game(rules: .fiveTPlus, start: row)
        plus.play(Move(dot: Point(10, 10), line: rowLine))
        let curve = plus.opennessCurve()
        XCTAssertEqual(curve.count, 2)
        XCTAssertGreaterThan(curve[0], 0)
    }
}
