import Foundation
import XCTest

@testable import LatticeCore

/// Headless coverage for the N-player, two-mode `DuelMatch`. This is the crux
/// of the redesign's correctness — the transport/UI can only be smoke-tested on
/// devices, so every mechanic (lock-step arming/elimination, race placement)
/// is proven here, for 2 and 3 players.
final class DuelMatchTests: XCTestCase {
    private let seed: UInt64 = 7
    private let variant = "5T"

    private func match(_ mode: DuelMode, players: [String]) -> DuelMatch {
        DuelMatch(
            mode: mode, seed: seed, variantKey: variant, local: players[0],
            roster: players.map { ($0, $0) })
    }

    /// The lowest-coordinate legal move — deterministic, for driving the local
    /// board forward one step.
    private func firstLegalMove(_ game: Game) -> Move {
        game.legalMoves().min {
            ($0.dot.x, $0.dot.y) < ($1.dot.x, $1.dot.y)
        }!
    }

    // MARK: Lock-step — 2 players

    func testLockStepFirstCommitArmsTheOther() {
        var m = match(.lockStep, players: ["A", "B"])
        // A (local) commits first → B's clock starts, A's does not.
        let actions = m.localMove(firstLegalMove(m.game))
        XCTAssertTrue(actions.contains(.startClock("B", seconds: DuelMode.turnClock)))
        XCTAssertFalse(m.players["A"]?.clockRunning ?? true)
        XCTAssertTrue(m.players["B"]?.clockRunning ?? false)
    }

    func testLockStepSecondCommitStopsOwnClockAndAdvancesRound() {
        var m = match(.lockStep, players: ["A", "B"])
        _ = m.localMove(firstLegalMove(m.game))  // A first → B armed
        let actions = m.remoteMoved("B")  // B answers
        XCTAssertTrue(actions.contains(.stopClock("B")))
        // Round complete: both movedThisRound reset for the next round.
        XCTAssertFalse(m.players["A"]?.movedThisRound ?? true)
        XCTAssertFalse(m.players["B"]?.movedThisRound ?? true)
        XCTAssertFalse(m.isOver)
    }

    func testLockStepBarrierBlocksSecondMoveBeforeRoundResolves() {
        var m = match(.lockStep, players: ["A", "B"])
        _ = m.localMove(firstLegalMove(m.game))  // A commits round 1
        XCTAssertTrue(m.localWaitingForRound)
        let scoreAfterFirst = m.game.score
        // A tries to race ahead before B has answered — rejected, no-op.
        let blocked = m.localMove(firstLegalMove(m.game))
        XCTAssertTrue(blocked.isEmpty)
        XCTAssertEqual(m.game.score, scoreAfterFirst)  // board didn't advance
        // Once B answers, the round resolves and A can move again.
        _ = m.remoteMoved("B")
        XCTAssertFalse(m.localWaitingForRound)
        XCTAssertFalse(m.localMove(firstLegalMove(m.game)).isEmpty)
    }

    func testLockStepClockExpiryEliminatesAndOpponentWins() {
        var m = match(.lockStep, players: ["A", "B"])
        _ = m.localMove(firstLegalMove(m.game))  // A first → B on the clock
        let actions = m.clockExpired("B")  // B fails to keep pace
        XCTAssertTrue(m.isOver)
        XCTAssertEqual(m.players["A"]?.status, .placed(1))
        XCTAssertEqual(m.players["B"]?.status, .eliminated)
        XCTAssertEqual(actions.last, .finish(standings: ["A", "B"]))
    }

    func testLockStepExpiryIgnoredWhenClockNotRunning() {
        var m = match(.lockStep, players: ["A", "B"])
        // Nobody moved yet → no clock running → expiry is a no-op.
        XCTAssertTrue(m.clockExpired("B").isEmpty)
        XCTAssertFalse(m.isOver)
    }

    func testLockStepLocalDeadEndEliminatesLocal() {
        var m = match(.lockStep, players: ["A", "B"])
        let actions = m.noLegalMoves("A")  // local can't keep pace
        XCTAssertTrue(actions.contains(.sendEliminated))
        XCTAssertTrue(m.isOver)
        XCTAssertEqual(m.players["B"]?.status, .placed(1))
    }

    // MARK: Lock-step — 3 players (battle royale)

    func testLockStepThreePlayersFirstCommitArmsBothOthers() {
        var m = match(.lockStep, players: ["A", "B", "C"])
        let actions = m.localMove(firstLegalMove(m.game))  // A first
        XCTAssertTrue(actions.contains(.startClock("B", seconds: DuelMode.turnClock)))
        XCTAssertTrue(actions.contains(.startClock("C", seconds: DuelMode.turnClock)))
        XCTAssertFalse(m.players["A"]?.clockRunning ?? true)
    }

    func testLockStepThreePlayersSecondCommitDoesNotRestartClocks() {
        var m = match(.lockStep, players: ["A", "B", "C"])
        _ = m.localMove(firstLegalMove(m.game))  // A first → B, C armed
        let actions = m.remoteMoved("B")  // B answers before its clock expires
        // Only B's own clock stops; C's keeps running, no new startClock.
        XCTAssertEqual(actions, [.stopClock("B")])
        XCTAssertTrue(m.players["C"]?.clockRunning ?? false)
        XCTAssertFalse(m.isOver)  // C still active, round not complete
    }

    func testLockStepThreePlayersOneEliminatedOthersContinue() {
        var m = match(.lockStep, players: ["A", "B", "C"])
        _ = m.localMove(firstLegalMove(m.game))  // A first → B, C armed
        _ = m.remoteMoved("B")  // B safe
        let actions = m.clockExpired("C")  // C times out
        XCTAssertEqual(m.players["C"]?.status, .eliminated)
        XCTAssertFalse(m.isOver)  // A and B still racing
        XCTAssertFalse(
            actions.contains(where: {
                if case .finish = $0 { return true }; return false
            }))
        // With C gone and A+B both having moved, the round resolves and resets.
        XCTAssertFalse(m.players["A"]?.movedThisRound ?? true)
        XCTAssertFalse(m.players["B"]?.movedThisRound ?? true)
    }

    func testLockStepThreePlayersLastStandingWins() {
        var m = match(.lockStep, players: ["A", "B", "C"])
        _ = m.localMove(firstLegalMove(m.game))  // A first
        _ = m.clockExpired("B")  // B out
        let actions = m.clockExpired("C")  // C out → A wins
        XCTAssertTrue(m.isOver)
        XCTAssertEqual(m.players["A"]?.status, .placed(1))
        if case .finish(let standings)? = actions.last {
            XCTAssertEqual(standings.first, "A")
            XCTAssertEqual(Set(standings), Set(["A", "B", "C"]))
        } else {
            XCTFail("expected finish")
        }
    }

    // MARK: Race — 2 players

    func testRaceReachingTierWinsFirstPlacement() {
        var m = match(.race(tier: 1), players: ["A", "B"])
        let actions = m.localMove(firstLegalMove(m.game))  // score 1 ≥ tier 1
        XCTAssertEqual(m.players["A"]?.status, .placed(1))
        XCTAssertTrue(actions.contains(.sendScore(1)))
    }

    func testRaceFirstToTierDoesNotEndMatchOthersPlaceAfter() {
        var m = match(.race(tier: 1), players: ["A", "B"])
        _ = m.localMove(firstLegalMove(m.game))  // A places 1st
        XCTAssertFalse(m.isOver)  // B still racing
        let actions = m.remoteScored("B", score: 1)  // B reaches tier → 2nd
        XCTAssertEqual(m.players["B"]?.status, .placed(2))
        XCTAssertTrue(m.isOver)
        XCTAssertEqual(actions.last, .finish(standings: ["A", "B"]))
    }

    func testRaceScoreBelowTierDoesNotPlace() {
        var m = match(.race(tier: 5), players: ["A", "B"])
        let actions = m.remoteScored("B", score: 3)
        XCTAssertEqual(m.players["B"]?.score, 3)
        XCTAssertEqual(m.players["B"]?.status, .active)
        XCTAssertTrue(actions.isEmpty)
    }

    // MARK: Race — 3 players, standings by score

    func testRaceThreePlayersStandingsByScore() {
        var m = match(.race(tier: 5), players: ["A", "B", "C"])
        _ = m.remoteScored("C", score: 5)  // C reaches tier (top score)
        _ = m.remoteEliminated("B")  // B out with score 0 (below the field)
        // A reaches the tier too (equal to C). The move that reaches it and
        // settles the match carries the finish.
        var finish: DuelMatch.Action?
        for _ in 0..<5 {
            let actions = m.localMove(firstLegalMove(m.game))
            if let f = actions.last, case .finish = f { finish = f }
        }
        // Standings by final score, highest first: A & C at 5, then B at 0.
        // A and C tie — roster order breaks the list stably, ranks are equal.
        XCTAssertEqual(finish, .finish(standings: ["A", "C", "B"]))
    }

    func testRaceStandingsAllEqualScore() {
        // Everyone finishes on the same score → a fully tied standings list,
        // stably in roster order (the result view shows them at equal rank).
        var m = match(.race(tier: 1), players: ["A", "B", "C"])
        _ = m.localMove(firstLegalMove(m.game))  // A → 1
        _ = m.remoteScored("C", score: 1)
        let actions = m.remoteScored("B", score: 1)
        XCTAssertEqual(actions.last, .finish(standings: ["A", "B", "C"]))
    }

    func testRaceDeadEndIsEliminatedNotPlaced() {
        var m = match(.race(tier: 100), players: ["A", "B"])
        let actions = m.noLegalMoves("B")  // B dead-ends before the tier
        // Dead-enders never took a placement — they rank below tier-reachers.
        XCTAssertEqual(m.players["B"]?.status, .eliminated)
        XCTAssertFalse(m.isOver)  // A still going
        XCTAssertFalse(
            actions.contains(where: {
                if case .finish = $0 { return true }; return false
            }))
    }

    func testRaceStandingsTierReacherBeatsDeadEnderRegardlessOfScore() {
        // B dead-ends with a high score; A reaches the tier. A still wins —
        // reaching the tier outranks any non-reacher.
        var m = match(.race(tier: 2), players: ["A", "B"])
        _ = m.remoteScored("B", score: 1)  // B ahead early…
        _ = m.noLegalMoves("B")  // …but dead-ends short of the tier
        // A reaches the tier: two local moves.
        _ = m.localMove(firstLegalMove(m.game))
        let actions = m.localMove(firstLegalMove(m.game))  // score 2 ≥ tier
        XCTAssertEqual(m.players["A"]?.status, .placed(1))
        XCTAssertTrue(m.isOver)
        XCTAssertEqual(actions.last, .finish(standings: ["A", "B"]))
    }

    // MARK: Disconnect / post-over

    func testDisconnectEliminatesInLockStep() {
        var m = match(.lockStep, players: ["A", "B", "C"])
        let actions = m.disconnected("B")
        XCTAssertEqual(m.players["B"]?.status, .eliminated)
        XCTAssertFalse(m.isOver)  // A, C continue
        XCTAssertFalse(
            actions.contains(where: {
                if case .finish = $0 { return true }; return false
            }))
    }

    func testDisconnectIsEliminatedInRace() {
        // A race disconnect never reached the tier, so it's out (eliminated),
        // ranking below any tier-reacher — not handed a placement.
        var m = match(.race(tier: 10), players: ["A", "B", "C"])
        _ = m.disconnected("B")
        XCTAssertEqual(m.players["B"]?.status, .eliminated)
        XCTAssertFalse(m.isOver)
    }

    func testEventsAfterOverAreNoOps() {
        var m = match(.lockStep, players: ["A", "B"])
        _ = m.localMove(firstLegalMove(m.game))
        _ = m.clockExpired("B")  // A wins, match over
        XCTAssertTrue(m.localMove(firstLegalMove(m.game)).isEmpty)
        XCTAssertTrue(m.remoteMoved("B").isEmpty)
        XCTAssertTrue(m.disconnected("B").isEmpty)
        XCTAssertTrue(m.clockExpired("B").isEmpty)
    }
}
