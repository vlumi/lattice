import LatticeCore
import XCTest

@testable import LatticeKit

/// Restart/New Game is briefly undoable: an accidental restart mid-game can be
/// recovered until the first move commits to the fresh board.
@MainActor
final class RestartUndoTests: XCTestCase {
    private func session() -> GameSession {
        GameSession(mode: .free, store: .ephemeral())
    }

    private func firstPlaceable(_ s: GameSession) -> Point {
        let xs = s.game.dots.map(\.x)
        let ys = s.game.dots.map(\.y)
        return (xs.min()! - 1...xs.max()! + 1).flatMap { x in
            (ys.min()! - 1...ys.max()! + 1).map { Point(x, $0) }
        }
        .first { s.isPlaceable($0) }!
    }

    func testUndoRestoresGameReplacedByRestart() {
        let s = session()
        // Play a move, then restart — the restart is undoable.
        s.place(firstPlaceable(s))
        s.commitHighlighted()
        let movesBefore = s.game.moves
        XCTAssertEqual(movesBefore.count, 1)

        s.newGame()  // restart the same board
        XCTAssertTrue(s.game.moves.isEmpty, "fresh board after restart")
        XCTAssertTrue(s.undoAllowed, "the restart itself should be undoable")

        s.undo()
        XCTAssertEqual(s.game.moves, movesBefore, "undo brings the replaced game back")
    }

    func testRestartOfUnplayedBoardIsNotUndoable() {
        let s = session()
        // Nothing played — restarting an untouched board leaves nothing to undo.
        s.newGame()
        XCTAssertFalse(s.undoAllowed)
    }

    func testFirstMoveClearsTheRestorePoint() {
        let s = session()
        s.place(firstPlaceable(s))
        s.commitHighlighted()
        s.newGame()  // restore point armed

        // Commit a move on the fresh board — this discards the old game.
        s.place(firstPlaceable(s))
        s.commitHighlighted()
        XCTAssertEqual(s.game.moves.count, 1)

        // Undo now just undoes that one move, back to the empty fresh board —
        // NOT back to the pre-restart game.
        s.undo()
        XCTAssertTrue(s.game.moves.isEmpty)
        XCTAssertFalse(s.undoAllowed, "the pre-restart game is no longer recoverable")
    }

    func testUndoRestoresSeededChallengeAfterVariantSwitch() {
        let s = session()
        s.newChallenge(seed: 12345)
        s.place(firstPlaceable(s))
        s.commitHighlighted()
        let seededMoves = s.game.moves

        s.newGame(rules: .fiveT)  // switch away to a standard start
        XCTAssertNil(s.seed)
        XCTAssertTrue(s.undoAllowed)

        s.undo()
        XCTAssertEqual(s.seed, 12345, "the seeded challenge comes back")
        XCTAssertEqual(s.game.moves, seededMoves)
    }
}
