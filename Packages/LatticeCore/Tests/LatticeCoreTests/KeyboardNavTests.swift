import LatticeCore
import XCTest

@testable import LatticeKit

/// Keyboard play over GameSession: cursor clamp, place, candidate cycle,
/// commit, undo. Uses an ephemeral store so nothing touches real saves.
@MainActor
final class KeyboardNavTests: XCTestCase {
    private func session() -> GameSession {
        GameSession(mode: .free, store: .ephemeral())
    }

    func testCursorClampsToBoundingBoxPlusOne() {
        let s = session()  // standard 5T cross around the origin region
        // Drive far up-left; the cursor must stop at the dots' bbox − 1, never
        // wander into open space.
        for _ in 0..<50 { s.moveCursor(dx: -1, dy: -1) }
        let cursor = s.keyboardCursor!
        let minX = s.game.dots.map(\.x).min()!
        let minY = s.game.dots.map(\.y).min()!
        XCTAssertEqual(cursor.x, minX - 1)
        XCTAssertEqual(cursor.y, minY - 1)
        // …and the far corner the other way.
        for _ in 0..<50 { s.moveCursor(dx: 1, dy: 1) }
        let far = s.keyboardCursor!
        XCTAssertEqual(far.x, s.game.dots.map(\.x).max()! + 1)
        XCTAssertEqual(far.y, s.game.dots.map(\.y).max()! + 1)
    }

    func testCursorSelectPlacesOnlyOnPlaceablePoints() {
        let s = session()
        // Park the cursor on a definitely-empty, non-placeable corner.
        for _ in 0..<50 { s.moveCursor(dx: -1, dy: -1) }
        s.cursorSelect()
        XCTAssertNil(s.tentative, "shouldn't place on a non-placeable point")
        // Move onto a placeable point (there is at least one on a fresh cross).
        let placeable = (s.game.dots.map(\.x).min()! - 1...s.game.dots.map(\.x).max()! + 1)
            .flatMap { x in
                (s.game.dots.map(\.y).min()! - 1...s.game.dots.map(\.y).max()! + 1)
                    .map { Point(x, $0) }
            }
            .first { s.isPlaceable($0) }!
        s.place(placeable)
        XCTAssertEqual(s.tentative, placeable)
    }

    func testCycleCandidateWrapsAndCommitPlaysHighlighted() {
        let s = session()
        // Find a placeable dot and enter stage two.
        let placeable = allPoints(s).first { s.isPlaceable($0) }!
        s.place(placeable)
        let count = s.candidates.count
        XCTAssertGreaterThan(count, 0)
        // Cycle a full loop → back to 0.
        for _ in 0..<count { s.cycleCandidate(by: 1) }
        XCTAssertEqual(s.candidateIndex, 0)
        // Backwards wraps to the last.
        s.cycleCandidate(by: -1)
        XCTAssertEqual(s.candidateIndex, count - 1)
        // Commit the highlighted candidate → a move is played, tentative clears.
        let expected = s.candidates[s.candidateIndex]
        s.commitHighlighted()
        XCTAssertNil(s.tentative)
        XCTAssertEqual(s.game.moves.last, expected)
    }

    func testCandidateCycleIsNoOpWithoutTentative() {
        let s = session()
        s.cycleCandidate(by: 1)
        XCTAssertEqual(s.candidateIndex, 0)
        s.commitHighlighted()
        XCTAssertTrue(s.game.moves.isEmpty)
    }

    func testUndoAfterKeyboardCommit() {
        let s = session()
        let placeable = allPoints(s).first { s.isPlaceable($0) }!
        s.place(placeable)
        s.commitHighlighted()
        XCTAssertEqual(s.game.moves.count, 1)
        s.undo()
        XCTAssertTrue(s.game.moves.isEmpty)
        XCTAssertNil(s.tentative)
        XCTAssertEqual(s.candidateIndex, 0)
    }

    private func allPoints(_ s: GameSession) -> [Point] {
        let xs = s.game.dots.map(\.x)
        let ys = s.game.dots.map(\.y)
        return (xs.min()! - 1...xs.max()! + 1).flatMap { x in
            (ys.min()! - 1...ys.max()! + 1).map { Point(x, $0) }
        }
    }
}
