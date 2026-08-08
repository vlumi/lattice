import Foundation
import XCTest

@testable import LatticeCore

/// Prototype detector: when a move's line ends 1–4 dots from another collinear
/// drawn line, the gap between them is dead (no line can ever span it).
final class ForeclosureTests: XCTestCase {
    private func record(start: Set<Point>, moves: [Move]) -> GameRecord {
        var g = Game(rules: .fiveT, start: start)
        for m in moves { _ = g.play(m) }
        return GameRecord(game: g, id: UUID(), finishedAt: Date(timeIntervalSince1970: 1))
    }

    /// A horizontal 5-line starting at (x, 0).
    private func hLine(_ x: Int) -> Line { Line(origin: Point(x, 0), axis: .horizontal, length: 5) }

    /// The move that draws the horizontal 5-line at column `x`, placing its
    /// last dot (so the preceding four already exist in `start`).
    private func hMove(_ x: Int) -> Move { Move(dot: Point(x + 4, 0), line: hLine(x)) }

    func testNoNearbyLineNoLoss() {
        // One line, nothing else on the axis → nothing dead.
        let dots: Set<Point> = [Point(0, 0), Point(1, 0), Point(2, 0), Point(3, 0)]
        XCTAssertTrue(Foreclosure.losses(in: record(start: dots, moves: [hMove(0)])).isEmpty)
    }

    func testGapBetweenTwoCollinearLinesIsDead() {
        // Left line cols 0–4, right line cols 6–10: a one-dot gap at col 5.
        // Drawing the second line seals it — dead span from col 4 to col 6.
        let dots: Set<Point> = [
            0, 1, 2, 3, 6, 7, 8, 9,  // the pre-existing dots of both runs
        ].reduce(into: Set<Point>()) { $0.insert(Point($1, 0)) }
        let losses = Foreclosure.losses(in: record(start: dots, moves: [hMove(0), hMove(6)]))
        XCTAssertEqual(losses.count, 1)
        XCTAssertEqual(losses.first?.moveIndex, 1)  // the SECOND line sealed it
        // Dead span: from the first line's end (4,0) to the second's start (6,0).
        XCTAssertEqual(losses.first?.span, Line(origin: Point(4, 0), axis: .horizontal, length: 3))
    }

    func testLinesFiveApartLeaveNoDeadGap() {
        // Left cols 0–4, right cols 10–14: a 5-dot gap (cols 5–9) — that's room
        // for a whole line, so it is NOT dead.
        let dots: Set<Point> = [
            0, 1, 2, 3, 10, 11, 12, 13,
        ].reduce(into: Set<Point>()) { $0.insert(Point($1, 0)) }
        let losses = Foreclosure.losses(in: record(start: dots, moves: [hMove(0), hMove(10)]))
        XCTAssertTrue(losses.isEmpty)
    }

    func testSealingLineDrawnBeforeAnExistingLine() {
        // Reverse order: draw the RIGHT line first, then the LEFT — so the
        // sealing (second) line has the other line AHEAD of it on the axis.
        // Same one-dot gap at col 5, same dead span; exercises the other
        // end-scan direction.
        let dots: Set<Point> = [
            0, 1, 2, 3, 6, 7, 8, 9,
        ].reduce(into: Set<Point>()) { $0.insert(Point($1, 0)) }
        let losses = Foreclosure.losses(in: record(start: dots, moves: [hMove(6), hMove(0)]))
        XCTAssertEqual(losses.count, 1)
        XCTAssertEqual(losses.first?.moveIndex, 1)
        XCTAssertEqual(losses.first?.span, Line(origin: Point(4, 0), axis: .horizontal, length: 3))
    }

    func testLiveGameOverloadMatchesRecord() {
        // The Game-based overload (used by the live board) sees the same losses.
        let dots: Set<Point> = [
            0, 1, 2, 3, 6, 7, 8, 9,
        ].reduce(into: Set<Point>()) { $0.insert(Point($1, 0)) }
        var game = Game(rules: .fiveT, start: dots)
        _ = game.play(hMove(0))
        _ = game.play(hMove(6))
        let losses = Foreclosure.losses(in: game)
        XCTAssertEqual(losses.count, 1)
        XCTAssertEqual(losses.first?.span, Line(origin: Point(4, 0), axis: .horizontal, length: 3))
    }
}
