import CoreGraphics
import LatticeCore
import SwiftUI
import XCTest

@testable import LatticeKit

/// The fit-to-content geometry. Coverage-wise this is view-layer, but the
/// position↔point round-trip is pure and worth locking — especially that an
/// inset (reserving the floating-controls corner) doesn't break hit-testing.
final class BoardLayoutTests: XCTestCase {
    private let size = CGSize(width: 400, height: 400)
    private let bounds = Bounds(of: [Point(0, 0), Point(9, 9)])

    func testPositionPointRoundTripsWithoutInset() {
        let layout = Layout(fitting: bounds, in: size)
        for p in [Point(0, 0), Point(9, 9), Point(5, 3)] {
            XCTAssertEqual(layout.point(near: layout.position(of: p)), p)
        }
    }

    func testPositionPointRoundTripsWithTrailingInset() {
        // The inset reserves the trailing strip; hit-testing must still invert
        // to the same lattice points (originOffset accounts for the inset).
        let layout = Layout(
            fitting: bounds, in: size,
            insets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 64))
        for p in [Point(0, 0), Point(9, 9), Point(5, 3)] {
            XCTAssertEqual(layout.point(near: layout.position(of: p)), p)
        }
    }

    func testCornerInsetIsZeroWhenBoardClearsTheCorner() {
        // A small board in a tall frame: the corner is dead space, no inset.
        let tall = CGSize(width: 400, height: 900)
        let insets = Layout.controlsClearInset(bounds: bounds, in: tall)
        XCTAssertEqual(insets.trailing, 0)
        XCTAssertEqual(insets.bottom, 0)
    }

    // A near-square board that fills the frame. The bottom-right dot must ALWAYS
    // end up clear of the 68pt control corner (in x or y) — this is the
    // guarantee: no dot is ever under the buttons at fit. `shrinkAllowed` says
    // whether the board may also shrink to achieve it.
    private func assertClearsCorner(
        _ frame: CGSize, shrinkAllowed: Bool, file: StaticString = #filePath, line: UInt = #line
    ) {
        let big = Bounds(of: [Point(0, 0), Point(24, 24)])
        let plain = Layout(fitting: big, in: frame)
        let insets = Layout.controlsClearInset(bounds: big, in: frame)
        let layout = Layout(fitting: big, in: frame, insets: insets)
        if !shrinkAllowed {
            XCTAssertEqual(
                layout.cell, plain.cell, accuracy: 0.001, "board shrank", file: file, line: line)
        }
        let corner = layout.position(of: Point(big.maxX, big.minY))
        let clearsX = corner.x + layout.cell <= frame.width - 68
        let clearsY = corner.y + layout.cell <= frame.height - 68
        XCTAssertTrue(clearsX || clearsY, "dot still under the controls", file: file, line: line)
    }

    func testWideWindowReservesVerticallyWithoutShrinking() {
        // Wider than tall → vertical slack → reserve the bottom, no shrink.
        assertClearsCorner(CGSize(width: 600, height: 500), shrinkAllowed: false)
    }

    func testTallWindowReservesHorizontallyWithoutShrinking() {
        // Taller than wide → horizontal slack → reserve trailing, no shrink.
        assertClearsCorner(CGSize(width: 400, height: 700), shrinkAllowed: false)
    }

    func testNearSquareWindowStillClearsCornerEvenIfItMustShrink() {
        // The bug: a near-square Mac window has little slack on either axis, so
        // clearing the corner requires shrinking — but it MUST still clear.
        assertClearsCorner(CGSize(width: 380, height: 380), shrinkAllowed: true)
    }
}
