import Foundation
import XCTest

@testable import LatticeCore

final class DuelTierTests: XCTestCase {
    private func bests(_ pairs: [String: Int]) -> BestScores {
        var b = BestScores()
        for (k, v) in pairs { b.register(v, forKey: k) }
        return b
    }

    func testEligibleVariantsIsIntersection() {
        let mine = bests(["5T": 40, "5D": 20, "4T": 10])
        let theirs = bests(["5T": 55, "4T": 30, "5T+": 8])
        XCTAssertEqual(DuelTier.eligibleVariants(mine: mine, theirs: theirs), ["5T", "4T"])
    }

    func testOfferableTiersCapAtLowerBest() {
        let mine = bests(["5T": 45])
        let theirs = bests(["5T": 95])
        // min(45, 95) = 45 → rungs ≤ 45.
        XCTAssertEqual(
            DuelTier.offerableTiers(variantKey: "5T", mine: mine, theirs: theirs),
            [10, 20, 30])
    }

    func testOfferableTiersEmptyWhenTooWeak() {
        let mine = bests(["5T": 7])
        let theirs = bests(["5T": 200])
        XCTAssertTrue(
            DuelTier.offerableTiers(variantKey: "5T", mine: mine, theirs: theirs).isEmpty)
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
