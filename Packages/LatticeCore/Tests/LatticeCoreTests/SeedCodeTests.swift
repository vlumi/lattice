import XCTest

@testable import LatticeCore

final class SeedCodeTests: XCTestCase {
    func testRoundTrip() {
        for seed: UInt64 in [0, 1, 31, 32, 12345, 1 << 30, UInt64.max] {
            XCTAssertEqual(SeedCode.decode(SeedCode.encode(seed)), seed, "\(seed)")
        }
    }

    func testDecodeForgiveness() {
        let code = SeedCode.encode(123_456)
        XCTAssertEqual(SeedCode.decode(code.lowercased()), 123_456)
        XCTAssertEqual(SeedCode.decode(" \(code) "), 123_456)
        // Crockford ambiguity: I/L read as 1, O as 0.
        XCTAssertEqual(SeedCode.decode("O"), 0)
        XCTAssertEqual(SeedCode.decode("I"), 1)
        XCTAssertEqual(SeedCode.decode("l"), 1)
    }

    func testDecodeRejectsGarbage() {
        XCTAssertNil(SeedCode.decode(""))
        XCTAssertNil(SeedCode.decode("!!!"))
        XCTAssertNil(SeedCode.decode("U0"), "U is not in the Crockford alphabet")
        XCTAssertNil(SeedCode.decode("ZZZZZZZZZZZZZZ"), "overflow")
    }

    func testRandomSeedRange() {
        for _ in 0..<20 {
            let seed = SeedCode.randomSeed()
            XCTAssertGreaterThan(seed, 0)
            XCTAssertLessThan(seed, 1 << 30)
            XCTAssertLessThanOrEqual(SeedCode.encode(seed).count, 6)
        }
    }

    func testVariantKeys() {
        XCTAssertEqual(Rules.fiveT.variantKey(forStart: StartingPattern.standardCross), "5T")
        XCTAssertEqual(Rules.fourT.variantKey(forStart: StartingPattern.smallCross), "4T")
        XCTAssertEqual(
            Rules.fiveT.variantKey(forStart: StartGenerator.pattern(seed: 7)), "5T#")
        XCTAssertEqual(
            Rules.fiveD.variantKey(forStart: StartGenerator.pattern(seed: 7)), "5D#")
    }

    func testSnapshotCarriesSeed() throws {
        let game = Game(rules: .fiveT, start: StartGenerator.pattern(seed: 99))
        let snapshot = GameSnapshot(game: game, id: UUID(), seed: 99)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)
        XCTAssertEqual(decoded.seed, 99)
        // Older saves without the field decode with a nil seed.
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "seed")
        let legacy = try JSONDecoder().decode(
            GameSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.seed)
    }
}
