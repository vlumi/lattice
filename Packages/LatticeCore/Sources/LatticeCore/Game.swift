/// The full game state: dots, drawn lines' bookkeeping, and the move stack
/// (which doubles as the replay). A value type — copy to explore, assign to
/// restore.
public struct Game: Hashable, Sendable {
    public let rules: Rules
    public let start: Set<Point>
    public private(set) var dots: Set<Point>
    public private(set) var moves: [Move]

    // Both overlap bookkeepings are maintained regardless of variant (cheap,
    // and keeps undo uniform); `rules.overlap` picks which one legality reads.
    private var usedSegments: Set<Segment>
    private var usedLineDots: Set<AxisUse>

    private struct AxisUse: Hashable, Sendable {
        let point: Point
        let axis: Axis
    }

    public init(rules: Rules = .fiveT, start: Set<Point> = StartingPattern.standardCross) {
        self.rules = rules
        self.start = start
        dots = start
        moves = []
        usedSegments = []
        usedLineDots = []
    }

    public var score: Int { moves.count }

    public func isLegal(_ move: Move) -> Bool {
        guard move.line.length == rules.lineLength else { return false }
        let points = move.line.points
        guard points.contains(move.dot), !dots.contains(move.dot) else { return false }
        guard points.allSatisfy({ $0 == move.dot || dots.contains($0) }) else { return false }
        switch rules.overlap {
        case .touching:
            return !move.line.segments.contains { usedSegments.contains($0) }
        case .disjoint:
            return !points.contains {
                usedLineDots.contains(AxisUse(point: $0, axis: move.line.axis))
            }
        }
    }

    /// Plays the move if legal; returns whether it was.
    @discardableResult
    public mutating func play(_ move: Move) -> Bool {
        guard isLegal(move) else { return false }
        dots.insert(move.dot)
        usedSegments.formUnion(move.line.segments)
        for p in move.line.points {
            usedLineDots.insert(AxisUse(point: p, axis: move.line.axis))
        }
        moves.append(move)
        return true
    }

    /// Reverts the latest move; returns it, or nil on a fresh game.
    @discardableResult
    public mutating func undo() -> Move? {
        guard let move = moves.popLast() else { return nil }
        dots.remove(move.dot)
        usedSegments.subtract(move.line.segments)
        for p in move.line.points {
            usedLineDots.remove(AxisUse(point: p, axis: move.line.axis))
        }
        return move
    }

    /// Every legal move in the current position. A move is a (new dot, line)
    /// pair, so one placement can appear with several lines.
    public func legalMoves() -> [Move] {
        var result: [Move] = []
        enumerateLegalMoves { result.append($0) }
        return result
    }

    public var isOver: Bool {
        var found = false
        enumerateLegalMoves { _ in found = true }
        return !found
    }

    private func enumerateLegalMoves(_ body: (Move) -> Void) {
        guard let first = dots.first else { return }
        var (minX, maxX, minY, maxY) = (first.x, first.x, first.y, first.y)
        for dot in dots {
            minX = min(minX, dot.x)
            maxX = max(maxX, dot.x)
            minY = min(minY, dot.y)
            maxY = max(maxY, dot.y)
        }
        let reach = rules.lineLength - 1
        for x in (minX - 1)...(maxX + 1) {
            for y in (minY - 1)...(maxY + 1) {
                let candidate = Point(x, y)
                if dots.contains(candidate) { continue }
                for axis in Axis.allCases {
                    for offset in -reach...0 {
                        let move = Move(
                            dot: candidate,
                            line: Line(
                                origin: candidate.offset(along: axis, by: offset),
                                axis: axis, length: rules.lineLength))
                        if isLegal(move) { body(move) }
                    }
                }
            }
        }
    }
}
