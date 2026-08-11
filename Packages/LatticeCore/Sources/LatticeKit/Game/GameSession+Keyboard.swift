import LatticeCore

/// Keyboard play: the roaming cursor and candidate cycling. Mirrors the
/// pointer flow — place a dot, then choose among the lines it enables.
extension GameSession {

    /// Move the roaming cursor by one cell, clamped to the current dots'
    /// bounding box plus a one-cell margin — a placeable point is always
    /// adjacent to an existing dot, so that margin reaches every legal move
    /// while never wandering into open space. First arrow press seeds the
    /// cursor near the board's centre.
    public func moveCursor(dx: Int, dy: Int) {
        let bounds = Bounds(of: game.dots)
        let (minX, maxX) = (bounds.minX - 1, bounds.maxX + 1)
        let (minY, maxY) = (bounds.minY - 1, bounds.maxY + 1)
        let current = keyboardCursor ?? Point((minX + maxX) / 2, (minY + maxY) / 2)
        keyboardCursor = Point(
            min(max(current.x + dx, minX), maxX),
            min(max(current.y + dy, minY), maxY))
    }

    /// Enter/Space on the cursor: place a tentative dot if it's playable
    /// (stage one). No-op on a non-placeable point.
    public func cursorSelect() {
        guard let cursor = keyboardCursor else { return }
        place(cursor)
    }

    /// Cycle the highlighted candidate line while a dot is tentative (stage
    /// two); wraps. No-op with no tentative or no candidates.
    public func cycleCandidate(by step: Int) {
        let count = candidates.count
        guard tentative != nil, count > 0 else { return }
        candidateIndex = ((candidateIndex + step) % count + count) % count
    }

    /// Commit the currently-highlighted candidate line (stage two).
    public func commitHighlighted() {
        guard tentative != nil, candidates.indices.contains(candidateIndex) else { return }
        commit(candidates[candidateIndex])
    }

    /// Free and pass-and-play — the daily is one attempt per day. Passing
    /// rules switches variant (with its standard start); omitting keeps the
    /// current rules. A seeded game's New Game replays the same seed —
    /// retrying the same challenge, like the classic cross.
}
