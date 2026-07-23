import Foundation

/// The Nearby duel's brain — pure state, no MultipeerConnectivity, so the whole
/// match is unit-testable headless. Supports 2–8 players and both `DuelMode`s.
/// `NearbyMatch` feeds it events (carrying the acting player) and executes the
/// `Action`s it returns; the reactive clock's countdown lives in the transport
/// (the match only knows a clock is running or not, per player).
///
/// Symmetric by design: the local player is just one entry in the roster, so
/// the same logic drives every player's state. Only the LOCAL player owns a
/// real `Game`; other players are tracked by their reported `score` alone
/// (lock-step needs "did they move this round?", race needs their number) —
/// boards are never replicated. Players trust each other (face-to-face).
public struct DuelMatch {
    /// Opaque, stable per-match player identifier (the peer's discovery tag).
    public typealias PlayerID = String

    public enum Status: Equatable {
        case active
        case eliminated
        /// Placed: 1 = winner, 2 = runner-up, … Assigned as players reach the
        /// tier (race) or as they're eliminated (lock-step: last standing = 1).
        case placed(Int)
    }

    public struct PlayerState: Equatable {
        public internal(set) var name: String
        public internal(set) var score: Int = 0
        public internal(set) var status: Status = .active
        /// Committed this lock-step round (reset each round). Unused in race.
        public internal(set) var movedThisRound = false
        /// Reactive clock running for this player (lock-step only).
        public internal(set) var clockRunning = false
    }

    /// What the transport must do after an event. Order matters.
    public enum Action: Equatable {
        /// Broadcast our committed move to everyone.
        case sendMove(Move)
        /// Broadcast our new score (race — drives opponents' live HUD).
        case sendScore(Int)
        /// Tell everyone we're out (clock expiry / dead-end).
        case sendEliminated
        /// Start/stop the visible reactive countdown for a player (lock-step).
        case startClock(PlayerID, seconds: TimeInterval)
        case stopClock(PlayerID)
        /// The match is over; payload is the final standings, winner-first.
        case finish(standings: [PlayerID])
    }

    public let mode: DuelMode
    public let local: PlayerID
    /// The roster in a stable order (as the host distributed it).
    public private(set) var order: [PlayerID]
    public private(set) var players: [PlayerID: PlayerState]
    /// The local player's own board — the one the UI renders and drives.
    public private(set) var game: Game
    public private(set) var isOver = false

    /// Next placement to hand out (1-based). Advances as players place.
    private var nextPlacement = 1
    /// Lock-step: a clock has been armed this round (first commit landed).
    private var roundArmed = false

    public init(
        mode: DuelMode, seed: UInt64, variantKey: String,
        local: PlayerID, roster: [(id: PlayerID, name: String)]
    ) {
        self.mode = mode
        self.local = local
        order = roster.map(\.id)
        players = Dictionary(
            uniqueKeysWithValues: roster.map { ($0.id, PlayerState(name: $0.name)) })
        game = Game(rules: Self.rules(for: variantKey), start: StartGenerator.pattern(seed: seed))
    }

    // MARK: Local events

    /// The local player committed a move in the duel UI.
    public mutating func localMove(_ move: Move) -> [Action] {
        guard !isOver, isActive(local) else { return [] }
        // Lock-step barrier: once you've committed this round you must wait for
        // everyone else — you cannot race ahead to the next move. (Committing
        // fast is still a weapon: it starts the others' clocks.)
        if case .lockStep = mode, players[local]?.movedThisRound == true { return [] }
        guard game.play(move) else { return [] }
        players[local]?.score = game.score
        var actions: [Action] = [.sendMove(move)]
        switch mode {
        case .lockStep:
            actions += commit(local)
            actions += resolveRoundIfComplete()
        case .race:
            actions.append(.sendScore(game.score))
            actions += placeIfReachedTier(local)
            actions += localDeadEndIfStuck()
        }
        return actions
    }

    /// The transport's reactive clock hit zero for a player (lock-step).
    public mutating func clockExpired(_ player: PlayerID) -> [Action] {
        guard case .lockStep = mode, !isOver, isActive(player),
            players[player]?.clockRunning == true
        else { return [] }
        return dropOut(player)
    }

    /// A player has no legal move while the match continues — they can't keep
    /// pace (lock-step) or reach the tier (race). Either way they're out; in
    /// race they rank below everyone who reached the tier, by final score.
    public mutating func noLegalMoves(_ player: PlayerID) -> [Action] {
        guard !isOver, isActive(player) else { return [] }
        return dropOut(player)
    }

    // MARK: Remote events (carry the sender)

    /// A remote player committed a move (lock-step: marks them moved).
    public mutating func remoteMoved(_ player: PlayerID) -> [Action] {
        guard case .lockStep = mode, !isOver, isActive(player) else { return [] }
        var actions = commit(player)
        actions += resolveRoundIfComplete()
        return actions
    }

    /// A remote player reported a new score (race: drives their HUD; may place).
    public mutating func remoteScored(_ player: PlayerID, score: Int) -> [Action] {
        guard case .race = mode, !isOver, isActive(player) else { return [] }
        players[player]?.score = score
        return placeIfReachedTier(player)
    }

    /// A remote player announced they're out (dead-ended / resigned).
    public mutating func remoteEliminated(_ player: PlayerID) -> [Action] {
        guard !isOver, isActive(player) else { return [] }
        return dropOut(player)
    }

    /// A player dropped off the session. Same as being out — they can no
    /// longer keep pace or reach the tier.
    public mutating func disconnected(_ player: PlayerID) -> [Action] {
        guard !isOver, isActive(player) else { return [] }
        return dropOut(player)
    }

    // MARK: Queries

    public func isActive(_ player: PlayerID) -> Bool {
        players[player]?.status == .active
    }

    /// Players still in the match, in roster order.
    public var activePlayers: [PlayerID] {
        order.filter { players[$0]?.status == .active }
    }

    /// Lock-step: the local player has committed and is waiting at the barrier
    /// for the others — the board should be locked until the round resolves.
    public var localWaitingForRound: Bool {
        guard case .lockStep = mode else { return false }
        return players[local]?.movedThisRound == true
    }

    /// The local player is stuck — still in the match, it's their turn (not
    /// waiting at the lock-step barrier), and the board has no legal move. The
    /// transport calls `noLegalMoves(local)` when this becomes true so a
    /// dead-end eliminates immediately instead of waiting out the clock.
    public var localHasNoMove: Bool {
        guard !isOver, isActive(local), !localWaitingForRound else { return false }
        return game.legalMoves().isEmpty
    }

    // MARK: Lock-step mechanics

    /// Register a commit: mark the player moved, stop their clock, and — if
    /// this is the round's first commit — arm everyone else's clock.
    private mutating func commit(_ player: PlayerID) -> [Action] {
        players[player]?.movedThisRound = true
        var actions: [Action] = []
        if players[player]?.clockRunning == true {
            players[player]?.clockRunning = false
            actions.append(.stopClock(player))
        }
        if !roundArmed {
            roundArmed = true
            for other in activePlayers
            where other != player && players[other]?.movedThisRound == false {
                players[other]?.clockRunning = true
                actions.append(.startClock(other, seconds: DuelMode.turnClock))
            }
        }
        return actions
    }

    /// When every surviving player has committed, the round ends: reset for the
    /// next parallel round (all clocks are already stopped by their commits).
    private mutating func resolveRoundIfComplete() -> [Action] {
        guard !isOver, activePlayers.allSatisfy({ players[$0]?.movedThisRound == true })
        else { return [] }
        for id in activePlayers { players[id]?.movedThisRound = false }
        roundArmed = false
        return []
    }

    // MARK: Placement / elimination

    /// Race: a player reached the tier → hand them the next placement.
    private mutating func placeIfReachedTier(_ player: PlayerID) -> [Action] {
        guard case .race(let tier) = mode, (players[player]?.score ?? 0) >= tier else { return [] }
        return place(player)
    }

    /// Assign the next placement to a player and end the match if everyone has
    /// placed / been eliminated.
    private mutating func place(_ player: PlayerID) -> [Action] {
        guard isActive(player) else { return [] }
        players[player]?.status = .placed(nextPlacement)
        nextPlacement += 1
        return finishIfSettled()
    }

    /// A player is out — clock expiry, dead-end, resign, or disconnect. Marks
    /// them `.eliminated` and stops any clock. In lock-step, if exactly one
    /// active player remains they win (placement 1). Ends the match once
    /// nobody is `.active`.
    private mutating func dropOut(_ player: PlayerID) -> [Action] {
        guard isActive(player) else { return [] }
        var actions: [Action] = player == local ? [.sendEliminated] : []
        if players[player]?.clockRunning == true {
            players[player]?.clockRunning = false
            actions.append(.stopClock(player))
        }
        players[player]?.status = .eliminated
        if case .lockStep = mode {
            let survivors = activePlayers
            if survivors.count == 1, let winner = survivors.first {
                players[winner]?.status = .placed(1)
            }
        }
        actions += finishIfSettled()
        // A drop can leave the round "complete" for the remaining players.
        actions += resolveRoundIfComplete()
        return actions
    }

    /// The local player dead-ends if the board is exhausted for them — out,
    /// same as `noLegalMoves` (checked after each local move in race).
    private mutating func localDeadEndIfStuck() -> [Action] {
        guard game.isOver, isActive(local) else { return [] }
        return dropOut(local)
    }

    /// End the match once no player is still `.active`. Final standings are by
    /// final score, highest first — equal scores are equal positions (the
    /// result view assigns tied ranks). `order` breaks ties stably so the list
    /// is deterministic, but same-score players display the same position.
    private mutating func finishIfSettled() -> [Action] {
        guard !isOver, activePlayers.isEmpty else { return [] }
        isOver = true
        let standings = order.sorted {
            (players[$0]?.score ?? 0) > (players[$1]?.score ?? 0)
        }
        return [.finish(standings: standings)]
    }

    private static func rules(for variantKey: String) -> Rules {
        Rules.selectable.first { $0.storageKey == variantKey } ?? .fiveT
    }
}
