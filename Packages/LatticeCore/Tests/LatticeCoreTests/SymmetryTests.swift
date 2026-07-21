import XCTest

@testable import LatticeCore

final class SymmetryTests: XCTestCase {
    private let samples = [
        Point(0, 0), Point(-1, 0), Point(3, -5), Point(-5, 4), Point(7, 11),
    ]

    func testRotationsCompose() {
        for p in samples {
            let once = Symmetry.rotate90.apply(p)
            XCTAssertEqual(Symmetry.rotate180.apply(p), Symmetry.rotate90.apply(once))
            XCTAssertEqual(
                Symmetry.rotate270.apply(p),
                Symmetry.rotate90.apply(Symmetry.rotate90.apply(once)))
            XCTAssertEqual(Symmetry.rotate90.apply(Symmetry.rotate270.apply(p)), p)
        }
    }

    func testMirrorsAreInvolutions() {
        let mirrors: [Symmetry] = [.mirrorX, .mirrorY, .mirrorDiagonal, .mirrorAntidiagonal]
        for mirror in mirrors {
            for p in samples {
                XCTAssertEqual(mirror.apply(mirror.apply(p)), p, "\(mirror)")
            }
        }
    }

    func testSymmetriesAreDistinct() {
        // No two symmetries agree on all of an asymmetric probe set.
        let probe = [Point(2, 5), Point(-3, 1)]
        var images = Set<[Point]>()
        for symmetry in Symmetry.allCases {
            images.insert(probe.map(symmetry.apply))
        }
        XCTAssertEqual(images.count, Symmetry.allCases.count)
    }
}
