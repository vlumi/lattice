import XCTest

@testable import LatticeCore

final class StartingPatternTests: XCTestCase {
    private let cross = StartingPattern.standardCross

    func testCrossHas36Dots() {
        XCTAssertEqual(cross.count, 36)
    }

    func testCrossSpansConventionBounds() {
        XCTAssertEqual(cross.map(\.x).min(), -5)
        XCTAssertEqual(cross.map(\.x).max(), 4)
        XCTAssertEqual(cross.map(\.y).min(), -5)
        XCTAssertEqual(cross.map(\.y).max(), 4)
    }

    func testCrossIsHollow() {
        // The middle square and the rest of the interior hold no dots.
        for x in -1...0 {
            for y in -1...0 {
                XCTAssertFalse(cross.contains(Point(x, y)))
            }
        }
        XCTAssertFalse(cross.contains(Point(0, 2)))
        XCTAssertFalse(cross.contains(Point(-3, 0)))
    }

    func testCrossCornersPresent() {
        // Outer corners of two arms and two reflex corners of the outline.
        XCTAssertTrue(cross.contains(Point(-2, 4)))
        XCTAssertTrue(cross.contains(Point(4, -2)))
        XCTAssertTrue(cross.contains(Point(1, 1)))
        XCTAssertTrue(cross.contains(Point(-2, -2)))
    }

    func testCrossInvariantUnderAllSymmetries() {
        for symmetry in Symmetry.allCases {
            XCTAssertEqual(symmetry.apply(cross), cross, "\(symmetry)")
        }
    }
}
