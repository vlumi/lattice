import LatticeCore
import XCTest

@testable import LatticeKit

/// The keyboard cursor's state drives the roaming sound/haptic cues, so the
/// classification has to match what the board draws.
@MainActor
final class CursorStateTests: XCTestCase {
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

    func testNoCursorReadsAsEmpty() {
        XCTAssertEqual(session().cursorState, .empty)
    }

    /// Walk the cursor onto `target` (it clamps, so step by sign).
    private func steer(_ s: GameSession, to target: Point) {
        s.moveCursor(dx: 0, dy: 0)  // seed the cursor at the board centre
        for _ in 0..<200 where s.keyboardCursor != target {
            let current = s.keyboardCursor!
            s.moveCursor(
                dx: (target.x - current.x).signum(), dy: (target.y - current.y).signum())
        }
    }

    func testPlaceablePoint() {
        let s = session()
        let target = firstPlaceable(s)
        steer(s, to: target)
        XCTAssertEqual(s.keyboardCursor, target)
        XCTAssertEqual(s.cursorState, .placeable)
    }

    func testExistingDot() {
        let s = session()
        // A starting-cross dot that isn't itself playable.
        let dot = s.game.dots.first { !s.isPlaceable($0) }!
        steer(s, to: dot)
        XCTAssertEqual(s.keyboardCursor, dot)
        XCTAssertEqual(s.cursorState, .dot)
    }

    /// The states are exclusive: an occupied point is never `placeable`,
    /// because `isPlaceable` requires an empty point in both branches.
    func testDotsAreNeverPlaceable() {
        let s = session()
        s.newGame(rules: .fiveTPlus)  // free lines make the loosest case
        XCTAssertFalse(
            s.game.dots.contains { s.isPlaceable($0) },
            "an occupied point must never report placeable")
    }
}
