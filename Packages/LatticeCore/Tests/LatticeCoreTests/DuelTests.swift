import Foundation
import XCTest

@testable import LatticeCore

final class DuelTierTests: XCTestCase {
    private func bests(_ pairs: [String: Int]) -> BestScores {
        var b = BestScores()
        for (k, v) in pairs { b.register(v, forKey: k) }
        return b
    }

    func testEligibleVariantsIsStandardSetInCanonicalOrder() {
        // Every standard selectable variant is duel-eligible (the floor tier is
        // universal), regardless of recorded bests — canonical display order.
        XCTAssertEqual(DuelTier.eligibleVariants, ["5T", "5T+", "5D", "4T", "4D"])
    }

    func testOfferableTiersCapAtLowerBest() {
        let mine = bests(["5T": 45])
        let theirs = bests(["5T": 95])
        // min(45, 95) = 45 → floor plus rungs ≤ 45.
        XCTAssertEqual(
            DuelTier.offerableTiers(variantKey: "5T", mine: mine, theirs: theirs),
            [10, 20, 30])
    }

    func testOfferableTiersAlwaysIncludesFloor() {
        // A brand-new player (no best at all): only the entry rung — but it's
        // always there, so anyone can duel at 10.
        let fresh = BestScores()
        XCTAssertEqual(
            DuelTier.offerableTiers(variantKey: "5T", mine: fresh, theirs: fresh),
            [10])
        // A weak+strong pairing still offers only the floor when the weaker
        // hasn't proven the next rung.
        let weak = bests(["5T": 7])
        let strong = bests(["5T": 200])
        XCTAssertEqual(
            DuelTier.offerableTiers(variantKey: "5T", mine: weak, theirs: strong),
            [10])
    }

    func testHostOfferableTiersGateOnHostBestAlone() {
        // Host-advertises: the host offers the floor plus rungs it has reached,
        // gated on its own best (guests join after).
        XCTAssertEqual(
            DuelTier.offerableTiers(variantKey: "5T", best: bests(["5T": 45])),
            [10, 20, 30])
        // A fresh host still offers the floor.
        XCTAssertEqual(
            DuelTier.offerableTiers(variantKey: "5T", best: BestScores()),
            [10])
    }
}
