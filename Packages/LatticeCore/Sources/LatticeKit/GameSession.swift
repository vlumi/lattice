import LatticeCore
import SwiftUI

/// UI-facing game state: the engine plus the two-stage input's tentative
/// placement. Placement and commit are separate steps, so cancel needs no
/// mechanism — nothing reaches the engine until a candidate line is chosen.
public final class GameSession: ObservableObject {
    @Published public private(set) var game: Game
    @Published public private(set) var tentative: Point?
    @Published public private(set) var movesByDot: [Point: [Move]]

    public init(rules: Rules = .fiveT) {
        let game = Game(rules: rules)
        self.game = game
        movesByDot = game.legalMovesByDot()
    }

    public var candidates: [Move] {
        tentative.flatMap { movesByDot[$0] } ?? []
    }

    public var isOver: Bool { movesByDot.isEmpty }

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
    }

    public func undo() {
        guard game.undo() != nil else { return }
        tentative = nil
        refresh()
    }

    public func newGame() {
        game = Game(rules: game.rules, start: game.start)
        tentative = nil
        refresh()
    }

    private func refresh() {
        movesByDot = game.legalMovesByDot()
    }
}
