import Foundation

/// The duel's brain — pure, no MultipeerConnectivity, so the whole match is
/// unit-testable headlessly. The transport feeds it events and performs the
/// actions it returns.
///
/// Rules (see the duel plan / AGENTS.md):
/// - Both players race the same seeded board to `tier` lines.
/// - **Lock-step reactive clock**: each turn both think in parallel; the first
///   to commit starts the OTHER player's `turnClock` countdown. Letting your
///   running clock hit zero loses the whole game (sudden death).
/// - First to reach `tier` wins. A resign/timeout loses.
///
/// This type tracks only the LOCAL player's game plus the clock bookkeeping;
/// the opponent's board isn't mirrored — their `reachedTier`/`resign` claims
/// and move timings are what cross the wire (trusted, face-to-face).
public struct DuelProtocol {
    public enum Outcome: Equatable {
        case won
        case lost
    }

    /// What the transport must do after an event.
    public enum Action: Equatable {
        /// Send our committed move (with our clock reading) to the opponent.
        case sendMove(Move, clock: TimeInterval)
        /// Start the local player's visible countdown from `seconds` — the
        /// opponent moved first and put us on the clock.
        case startLocalClock(seconds: TimeInterval)
        /// Stop the local countdown (we committed; the turn resolved).
        case stopLocalClock
        /// Tell the opponent we hit the tier (a win claim).
        case sendReachedTier
        /// Tell the opponent we're out (timeout/quit).
        case sendResign
        /// The match is over.
        case finish(Outcome)
    }

    public static let turnClock: TimeInterval = 10

    public let tier: Int
    public private(set) var game: Game
    public private(set) var outcome: Outcome?
    /// Whether the local player has committed this turn (waiting on opponent).
    public private(set) var localMovedThisTurn = false
    /// Whether the opponent has committed this turn (our clock is running).
    public private(set) var localClockRunning = false

    public init(seed: UInt64, variantKey: String, tier: Int) {
        self.tier = tier
        game = Game(rules: Self.rules(for: variantKey), start: StartGenerator.pattern(seed: seed))
    }

    private var isOver: Bool { outcome != nil }

    // MARK: Local events

    /// The local player committed a move. Returns the actions to perform
    /// (broadcast it, resolve the turn, maybe win).
    public mutating func localMove(_ move: Move, clock: TimeInterval) -> [Action] {
        guard !isOver, !localMovedThisTurn, game.play(move) else { return [] }
        localMovedThisTurn = true
        var actions: [Action] = [.sendMove(move, clock: clock)]
        // Committing stops any clock the opponent started on us.
        if localClockRunning {
            localClockRunning = false
            actions.append(.stopLocalClock)
        }
        if game.score >= tier {
            actions.append(.sendReachedTier)
            actions += finish(.won)
            return actions
        }
        actions += resolveTurnIfComplete()
        return actions
    }

    /// The local player's running clock hit zero — sudden-death loss.
    public mutating func localClockExpired() -> [Action] {
        guard !isOver, localClockRunning else { return [] }
        return [.sendResign] + finish(.lost)
    }

    // MARK: Remote events

    /// The opponent committed their move (timing rides in the message). If we
    /// haven't moved yet this turn, their commit starts our clock.
    public mutating func remoteMoved(clock: TimeInterval) -> [Action] {
        guard !isOver, !remoteMovedThisTurn else { return [] }
        remoteMovedThisTurn = true
        var actions: [Action] = []
        if !localMovedThisTurn, !localClockRunning {
            localClockRunning = true
            actions.append(.startLocalClock(seconds: Self.turnClock))
        }
        actions += resolveTurnIfComplete()
        return actions
    }

    /// The opponent claims they reached the tier — they win, UNLESS we
    /// already finished (a local win reaches `isOver` first and no-ops this).
    /// A dead-heat where both reach the tier on the same wire round resolves
    /// by message-arrival order; acceptable for a trusted face-to-face match,
    /// where "that was close" is the whole point — no timestamp arbitration.
    public mutating func remoteReachedTier() -> [Action] {
        guard !isOver else { return [] }
        return finish(.lost)
    }

    /// The opponent resigned or timed out — we win.
    public mutating func remoteResigned() -> [Action] {
        guard !isOver else { return [] }
        return finish(.won)
    }

    /// The connection dropped mid-match — treated as the opponent forfeiting
    /// (we're still here). The transport decides when a drop is terminal.
    public mutating func disconnected() -> [Action] {
        guard !isOver else { return [] }
        return finish(.won)
    }

    // MARK: Turn bookkeeping

    private var remoteMovedThisTurn = false

    /// When both have committed, the turn ends: reset for the next parallel
    /// round. (A win is detected in `localMove` before this runs.)
    private mutating func resolveTurnIfComplete() -> [Action] {
        guard localMovedThisTurn, remoteMovedThisTurn, !isOver else { return [] }
        localMovedThisTurn = false
        remoteMovedThisTurn = false
        // Clock is already stopped by whoever moved second; ensure it's clear.
        if localClockRunning {
            localClockRunning = false
            return [.stopLocalClock]
        }
        return []
    }

    private mutating func finish(_ result: Outcome) -> [Action] {
        outcome = result
        localClockRunning = false
        return [.finish(result)]
    }

    private static func rules(for variantKey: String) -> Rules {
        Rules.selectable.first { $0.storageKey == variantKey } ?? .fiveT
    }
}
