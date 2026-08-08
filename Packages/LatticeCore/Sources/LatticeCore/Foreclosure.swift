/// Analysis: spans a move permanently killed. When you draw a line, look off
/// each end along the SAME axis — if another already-drawn line sits 1–4 dots
/// away, the gap between the two is dead: no line can ever be placed spanning
/// it (both sides are walled by drawn lines). That's a self-inflicted loss the
/// player can review — "you left a gap here that can never become a line".
///
/// Reported per move (the move whose new line closed the gap), as the dead span
/// itself (a short line from this line's end to the other line's near end).
public enum Foreclosure {
    /// A dead gap between two collinear drawn lines.
    public struct Loss: Equatable, Sendable {
        /// The move index (0-based) whose line closed the gap.
        public let moveIndex: Int
        /// The dead span: origin/axis/length covering the gap and its two
        /// bracketing endpoints.
        public let span: Line
    }

    /// Walk the recorded game; each move's new line is checked off both ends for
    /// a nearby parallel line, marking the enclosed gap dead.
    public static func losses(in record: GameRecord) -> [Loss] {
        losses(moves: record.moves)
    }

    /// Same, over a live game's move stack.
    public static func losses(in game: Game) -> [Loss] {
        losses(moves: game.moves)
    }

    private static func losses(moves: [Move]) -> [Loss] {
        var drawn: [Line] = []
        var losses: [Loss] = []
        for (index, move) in moves.enumerated() {
            for gap in deadGaps(newLine: move.line, against: drawn) {
                losses.append(Loss(moveIndex: index, span: gap))
            }
            drawn.append(move.line)
        }
        return losses
    }

    /// Gaps sealed by `newLine`: for each of its two ends, if another drawn line
    /// on the same axis lies 1–4 dots beyond (facing it), the span from this
    /// end's dot to that line's near end is dead.
    private static func deadGaps(newLine: Line, against drawn: [Line]) -> [Line] {
        guard let newFirst = newLine.points.first, let newLast = newLine.points.last else {
            return []
        }
        var gaps: [Line] = []
        for other in drawn where other.axis == newLine.axis {
            guard let oFirst = other.points.first, let oLast = other.points.last else { continue }
            // Other line AFTER us on the axis: gap from our last dot → its first.
            if let span = gapSpan(lower: newLast, upper: oFirst, axis: newLine.axis) {
                gaps.append(span)
            }
            // Other line BEFORE us on the axis: gap from its last dot → our first.
            if let span = gapSpan(lower: oLast, upper: newFirst, axis: newLine.axis) {
                gaps.append(span)
            }
        }
        return gaps
    }

    /// If `upper` is 2–5 steps beyond `lower` along `axis` (a 1–4 dot gap that
    /// can't hold a full line), return the dead span from `lower` to `upper`
    /// inclusive; else nil.
    private static func gapSpan(lower: Point, upper: Point, axis: Axis) -> Line? {
        for steps in 2...5 where lower.offset(along: axis, by: steps) == upper {
            return Line(origin: lower, axis: axis, length: steps + 1)
        }
        return nil
    }
}
