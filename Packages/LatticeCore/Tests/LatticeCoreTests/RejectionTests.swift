import LatticeCore
import XCTest

@testable import LatticeKit

/// A tap that can't become a move gets feedback — but only where feedback tells
/// the player something. Tapping an existing dot is self-evident; tapping empty
/// space no line can reach is the teachable case.
@MainActor
final class RejectionTests: XCTestCase {
    private func session() -> GameSession {
        GameSession(mode: .free, store: .ephemeral())
    }

    /// The starting cross has dots that aren't themselves playable — tapping one
    /// is not a "why did nothing happen?" moment.
    func testExistingDotsAreNotPlaceableButAreSelfEvident() {
        let s = session()
        let dot = s.game.dots.first { !s.isPlaceable($0) }
        XCTAssertNotNil(dot, "the cross should have a non-playable dot")
        XCTAssertTrue(s.game.dots.contains(dot!))
    }

    /// Far from the board nothing can be played, and nothing is there — the case
    /// worth marking.
    func testEmptyUnreachablePointIsRejectable() {
        let s = session()
        let far = Point(50, 50)
        XCTAssertFalse(s.isPlaceable(far))
        XCTAssertFalse(s.game.dots.contains(far), "empty AND unplayable — mark it")
    }

    /// And the marker must not fire where a move IS legal.
    func testPlaceablePointsAreNotRejected() {
        let s = session()
        let xs = s.game.dots.map(\.x)
        let ys = s.game.dots.map(\.y)
        let playable = (xs.min()! - 1...xs.max()! + 1).flatMap { x in
            (ys.min()! - 1...ys.max()! + 1).map { Point(x, $0) }
        }
        .first { s.isPlaceable($0) }
        XCTAssertNotNil(playable)
        XCTAssertTrue(s.isPlaceable(playable!))
    }
}
