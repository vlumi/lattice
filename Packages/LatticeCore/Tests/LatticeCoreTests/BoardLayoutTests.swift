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
        let insets = BoardView.cornerInset(bounds: bounds, in: tall)
        XCTAssertEqual(insets.trailing, 0)
        XCTAssertEqual(insets.bottom, 0)
    }

    /// A nearly-square board fills whichever axis binds; the inset must reserve
    /// the OTHER (slack) axis and must NOT shrink the board — the whole point of
    /// choosing the slack axis. Cell size stays equal to the plain fit.
    private func assertClearsWithoutShrinking(
        _ frame: CGSize, file: StaticString = #filePath, line: UInt = #line
    ) {
        let big = Bounds(of: [Point(0, 0), Point(24, 24)])
        let plain = Layout(fitting: big, in: frame)
        let insets = BoardView.cornerInset(bounds: big, in: frame)
        let layout = Layout(fitting: big, in: frame, insets: insets)
        XCTAssertEqual(
            layout.cell, plain.cell, accuracy: 0.001, "board shrank", file: file, line: line)
        // The bottom-right dot clears the reserved corner in at least one axis.
        let corner = layout.position(of: Point(big.maxX, big.minY))
        let clearsX = corner.x + layout.cell <= frame.width - 68
        let clearsY = corner.y + layout.cell <= frame.height - 68
        XCTAssertTrue(clearsX || clearsY, "still under the controls", file: file, line: line)
    }

    func testWidthBoundBoardReservesVerticallyWithoutShrinking() {
        // Mac-window shape: wider than tall → width-bound → reserve the bottom.
        assertClearsWithoutShrinking(CGSize(width: 600, height: 500))
    }

    func testHeightBoundBoardReservesHorizontallyWithoutShrinking() {
        // Portrait phone shape: taller than wide → height-bound → reserve trailing.
        assertClearsWithoutShrinking(CGSize(width: 400, height: 700))
    }
}
