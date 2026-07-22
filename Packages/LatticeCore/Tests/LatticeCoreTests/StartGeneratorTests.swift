import XCTest

@testable import LatticeCore

final class StartGeneratorTests: XCTestCase {
    func testDeterministic() {
        XCTAssertEqual(StartGenerator.pattern(seed: 42), StartGenerator.pattern(seed: 42))
        XCTAssertEqual(StartGenerator.pattern(seed: 0), StartGenerator.pattern(seed: 0))
    }

    func testPatternShape() {
        for seed: UInt64 in [1, 7, 99, 12345] {
            let pattern = StartGenerator.pattern(seed: seed)
            XCTAssertEqual(pattern.count, 36, "seed \(seed)")
            for symmetry in Symmetry.allCases {
                XCTAssertEqual(symmetry.apply(pattern), pattern, "seed \(seed) \(symmetry)")
            }
        }
    }

    func testPatternsArePlayable() {
        for seed: UInt64 in [1, 7, 99, 12345] {
            let game = Game(rules: .fiveT, start: StartGenerator.pattern(seed: seed))
            XCTAssertGreaterThanOrEqual(game.legalMoves().count, 12, "seed \(seed)")
        }
    }

    func testSeedsDiffer() {
        XCTAssertNotEqual(StartGenerator.pattern(seed: 1), StartGenerator.pattern(seed: 2))
        XCTAssertNotEqual(StartGenerator.pattern(seed: 2), StartGenerator.pattern(seed: 3))
    }

    func testStableHashVectors() {
        // FNV-1a fixed points — these values must never change (persisted
        // seeds derive from them).
        XCTAssertEqual(StableHash.fnv1a(""), 0xCBF2_9CE4_8422_2325)
        XCTAssertEqual(StableHash.fnv1a("a"), 0xAF63_DC4C_8601_EC8C)
    }
}
