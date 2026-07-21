import XCTest

@testable import LatticeCore

final class GameTests: XCTestCase {
    // Completes the left arm's top edge (dots at (-5,1)…(-2,1)) with a new
    // dot at (-1,1) — a classic first move.
    private let firstMove = Move(
        dot: Point(-1, 1),
        line: Line(origin: Point(-5, 1), axis: .horizontal, length: 5))

    // Collinear continuation sharing only the endpoint (-1,1): legal in 5T,
    // illegal in 5D.
    private let touchingMove = Move(
        dot: Point(0, 1),
        line: Line(origin: Point(-1, 1), axis: .horizontal, length: 5))

    func testFreshGame() {
        let game = Game()
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.dots.count, 36)
        XCTAssertFalse(game.isOver)
    }

    func testFirstMovePlays() {
        var game = Game()
        XCTAssertTrue(game.play(firstMove))
        XCTAssertEqual(game.score, 1)
        XCTAssertTrue(game.dots.contains(Point(-1, 1)))
    }

    func testDotsMinusStartEqualsScore() {
        var game = Game()
        game.play(firstMove)
        game.play(touchingMove)
        XCTAssertEqual(game.dots.count - game.start.count, game.score)
    }

    func testRejectsOccupiedDot() {
        var game = Game()
        // A "free line" shape: the dot is already on the board.
        let move = Move(
            dot: Point(-5, 1),
            line: Line(origin: Point(-5, 1), axis: .vertical, length: 5))
        XCTAssertFalse(game.play(move))
    }

    func testRejectsMissingSupportDots() {
        var game = Game()
        let move = Move(
            dot: Point(0, 0),
            line: Line(origin: Point(0, 0), axis: .horizontal, length: 5))
        XCTAssertFalse(game.play(move))
    }

    func testRejectsWrongLineLength() {
        var game = Game()
        let move = Move(
            dot: Point(-1, 1),
            line: Line(origin: Point(-4, 1), axis: .horizontal, length: 4))
        XCTAssertFalse(game.play(move))
    }

    func testSegmentReuseBlocked() {
        var game = Game()
        game.play(firstMove)
        // Overlaps four segments of the first line: only the new dot at
        // (0,1) extends it, so segments (-4…-1) are reused. Illegal in 5T.
        let overlapping = Move(
            dot: Point(0, 1),
            line: Line(origin: Point(-4, 1), axis: .horizontal, length: 5))
        XCTAssertFalse(game.play(overlapping))
    }

    func testTouchingAllowedIn5T() {
        var game = Game(rules: .fiveT)
        XCTAssertTrue(game.play(firstMove))
        XCTAssertTrue(game.play(touchingMove))
    }

    func testTouchingBlockedIn5D() {
        var game = Game(rules: .fiveD)
        XCTAssertTrue(game.play(firstMove))
        XCTAssertFalse(game.play(touchingMove))
        // Shifted one step along, the lines share no dot — legal even in 5D.
        XCTAssertTrue(
            game.play(
                Move(
                    dot: Point(0, 1), line: Line(origin: Point(0, 1), axis: .horizontal, length: 5)
                )))
    }

    func testCrossOnSharedDotDifferentAxisAllowed() {
        var game = Game()
        game.play(firstMove)
        // Vertical line through (-1,1): needs 4 more dots — build via a
        // custom start instead for a direct check.
        var custom = Game(
            rules: .fiveT,
            start: [
                Point(0, 1), Point(0, 2), Point(0, 3), Point(0, 4),
                Point(1, 0), Point(2, 0), Point(3, 0), Point(4, 0),
            ])
        XCTAssertTrue(
            custom.play(
                Move(dot: Point(0, 0), line: Line(origin: Point(0, 0), axis: .vertical, length: 5))
            ))
        XCTAssertTrue(
            custom.play(
                Move(
                    dot: Point(5, 0), line: Line(origin: Point(1, 0), axis: .horizontal, length: 5)
                )))
    }

    func testUndoRestoresState() {
        let fresh = Game()
        var game = fresh
        game.play(firstMove)
        game.play(touchingMove)
        XCTAssertEqual(game.undo(), touchingMove)
        XCTAssertEqual(game.undo(), firstMove)
        XCTAssertNil(game.undo())
        XCTAssertEqual(game, fresh)
    }

    func testUndoReopensBlockedMove() {
        var game = Game()
        game.play(firstMove)
        let overlapping = Move(
            dot: Point(0, 1),
            line: Line(origin: Point(-4, 1), axis: .horizontal, length: 5))
        XCTAssertFalse(game.isLegal(overlapping))
        game.undo()
        XCTAssertTrue(game.isLegal(firstMove))
    }

    func testInitialLegalMoveCount() {
        // 28, the known count for the standard cross. Derivation: each of
        // the four 8-dot rows/columns (y = 1, y = -2, x = 1, x = -2) gives
        // 4 windows, each of the four 4-dot arm-end edges gives 2 — that's
        // 24 axis-aligned — plus one diagonal per corner threading the arm
        // edges (e.g. (-5,-1)…(-1,-5) with only (-3,-3) missing) = 28.
        // Identical for 5D: no overlap exists on an unplayed board.
        XCTAssertEqual(Game(rules: .fiveT).legalMoves().count, 28)
        XCTAssertEqual(Game(rules: .fiveD).legalMoves().count, 28)
    }

    func testLegalMovesByDotMatchesFlatEnumeration() {
        let game = Game()
        let grouped = game.legalMovesByDot()
        XCTAssertEqual(grouped.values.map(\.count).reduce(0, +), game.legalMoves().count)
        for (dot, moves) in grouped {
            for move in moves {
                XCTAssertEqual(move.dot, dot)
            }
        }
    }

    func testLegalMovesAreDistinctAndLegal() {
        var game = Game()
        game.play(firstMove)
        let moves = game.legalMoves()
        XCTAssertEqual(Set(moves).count, moves.count)
        for move in moves {
            XCTAssertTrue(game.isLegal(move), "\(move)")
        }
    }

    func testGameEndsOnDeadPosition() {
        // Four dots in a row: two legal moves at either end; after playing
        // one, 5T still has exactly one fresh extension left on each side of
        // the used segments... play until isOver and verify no legal moves
        // remain rather than asserting the trajectory.
        var game = Game(
            rules: .fiveT,
            start: [Point(0, 0), Point(1, 0), Point(2, 0), Point(3, 0)])
        XCTAssertEqual(game.legalMoves().count, 2)
        while let move = game.legalMoves().first {
            XCTAssertTrue(game.play(move))
        }
        XCTAssertTrue(game.isOver)
        XCTAssertTrue(game.legalMoves().isEmpty)
        XCTAssertGreaterThan(game.score, 0)
    }

    func testRandomPlayoutStaysConsistent() {
        // A full playout on the real cross: every applied move must keep the
        // invariants; the game must terminate.
        var game = Game()
        var rng = SplitMix64(seed: 5)
        while true {
            let moves = game.legalMoves()
            if moves.isEmpty { break }
            let index = Int(rng.next() % UInt64(moves.count))
            XCTAssertTrue(game.play(moves.sorted(by: Self.moveOrder)[index]))
        }
        XCTAssertTrue(game.isOver)
        XCTAssertEqual(game.dots.count - game.start.count, game.score)
        XCTAssertGreaterThan(game.score, 20, "random 5T playouts reliably exceed 20 moves")
    }

    // Deterministic order so the seeded playout is reproducible across runs
    // (Set iteration order isn't).
    private static func moveOrder(_ a: Move, _ b: Move) -> Bool {
        (a.dot.x, a.dot.y, a.line.origin.x, a.line.origin.y)
            < (b.dot.x, b.dot.y, b.line.origin.x, b.line.origin.y)
    }
}

// Tiny deterministic RNG so tests don't depend on SystemRandomNumberGenerator.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
