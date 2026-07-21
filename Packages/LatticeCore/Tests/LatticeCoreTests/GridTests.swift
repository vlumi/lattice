import XCTest

@testable import LatticeCore

final class GridTests: XCTestCase {
    func testOffsetWalksEveryAxis() {
        let origin = Point(2, -3)
        XCTAssertEqual(origin.offset(along: .horizontal, by: 4), Point(6, -3))
        XCTAssertEqual(origin.offset(along: .vertical, by: -2), Point(2, -5))
        XCTAssertEqual(origin.offset(along: .diagonalRising, by: 3), Point(5, 0))
        XCTAssertEqual(origin.offset(along: .diagonalFalling, by: 1), Point(3, -4))
    }

    func testSegmentKeyIsDirectionless() {
        let a = Point(0, 0)
        for axis in Axis.allCases {
            let b = a.offset(along: axis, by: 1)
            let forward = Segment.between(a, b)
            let backward = Segment.between(b, a)
            XCTAssertNotNil(forward)
            XCTAssertEqual(forward, backward, "\(axis)")
            XCTAssertEqual(forward?.origin, a, "\(axis)")
            XCTAssertEqual(forward?.endpoint, b, "\(axis)")
        }
    }

    func testSegmentRejectsNonAdjacentPoints() {
        XCTAssertNil(Segment.between(Point(0, 0), Point(0, 0)))
        XCTAssertNil(Segment.between(Point(0, 0), Point(2, 0)))
        XCTAssertNil(Segment.between(Point(0, 0), Point(1, 2)))
    }

    func testDistinctSegmentsOnSharedOrigin() {
        let origin = Point(0, 0)
        let keys = Set(Axis.allCases.map { Segment(origin: origin, axis: $0) })
        XCTAssertEqual(keys.count, Axis.allCases.count)
    }
}
