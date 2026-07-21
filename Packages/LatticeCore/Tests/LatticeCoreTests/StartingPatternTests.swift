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

    func testSmallCross() {
        let small = StartingPattern.smallCross
        XCTAssertEqual(small.count, 24)
        XCTAssertEqual(small.map(\.x).min(), -3)
        XCTAssertEqual(small.map(\.x).max(), 3)
        XCTAssertEqual(small.map(\.y).min(), -3)
        XCTAssertEqual(small.map(\.y).max(), 3)
        XCTAssertFalse(small.contains(Point(0, 0)), "hollow")
        // Odd extent: symmetric about the origin (plain negation), not the
        // standard cross's between-dots center.
        XCTAssertEqual(Set(small.map { Point(-$0.x, -$0.y) }), small)
        XCTAssertEqual(Set(small.map { Point($0.y, $0.x) }), small)
    }

    func testStandardStartForRules() {
        XCTAssertEqual(StartingPattern.standard(for: .fiveT), StartingPattern.standardCross)
        XCTAssertEqual(StartingPattern.standard(for: .fiveD), StartingPattern.standardCross)
        XCTAssertEqual(StartingPattern.standard(for: .fourT), StartingPattern.smallCross)
        XCTAssertEqual(StartingPattern.standard(for: .fourD), StartingPattern.smallCross)
    }

    func testFourGameInitialMoveCount() {
        // 40, engine-derived and verified by hand: the small cross's arm
        // gap is a single cell, so the centre-gap dots (0,±1)/(±1,0) accept
        // all four windows through them — 6 per row/column (24) — plus 2
        // per arm-end edge (8) and 2 corner-threading diagonals per corner
        // (8), e.g. (-1,-4),(0,-3),(1,-2),(2,-1).
        let fourT = Game(rules: .fourT, start: StartingPattern.smallCross)
        XCTAssertEqual(fourT.legalMoves().count, 40)
        let fourD = Game(rules: .fourD, start: StartingPattern.smallCross)
        XCTAssertEqual(fourD.legalMoves().count, 40)
    }
}
