import LatticeCore
import XCTest

/// The help diagrams claim specific rules ("Allowed" / "Not allowed"). Assert
/// the ENGINE agrees, so a diagram can never teach a rule the game doesn't have.
final class DiagramTruthTests: XCTestCase {
    private func run(_ y: Int, from x0: Int, count: Int) -> Set<Point> {
        Set((0..<count).map { Point(x0 + $0, y) })
    }

    private func hLine(_ x0: Int, _ y: Int = 0) -> Line {
        Line(origin: Point(x0, y), axis: .horizontal, length: 5)
    }

    /// Plays the first line of a two-line diagram. `present` seeds every dot the
    /// diagram shows EXCEPT the ones each move places, since a move's dot must
    /// be new.
    private func gameWithFirstLine(_ rules: Rules, present: Set<Point>) -> Game {
        var game = Game(rules: rules, start: present)
        XCTAssertTrue(
            game.play(Move(dot: Point(0, 0), line: hLine(-4))),
            "setup: the first line should be legal")
        return game
    }

    /// "Lines may touch, but never overlap" — 5T, sharing one end dot.
    func testSharingAnEndDotIsLegalIn5T() {
        // -4…3 present; x=0 and x=4 are the two moves' new dots.
        let game = gameWithFirstLine(
            .fiveT, present: run(0, from: -4, count: 4).union(run(0, from: 1, count: 3)))
        let touching = Move(dot: Point(4, 0), line: hLine(0))
        XCTAssertTrue(game.isLegal(touching), "5T allows a shared end dot")
    }

    /// The "Not allowed" diagram: overlapping a segment of the first line.
    func testOverlappingASegmentIsIllegal() {
        let game = gameWithFirstLine(
            .fiveT, present: run(0, from: -4, count: 4).union(run(0, from: 1, count: 2)))
        // -1…3 overlaps -4…0 on the segment -1→0.
        let overlapping = Move(dot: Point(3, 0), line: hLine(-1))
        XCTAssertFalse(
            game.isLegal(overlapping),
            "reusing a segment in the same direction must be illegal")
    }

    /// The 5D diagram: what 5T allows, 5D forbids.
    func testTouchingIsIllegalIn5D() {
        let game = gameWithFirstLine(
            .fiveD, present: run(0, from: -4, count: 4).union(run(0, from: 1, count: 3)))
        let touching = Move(dot: Point(4, 0), line: hLine(0))
        XCTAssertFalse(
            game.isLegal(touching), "5D forbids collinear lines sharing even a dot")
    }

    /// "Every line needs a new dot" — five existing dots aren't claimable.
    func testFiveExistingDotsAreNotALine() {
        let game = Game(rules: .fiveT, start: run(0, from: -2, count: 5))
        XCTAssertFalse(
            game.legalMoves().contains { $0.line == hLine(-2) },
            "a line must contain the move's NEW dot")
        // And the engine rejects it even when asked directly, for any dot.
        for p in game.dots {
            XCTAssertFalse(game.isLegal(Move(dot: p, line: hLine(-2))))
        }
    }

    /// The dead-gap diagram: two lines 1–4 apart along one axis foreclose the
    /// span between them.
    func testTheDeadGapDiagramForecloses() {
        // Two lines with a two-dot GAP between them: -6…-2 and 1…5. Nothing can
        // span -2…1, so the gap is dead.
        var game = Game(
            rules: .fiveT,
            start: run(0, from: -6, count: 4).union(run(0, from: 1, count: 4)))
        XCTAssertTrue(game.play(Move(dot: Point(-2, 0), line: hLine(-6))))
        XCTAssertTrue(game.play(Move(dot: Point(5, 0), line: hLine(1))))
        XCTAssertFalse(
            Foreclosure.losses(in: game).isEmpty,
            "the diagram claims a dead gap — the analysis must report one")
    }
}
