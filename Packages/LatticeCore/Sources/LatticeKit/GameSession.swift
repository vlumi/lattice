import Foundation
import LatticeCore
import SwiftUI

/// UI-facing game state: the engine plus the two-stage input's tentative
/// placement. Placement and commit are separate steps, so cancel needs no
/// mechanism — nothing reaches the engine until a candidate line is chosen.
///
/// Two modes over the same engine:
/// - `.free`: unlimited undo, New Game any time; auto-saves to the current
///   slot; finished games are recorded and count toward the best.
/// - `.daily`: one attempt per local date at the day's challenge, one undo
///   per committed move; the finished board stays on display and the result
///   feeds the streak.
public final class GameSession: ObservableObject {
    public enum Mode {
        case free
        case daily
    }

    @Published public private(set) var game: Game
    @Published public private(set) var tentative: Point?
    @Published public private(set) var movesByDot: [Point: [Move]]
    @Published public private(set) var bests: BestScores
    @Published public private(set) var dailyLog: DailyLog

    public let mode: Mode

    private let store: LatticeStore
    private var gameID: UUID
    private var dateKey: String
    /// Daily: armed by a commit, spent by an undo — one undo per move.
    private var undoArmed = false

    public init(mode: Mode = .free, rules: Rules = .fiveT, store: LatticeStore = .appSupport()) {
        self.mode = mode
        self.store = store
        bests = store.loadBests()
        dailyLog = store.loadDailyLog()
        let todayKey = DailyChallenge.dateKey()
        dateKey = todayKey

        let resolved: (game: Game, id: UUID)
        switch mode {
        case .free:
            let restored = store.loadCurrent().flatMap { snapshot in
                Game(snapshot: snapshot).map { ($0, snapshot.id) }
            }
            resolved = restored ?? (Game(rules: rules), UUID())
        case .daily:
            let attempt = store.loadDailyAttempt()
            let restored: (Game, UUID)? =
                attempt?.dateKey == todayKey
                ? attempt.flatMap { stored in
                    Game(snapshot: stored.snapshot).map { ($0, stored.snapshot.id) }
                }
                : nil
            let board = DailyChallenge.board(for: todayKey)
            let fresh = Game(
                rules: board?.rules ?? .fiveT,
                start: board?.start ?? StartingPattern.standardCross)
            resolved = restored ?? (fresh, UUID())
        }
        game = resolved.game
        gameID = resolved.id
        movesByDot = resolved.game.legalMovesByDot()
    }

    public var candidates: [Move] {
        tentative.flatMap { movesByDot[$0] } ?? []
    }

    public var isOver: Bool { movesByDot.isEmpty }

    public var best: Int? { bests.best(for: game.rules) }

    /// Daily: today's result is in — the board is display-only.
    public var dailyDone: Bool {
        mode == .daily && dailyLog.results[dateKey] != nil
    }

    public var dailyStreak: Int {
        dailyLog.streak(today: dateKey)
    }

    public var undoAllowed: Bool {
        guard !game.moves.isEmpty, !dailyDone else { return false }
        return mode == .free || undoArmed
    }

    /// True if the point accepts a tentative dot (some line goes through it).
    public func isPlaceable(_ p: Point) -> Bool { movesByDot[p] != nil }

    public func place(_ p: Point) {
        guard !dailyDone, isPlaceable(p) else { return }
        tentative = p
    }

    public func cancel() {
        tentative = nil
    }

    public func commit(_ move: Move) {
        guard !dailyDone, game.play(move) else { return }
        tentative = nil
        undoArmed = true
        refresh()
        persist()
        if isOver { finishGame() }
    }

    public func undo() {
        guard undoAllowed, game.undo() != nil else { return }
        tentative = nil
        undoArmed = false
        refresh()
        persist()
    }

    /// Free mode only — the daily is one attempt per day.
    public func newGame() {
        guard mode == .free else { return }
        game = Game(rules: game.rules, start: game.start)
        gameID = UUID()
        tentative = nil
        refresh()
        persist()
    }

    private func refresh() {
        movesByDot = game.legalMovesByDot()
    }

    private func persist() {
        let snapshot = GameSnapshot(game: game, id: gameID)
        switch mode {
        case .free:
            store.saveCurrent(snapshot)
        case .daily:
            store.saveDailyAttempt(DailyAttempt(dateKey: dateKey, snapshot: snapshot))
        }
    }

    private func finishGame() {
        store.saveRecord(GameRecord(game: game, id: gameID, finishedAt: Date()))
        if bests.register(game.score, for: game.rules) {
            store.saveBests(bests)
        }
        if mode == .daily {
            dailyLog.record(
                DailyLog.Result(score: game.score, finishedAt: Date()), for: dateKey)
            store.saveDailyLog(dailyLog)
        }
    }
}
