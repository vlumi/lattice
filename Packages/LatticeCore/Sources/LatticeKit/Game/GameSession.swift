import Foundation
import LatticeCore
import SwiftUI

/// UI-facing game state: the engine plus the two-stage input's tentative
/// placement. Placement and commit are separate steps, so cancel needs no
/// mechanism — nothing reaches the engine until a candidate line is chosen.
///
/// Three modes over the same engine:
/// - `.free`: unlimited undo, New Game any time; auto-saves to the current
///   slot; finished games are recorded and count toward the best.
/// - `.daily`: one attempt per local date at the day's challenge, one undo
///   per committed move; the finished board stays on display and the result
///   feeds the streak.
/// - `.passAndPlay`: two players alternate moves on one device; the last
///   player able to move wins. Undo only before the opponent replies (the
///   same armed-undo rule as the daily). No records, bests, or ghost — a
///   match is its own event.
public final class GameSession: ObservableObject {
    public enum Mode {
        case free
        case daily
        case passAndPlay
    }

    @Published public private(set) var game: Game
    @Published public private(set) var tentative: Point?
    @Published public private(set) var movesByDot: [Point: [Move]]
    @Published public private(set) var bests: BestScores
    @Published public private(set) var dailyLog: DailyLog
    /// The live game's openness so far (legal moves before each move + now).
    @Published public private(set) var opennessHistory: [Int] = []
    /// The personal-best game's openness curve — the ghost to race.
    @Published public private(set) var pbCurve: [Int]?
    /// The challenge seed of the current game, if it's a seeded start.
    @Published public private(set) var seed: UInt64?
    /// Unlinked ("+") rules: lines drawable through existing dots alone —
    /// standing offers that pair with a dot placed anywhere.
    @Published public private(set) var freeLines: [Line] = []
    /// Keyboard play: the roaming cursor (nil until an arrow is first pressed,
    /// so it never shows for pure mouse/touch play).
    @Published public internal(set) var keyboardCursor: Point?
    /// Keyboard play: which of `candidates` is highlighted while a dot is
    /// tentative (stage two).
    @Published public internal(set) var candidateIndex = 0
    /// A seeded start is being generated off the main actor (see
    /// `generateChallenge`) — the board shows a "generating" indicator.
    @Published public private(set) var isGenerating = false

    public let mode: Mode

    private let store: LatticeStore
    private var gameID: UUID
    /// Set by the app layer: called when a best/daily result is persisted, so
    /// sync can fold it up. No-op (nil) when sync isn't wired.
    public var onSyncedChange: (() -> Void)?
    private var dateKey: String
    /// Daily: armed by a commit, spent by an undo — one undo per move.
    private var undoArmed = false
    /// Bumped per generate request so a stale one can't overwrite a newer board.
    private var generation = 0
    /// The in-flight seeded-start generation, exposed so tests (and any caller
    /// that must sequence on it) can await the new board.
    public private(set) var generateTask: Task<Void, Never>?

    private struct Resolved {
        let game: Game
        let id: UUID
        let seed: UInt64?
    }

    /// The game that was replaced by the last New Game / restart, kept only
    /// briefly so an undo can bring it back — an accidental restart mid-game is
    /// recoverable. Lives on the fresh board until the first move commits to it
    /// (then it's gone — this is a safety net, not an archive of past games).
    /// Free/versus only (the daily has its own one-undo rule).
    private struct RestorePoint {
        let game: Game
        let id: UUID
        let seed: UInt64?
        let openness: [Int]
    }
    private var restorePoint: RestorePoint?

    public init(mode: Mode = .free, rules: Rules = .fiveT, store: LatticeStore = .appSupport()) {
        self.mode = mode
        self.store = store
        bests = store.loadBests()
        dailyLog = store.loadDailyLog()
        let todayKey = DailyChallenge.dateKey()
        dateKey = todayKey

        let resolved = Self.resolve(mode: mode, rules: rules, store: store, todayKey: todayKey)
        game = resolved.game
        gameID = resolved.id
        seed = resolved.seed
        movesByDot = Self.linkedMovesByDot(of: resolved.game)
        freeLines = resolved.game.freeLines()
        opennessHistory = resolved.game.opennessCurve()
        pbCurve =
            mode == .passAndPlay
            ? nil
            : Self.bestCurve(
                in: store, key: resolved.game.rules.variantKey(forStart: resolved.game.start))
    }

    /// Restore the mode's saved game, or start fresh.
    private static func resolve(
        mode: Mode, rules: Rules, store: LatticeStore, todayKey: String
    ) -> Resolved {
        switch mode {
        case .free:
            let restored = store.loadCurrent().flatMap { snapshot in
                Game(snapshot: snapshot).map {
                    Resolved(game: $0, id: snapshot.id, seed: snapshot.seed)
                }
            }
            return restored ?? Resolved(game: Game(rules: rules), id: UUID(), seed: nil)
        case .daily:
            let attempt = store.loadDailyAttempt()
            let restored: Resolved? =
                attempt?.dateKey == todayKey
                ? attempt.flatMap { stored in
                    Game(snapshot: stored.snapshot).map {
                        Resolved(game: $0, id: stored.snapshot.id, seed: nil)
                    }
                }
                : nil
            let board = DailyChallenge.board(for: todayKey)
            let fresh = Game(
                rules: board?.rules ?? .fiveT,
                start: board?.start ?? StartingPattern.standardCross)
            return restored ?? Resolved(game: fresh, id: UUID(), seed: nil)
        case .passAndPlay:
            let restored = store.loadVersus().flatMap { snapshot in
                Game(snapshot: snapshot).map {
                    Resolved(game: $0, id: snapshot.id, seed: nil)
                }
            }
            return restored ?? Resolved(game: Game(rules: rules), id: UUID(), seed: nil)
        }
    }

    /// Moves grouped by dot for the input flow — through-dot moves only;
    /// unlinked rules' representative free-line pairings are excluded (free
    /// lines are offered with whatever dot the player places).
    private static func linkedMovesByDot(of game: Game) -> [Point: [Move]] {
        game.legalMovesByDot().compactMapValues { moves in
            let linked = moves.filter { $0.line.points.contains($0.dot) }
            return linked.isEmpty ? nil : linked
        }
    }

    /// Re-read bests + daily log after a sync merge changed local state, so
    /// the header's best/streak reflect the pulled data. Does not disturb the
    /// in-progress game.
    public func reloadSyncedState() {
        bests = store.loadBests()
        dailyLog = store.loadDailyLog()
    }

    /// After a progress reset: drop the in-memory game and reload from the (now
    /// empty) store, so the board, bests, streak and personal-best ghost all
    /// reflect the wipe without needing a relaunch.
    public func resetAfterWipe() {
        restorePoint = nil
        let resolved = Self.resolve(
            mode: mode, rules: game.rules, store: store, todayKey: DailyChallenge.dateKey())
        start(resolved.game, seed: resolved.seed)
        bests = store.loadBests()
        dailyLog = store.loadDailyLog()
        pbCurve = nil
        opennessHistory = [totalLegalMoves]
    }

    /// The openness curve of the highest-scoring stored game in this
    /// scoring pool, if any.
    private static func bestCurve(in store: LatticeStore, key: String) -> [Int]? {
        store.loadRecords()
            .filter { $0.variantKey == key }
            .max { $0.score < $1.score }?
            .legalMoveCurve()
    }

    public var candidates: [Move] {
        guard let tentative else { return [] }
        var result = movesByDot[tentative] ?? []
        // Any free line can be taken with this placement.
        result += freeLines.map { Move(dot: tentative, line: $0) }
        return result
    }

    public var isOver: Bool { movesByDot.isEmpty && freeLines.isEmpty }

    /// Gaps this game has permanently sealed between two collinear lines — a
    /// dead span no line can ever fill (see `Foreclosure`). Drawn by BoardView.
    /// Cached in `refresh()`, not computed per read: the scan is O(moves²) and
    /// the board's draw would re-run it on every pan/zoom frame.
    @Published public private(set) var deadGaps: [Line] = []

    /// The scoring pool of the current game ("5T", "5T#", …).
    public var variantKey: String { game.rules.variantKey(forStart: game.start) }

    public var best: Int? { bests.best(forKey: variantKey) }

    public var seedCode: String? { seed.map(SeedCode.encode) }

    /// Daily: today's result is in — the board is display-only.
    public var dailyDone: Bool {
        mode == .daily && dailyLog.results[dateKey] != nil
    }

    public var dailyStreak: Int {
        dailyLog.streak(today: dateKey)
    }

    public var dailyLongestStreak: Int {
        dailyLog.longestStreak()
    }

    /// The daily's date key, for captions; nil in free mode.
    public var dailyKey: String? {
        mode == .daily ? dateKey : nil
    }

    public var undoAllowed: Bool {
        guard !dailyDone else { return false }
        // A restore point (undo a New Game / restart) is undoable even on the
        // fresh board's empty move list.
        if game.moves.isEmpty {
            return restorePoint != nil && (mode == .free || mode == .passAndPlay)
        }
        return mode == .free || undoArmed
    }

    /// Pass-and-play: whose turn (1 or 2). Player 1 moves first.
    public var playerToMove: Int { game.moves.count % 2 + 1 }

    /// Pass-and-play, finished games: the winner — the LAST player able to
    /// move. Nil while the match runs (or on an unstarted board, where
    /// there is no last mover).
    public var winner: Int? {
        guard mode == .passAndPlay, isOver, !game.moves.isEmpty else { return nil }
        return (game.moves.count - 1) % 2 + 1
    }

    /// True if the point accepts a tentative dot: some line goes through
    /// it — or, with a free line standing, anywhere empty works.
    public func isPlaceable(_ p: Point) -> Bool {
        movesByDot[p] != nil || (!freeLines.isEmpty && !game.dots.contains(p))
    }

    public func place(_ p: Point) {
        guard !dailyDone, isPlaceable(p) else { return }
        tentative = p
        candidateIndex = 0
    }

    public func cancel() {
        tentative = nil
        candidateIndex = 0
    }

    public func commit(_ move: Move) {
        guard !dailyDone, game.play(move) else { return }
        // The first move on a fresh board commits to it — the just-replaced
        // game is no longer recoverable (the restore point is a brief
        // accidental-restart safety net, not an archive of past games).
        restorePoint = nil
        tentative = nil
        candidateIndex = 0
        undoArmed = true
        refresh()
        opennessHistory.append(totalLegalMoves)
        persist()
        if isOver { finishGame() }
    }

    public func undo() {
        guard undoAllowed else { return }
        // On the fresh board (no moves), undo means "undo the New Game/restart":
        // bring the replaced game back.
        if game.moves.isEmpty {
            guard let restore = restorePoint else { return }
            game = restore.game
            seed = restore.seed
            gameID = restore.id
            restorePoint = nil
            tentative = nil
            candidateIndex = 0
            undoArmed = false
            refresh()
            opennessHistory = restore.openness
            pbCurve = mode == .passAndPlay ? nil : Self.bestCurve(in: store, key: variantKey)
            persist()
            return
        }
        guard game.undo() != nil else { return }
        tentative = nil
        candidateIndex = 0
        undoArmed = false
        refresh()
        if opennessHistory.count > 1 { opennessHistory.removeLast() }
        persist()
    }

    public func newGame(rules: Rules? = nil) {
        guard mode != .daily else { return }
        let newRules = rules ?? game.rules
        if rules == nil, let seed {
            generateChallenge(seed: seed)  // same seed again — regenerate off-main
        } else {
            start(Game(rules: newRules, start: StartingPattern.standard(for: newRules)), seed: nil)
        }
    }

    /// Free mode only: a seeded-start challenge (the 5T# form). The code is
    /// the whole challenge — same seed, same board, anywhere.
    public func newChallenge(seed: UInt64) {
        guard mode == .free else { return }
        generateChallenge(seed: seed)
    }

    /// Generating a seeded start scans up to 256 candidates through the solver,
    /// which is slow enough to freeze a tap — so it runs off the main actor and
    /// the caller returns at once. `isGenerating` drives the board's indicator;
    /// a newer request supersedes an in-flight one.
    private func generateChallenge(seed: UInt64) {
        generation &+= 1
        let token = generation
        isGenerating = true
        generateTask?.cancel()
        generateTask = Task { [weak self] in
            let pattern = await Task.detached(priority: .userInitiated) {
                StartGenerator.pattern(seed: seed)
            }.value
            guard let self, !Task.isCancelled, token == self.generation else { return }
            self.start(Game(rules: .fiveT, start: pattern), seed: seed)
            self.isGenerating = false
        }
    }

    private func start(_ newGame: Game, seed: UInt64?) {
        // Snapshot the outgoing game so an undo can recover it — but only if it
        // was actually in progress (a fresh, unplayed board isn't worth
        // "restoring"). Free/versus only; the daily can't restart.
        restorePoint =
            (mode != .daily && !game.moves.isEmpty)
            ? RestorePoint(game: game, id: gameID, seed: self.seed, openness: opennessHistory)
            : nil
        game = newGame
        self.seed = seed
        gameID = UUID()
        tentative = nil
        refresh()
        opennessHistory = [totalLegalMoves]
        pbCurve = Self.bestCurve(in: store, key: variantKey)
        persist()
    }

    private var totalLegalMoves: Int {
        movesByDot.values.reduce(0) { $0 + $1.count } + freeLines.count
    }

    private func refresh() {
        movesByDot = Self.linkedMovesByDot(of: game)
        freeLines = game.freeLines()
        deadGaps = Foreclosure.losses(in: game).map(\.span)
    }

    private func persist() {
        let snapshot = GameSnapshot(game: game, id: gameID, seed: seed)
        switch mode {
        case .free:
            store.saveCurrent(snapshot)
        case .daily:
            store.saveDailyAttempt(DailyAttempt(dateKey: dateKey, snapshot: snapshot))
        case .passAndPlay:
            store.saveVersus(snapshot)
        }
    }

    private func finishGame() {
        // A pass-and-play match is its own event: no records, bests, or
        // daily side effects.
        guard mode != .passAndPlay else { return }
        store.saveRecord(
            GameRecord(
                game: game, id: gameID, finishedAt: Date(), seed: seed,
                // Stamped at save time: History can't tell a daily from a
                // random-start challenge afterwards — they share the 5T# pool.
                dailyDateKey: mode == .daily ? dateKey : nil))
        var syncedChange = false
        if bests.register(game.score, forKey: variantKey) {
            store.saveBests(bests)
            // The game just played becomes the ghost.
            pbCurve = opennessHistory
            syncedChange = true
        }
        if mode == .daily {
            dailyLog.record(
                DailyLog.Result(score: game.score, finishedAt: Date()), for: dateKey)
            store.saveDailyLog(dailyLog)
            syncedChange = true
        }
        // A new best or daily result is sync-relevant; nudge the coordinator
        // (no-op when sync is off — set only by the app layer).
        if syncedChange { onSyncedChange?() }
    }
}
