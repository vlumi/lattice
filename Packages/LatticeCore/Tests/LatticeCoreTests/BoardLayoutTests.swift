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

    func testTrailingInsetKeepsContentClearOfReservedStrip() {
        // With a trailing inset, the rightmost column must render left of the
        // reserved strip — nothing draws under the floating buttons.
        let inset: CGFloat = 64
        let layout = Layout(
            fitting: bounds, in: size,
            insets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: inset))
        let rightmost = layout.position(of: Point(9, 9)).x
        XCTAssertLessThanOrEqual(rightmost, size.width - inset)
    }
}
