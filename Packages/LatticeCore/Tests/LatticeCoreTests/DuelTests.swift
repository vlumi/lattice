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

final class DuelProtocolTests: XCTestCase {
    // A generated 5T# board — but tier tests only need `game.score`, which the
    // protocol drives via real moves. Use a tiny tier and a helper that plays
    // whatever the first legal move is, to reach it deterministically.
    private func proto(tier: Int) -> DuelProtocol {
        DuelProtocol(seed: 7, variantKey: "5T", tier: tier)
    }

    private func firstLegalMove(_ p: DuelProtocol) -> Move {
        p.game.legalMoves().min { lhs, rhs in
            (lhs.dot.x, lhs.dot.y) < (rhs.dot.x, rhs.dot.y)
        }!
    }

    func testLockStepClockStartsOnOpponentFirstMove() {
        var p = proto(tier: 999)
        // Opponent moves first this turn → our clock starts.
        let actions = p.remoteMoved(clock: 0)
        XCTAssertTrue(p.localClockRunning)
        XCTAssertTrue(actions.contains(.startLocalClock(seconds: DuelProtocol.turnClock)))
    }

    func testCommittingStopsOurClockAndResolvesTurn() {
        var p = proto(tier: 999)
        _ = p.remoteMoved(clock: 0)  // our clock running
        let move = firstLegalMove(p)
        let actions = p.localMove(move, clock: 1)
        XCTAssertFalse(p.localClockRunning)
        XCTAssertTrue(actions.contains(.stopLocalClock))
        XCTAssertTrue(
            actions.contains { if case .sendMove = $0 { return true } else { return false } })
        // Both moved → turn resolved, ready for next parallel round.
        XCTAssertFalse(p.localMovedThisTurn)
    }

    func testWeMoveFirstNoClockRunsForUs() {
        var p = proto(tier: 999)
        let actions = p.localMove(firstLegalMove(p), clock: 0)
        XCTAssertFalse(p.localClockRunning)
        XCTAssertTrue(p.localMovedThisTurn)
        XCTAssertFalse(actions.contains(.startLocalClock(seconds: DuelProtocol.turnClock)))
    }

    func testReachingTierWins() {
        var p = proto(tier: 1)  // one line wins
        let actions = p.localMove(firstLegalMove(p), clock: 0)
        XCTAssertEqual(p.outcome, .won)
        XCTAssertTrue(actions.contains(.sendReachedTier))
        XCTAssertTrue(actions.contains(.finish(.won)))
    }

    func testClockExpiryLosesWholeGame() {
        var p = proto(tier: 999)
        _ = p.remoteMoved(clock: 0)  // clock running
        let actions = p.localClockExpired()
        XCTAssertEqual(p.outcome, .lost)
        XCTAssertTrue(actions.contains(.sendResign))
        XCTAssertTrue(actions.contains(.finish(.lost)))
    }

    func testClockExpiryIgnoredWhenNotRunning() {
        var p = proto(tier: 999)
        XCTAssertTrue(p.localClockExpired().isEmpty)
        XCTAssertNil(p.outcome)
    }

    func testRemoteReachedTierLoses() {
        var p = proto(tier: 999)
        XCTAssertEqual(p.remoteReachedTier(), [.finish(.lost)])
        XCTAssertEqual(p.outcome, .lost)
    }

    func testRemoteResignWins() {
        var p = proto(tier: 999)
        XCTAssertEqual(p.remoteResigned(), [.finish(.won)])
        XCTAssertEqual(p.outcome, .won)
    }

    func testDisconnectForfeitsToUs() {
        var p = proto(tier: 999)
        XCTAssertEqual(p.disconnected(), [.finish(.won)])
    }

    func testEventsAfterGameOverAreNoOps() {
        var p = proto(tier: 1)
        _ = p.localMove(firstLegalMove(p), clock: 0)  // won
        XCTAssertTrue(p.remoteResigned().isEmpty)
        XCTAssertTrue(p.remoteReachedTier().isEmpty)
        XCTAssertTrue(p.localClockExpired().isEmpty)
    }
}
