import Foundation
import LatticeCore
import SwiftUI

/// UI-facing game state: the engine plus the two-stage input's tentative
/// placement. Placement and commit are separate steps, so cancel needs no
/// mechanism — nothing reaches the engine until a candidate line is chosen.
///
/// Persistence: the current game auto-saves on every mutation; a finished
/// game is recorded (idempotently, by game id) and counts toward the best.
public final class GameSession: ObservableObject {
    @Published public private(set) var game: Game
    @Published public private(set) var tentative: Point?
    @Published public private(set) var movesByDot: [Point: [Move]]
    @Published public private(set) var bests: BestScores

    private let store: LatticeStore
    private var gameID: UUID

    public init(rules: Rules = .fiveT, store: LatticeStore = .appSupport()) {
        self.store = store
        bests = store.loadBests()
        let restored = store.loadCurrent().flatMap { snapshot in
            Game(snapshot: snapshot).map { ($0, snapshot.id) }
        }
        let (game, id) = restored ?? (Game(rules: rules), UUID())
        self.game = game
        gameID = id
        movesByDot = game.legalMovesByDot()
    }

    public var candidates: [Move] {
        tentative.flatMap { movesByDot[$0] } ?? []
    }

    public var isOver: Bool { movesByDot.isEmpty }

    public var best: Int? { bests.best(for: game.rules) }

    /// True if the point accepts a tentative dot (some line goes through it).
    public func isPlaceable(_ p: Point) -> Bool { movesByDot[p] != nil }

    public func place(_ p: Point) {
        guard isPlaceable(p) else { return }
        tentative = p
    }

    public func cancel() {
        tentative = nil
    }

    public func commit(_ move: Move) {
        guard game.play(move) else { return }
        tentative = nil
        refresh()
        persist()
        if isOver { finishGame() }
    }

    public func undo() {
        guard game.undo() != nil else { return }
        tentative = nil
        refresh()
        persist()
    }

    public func newGame() {
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
        store.saveCurrent(GameSnapshot(game: game, id: gameID))
    }

    private func finishGame() {
        store.saveRecord(GameRecord(game: game, id: gameID, finishedAt: Date()))
        if bests.register(game.score, for: game.rules) {
            store.saveBests(bests)
        }
    }
}
