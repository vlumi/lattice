extension GameRecord {
    /// The openness curve: the legal-move count in the position **before**
    /// each move, plus the final position — `moves.count + 1` samples. Where
    /// this peaks is where the game held the most potential; the slide to
    /// zero is where the position died. Replays through the engine; stops
    /// early on a corrupt record.
    public func legalMoveCurve() -> [Int] {
        var game = Game(rules: rules, start: start)
        var curve = [game.legalMoves().count]
        for move in moves {
            guard game.play(move) else { break }
            curve.append(game.legalMoves().count)
        }
        return curve
    }
}
