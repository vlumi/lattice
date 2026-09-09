import CoreGraphics
import LatticeCore
import SwiftUI
import XCTest

@testable import LatticeKit

/// A tentative dot used to own the WHOLE board for scrubbing, so the board
/// couldn't be panned and a tap far away did nothing — the corner Cancel
/// button was the only way out. The scrub is now scoped to the candidates'
/// vicinity; everything outside stays pan/tap.
@MainActor
final class ScrubZoneTests: XCTestCase {
    private let size = CGSize(width: 600, height: 600)

    /// A session with a dot placed and candidate lines pending.
    private func tentativeSession() throws -> GameSession {
        let session = GameSession(mode: .free, store: .ephemeral())
        let move = try XCTUnwrap(session.game.legalMoves().first)
        session.place(move.dot)
        XCTAssertNotNil(session.tentative)
        XCTAssertFalse(session.candidates.isEmpty, "need ghosts to scrub between")
        return session
    }

    private func layout(for session: GameSession) -> LatticeKit.Layout {
        LatticeKit.Layout(fitting: Bounds(of: session.game.dots), in: size)
    }

    func testTentativeDotItselfIsInTheZone() throws {
        let session = try tentativeSession()
        let view = BoardView(session: session, camera: BoardCamera())
        let l = layout(for: session)
        let dot = try XCTUnwrap(session.tentative)
        XCTAssertTrue(view.inScrubZone(l.position(of: dot), l))
    }

    func testCandidateLinesAreInTheZone() throws {
        let session = try tentativeSession()
        let view = BoardView(session: session, camera: BoardCamera())
        let l = layout(for: session)
        for ghost in view.ghostGeometry(l) {
            let mid = CGPoint(x: (ghost.a.x + ghost.b.x) / 2, y: (ghost.a.y + ghost.b.y) / 2)
            XCTAssertTrue(view.inScrubZone(mid, l), "midpoint of a ghost must scrub")
        }
    }

    /// The point of the change: far from the pending choice, the gesture is
    /// the board's again.
    func testFarFromTheCandidatesIsNotInTheZone() throws {
        let session = try tentativeSession()
        let view = BoardView(session: session, camera: BoardCamera())
        let l = layout(for: session)
        let dot = try XCTUnwrap(session.tentative)
        let origin = l.position(of: dot)
        // Well beyond any ghost: the candidates span at most 5 dots from the
        // placed one, so 12 cells out is unambiguously "somewhere else".
        for offset in [
            CGSize(width: 12, height: 0), CGSize(width: 0, height: 12),
            CGSize(width: -12, height: -12),
        ] {
            let far = CGPoint(
                x: origin.x + offset.width * l.cell, y: origin.y + offset.height * l.cell)
            XCTAssertFalse(view.inScrubZone(far, l), "\(offset) should be outside the zone")
        }
    }
}
