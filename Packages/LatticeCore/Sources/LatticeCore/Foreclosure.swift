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

    /// If `upper` is 1–3 steps beyond `lower` along `axis`, return the dead span
    /// from `lower` to `upper` inclusive; else nil.
    ///
    /// The range is exactly the gaps a line can NEVER cross. A line needs five
    /// consecutive dots but may start inside a neighbour's span, so long as it
    /// reuses no unit segment — so with **three or more** empty dots between the
    /// two lines a legal window still fits (with three, x −4…0 clears both).
    /// Only 0, 1 or 2 empty dots — `steps` 1, 2, 3 — are genuinely sealed:
    ///
    /// - `steps == 1`: the lines abut; the single segment between them would
    ///   have to overlap one of them.
    /// - `steps == 2, 3`: one or two empty dots; every five-window covering them
    ///   reuses a segment at one end or the other.
    ///
    /// Both bounds have been wrong: it started at 2 (missing the abutting case)
    /// and ran to 5, claiming gaps of three and four empty dots that a line can
    /// still cross — four such false claims in one reported 85-move game.
    private static func gapSpan(lower: Point, upper: Point, axis: Axis) -> Line? {
        for steps in 1...3 where lower.offset(along: axis, by: steps) == upper {
            return Line(origin: lower, axis: axis, length: steps + 1)
        }
        return nil
    }
}
