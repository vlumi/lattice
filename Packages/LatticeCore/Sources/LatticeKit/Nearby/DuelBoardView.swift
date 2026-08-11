import LatticeCore
import SwiftUI

/// A compact interactive board for the duel: renders a `Game` and reports the
/// chosen `Move` outward (the duel owns the engine, not a GameSession). Same
/// two-stage tap flow as the main board, trimmed — no camera/pan (duel boards
/// stay small and fast), auto-fit each move.
struct DuelBoardView: View {
    let game: Game
    /// Lock-step: input is barred while waiting for the round (the parent also
    /// dims the board). Keyboard bypasses SwiftUI `.disabled`, so gate here too.
    var waiting = false
    let onCommit: (Move) -> Void
    /// Esc with no tentative dot: leave the match (resign). With a tentative dot,
    /// Esc cancels the placement instead.
    var onExit: () -> Void = {}

    @State private var tentative: Point?
    @State private var keyboardCursor: Point?
    @State private var candidateIndex = 0

    private var movesByDot: [Point: [Move]] {
        var result: [Point: [Move]] = [:]
        for move in game.legalMoves() where move.line.points.contains(move.dot) {
            result[move.dot, default: []].append(move)
        }
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = Layout(fitting: Bounds(of: game.dots), in: geometry.size)
            Canvas { context, _ in draw(in: context, layout) }
                .gesture(
                    SpatialTapGesture().onEnded { tap in
                        handleTap(at: tap.location, layout)
                    })
        }
        .aspectRatio(1, contentMode: .fit)
        #if os(macOS)
        .background(KeyCatcher(onKey: handle))
        #endif
    }

    private var candidates: [Move] {
        tentative.flatMap { movesByDot[$0] } ?? []
    }

    #if os(macOS)
    // Keyboard play, mirroring the main board (BoardKeyboard): arrows roam a
    // cursor / cycle candidates, Enter/Space place then commit, Esc cancels.
    // No-op while the round barrier is up. Model y grows up, screen y down.
    private func handle(_ key: KeyCatcher.Key) {
        // Esc always available: cancel a pending placement, else leave the match.
        if key == .escape {
            if tentative != nil {
                tentative = nil
            } else {
                onExit()
            }
            return
        }
        guard !waiting else { return }
        switch key {
        case .up: moveCursor(0, 1)
        case .down: moveCursor(0, -1)
        case .left: horizontal(-1)
        case .right: horizontal(1)
        case .tab: cycleCandidate(1)
        case .enter, .space: activate()
        default: break
        }
    }

    private func moveCursor(_ dx: Int, _ dy: Int) {
        let bounds = Bounds(of: game.dots)
        let (minX, maxX) = (bounds.minX - 1, bounds.maxX + 1)
        let (minY, maxY) = (bounds.minY - 1, bounds.maxY + 1)
        let current = keyboardCursor ?? Point((minX + maxX) / 2, (minY + maxY) / 2)
        keyboardCursor = Point(
            min(max(current.x + dx, minX), maxX),
            min(max(current.y + dy, minY), maxY))
    }

    // Left/right roam while placing, but cycle candidate lines once tentative.
    private func horizontal(_ dir: Int) {
        if tentative == nil {
            moveCursor(dir, 0)
        } else {
            cycleCandidate(dir)
        }
    }

    private func cycleCandidate(_ step: Int) {
        let count = candidates.count
        guard tentative != nil, count > 0 else { return }
        candidateIndex = ((candidateIndex + step) % count + count) % count
    }

    private func activate() {
        if tentative == nil {
            guard let cursor = keyboardCursor, movesByDot[cursor] != nil else { return }
            tentative = cursor
            candidateIndex = 0
        } else if candidates.indices.contains(candidateIndex) {
            onCommit(candidates[candidateIndex])
            tentative = nil
            candidateIndex = 0
        }
    }
    #endif

    private func draw(in context: GraphicsContext, _ layout: Layout) {
        drawPinpoints(in: context, layout)
        for dot in game.dots {
            context.fill(dot: dot, radius: layout.dotRadius, .style(.primary), layout)
        }
        for move in game.moves {
            context.stroke(
                line: move.line, .style(.primary.opacity(0.7)),
                width: layout.lineWidth, layout)
        }
        for (index, candidate) in candidates.enumerated() {
            // The keyboard-highlighted candidate reads solid; the rest dashed.
            let selected = index == candidateIndex
            context.stroke(
                line: candidate.line,
                selected ? .style(.tint) : .style(.tint.opacity(0.5)),
                width: layout.lineWidth,
                dash: selected ? nil : layout.lineWidth * 2.5, layout)
        }
        if let tentative {
            context.fill(dot: tentative, radius: layout.dotRadius * 1.3, .style(.tint), layout)
        }
        // The keyboard cursor ring, only while roaming — once a dot is tentative
        // the enlarged tentative dot stands in for it.
        if let cursor = keyboardCursor, tentative == nil {
            context.strokeRing(around: cursor, .style(.tint), layout)
        }
    }

    private func drawPinpoints(in context: GraphicsContext, _ layout: Layout) {
        let dots = Set(game.dots)
        let placeable = Set(movesByDot.keys)
        layout.forEachDrawnPoint { p in
            guard !dots.contains(p), p != tentative else { return }
            let (radius, shade) = Pinpoint.style(placeable: placeable.contains(p), layout)
            context.fill(dot: p, radius: radius, .style(.primary.opacity(shade)), layout)
        }
    }

    private func handleTap(at location: CGPoint, _ layout: Layout) {
        // A candidate tap commits; otherwise place/cancel a tentative dot.
        if tentative != nil, let move = layout.nearestLine(to: location, among: candidates) {
            onCommit(move)
            tentative = nil
            return
        }
        guard let p = layout.point(near: location) else {
            tentative = nil
            return
        }
        if p == tentative {
            tentative = nil
        } else if movesByDot[p] != nil {
            tentative = p
        }
    }

}
