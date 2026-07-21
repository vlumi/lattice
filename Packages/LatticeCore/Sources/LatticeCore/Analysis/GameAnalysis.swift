/// Openness: how many legal moves a position holds. The curve over a game's
/// moves is its biography — where it peaks the game held the most potential;
/// the slide to zero is where the position died.
enum Openness {
    /// One sample before each move plus the final position. Replays through
    /// the engine; stops early if a move is illegal (corrupt data).
    static func curve(rules: Rules, start: Set<Point>, moves: [Move]) -> [Int] {
        var game = Game(rules: rules, start: start)
        var curve = [game.legalMoves().count]
        for move in moves {
            guard game.play(move) else { break }
            curve.append(game.legalMoves().count)
        }
        return curve
    }
}

extension GameRecord {
    /// The openness curve of the recorded game — `moves.count + 1` samples
    /// unless the record is corrupt.
    public func legalMoveCurve() -> [Int] {
        Openness.curve(rules: rules, start: start, moves: moves)
    }
}

extension Game {
    /// The openness curve of this game so far, recomputed from the start.
    public func opennessCurve() -> [Int] {
        Openness.curve(rules: rules, start: start, moves: moves)
    }
}
