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
            let center = layout.position(of: dot)
            let r = layout.dotRadius
            context.fill(
                Path(
                    ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ),
                with: .style(.primary))
        }
        for move in game.moves {
            stroke(move.line, .style(.primary.opacity(0.7)), layout, in: context)
        }
        for (index, candidate) in candidates.enumerated() {
            // The keyboard-highlighted candidate reads solid; the rest dashed.
            let selected = index == candidateIndex
            let shading: GraphicsContext.Shading =
                selected ? .style(.tint) : .style(.tint.opacity(0.5))
            stroke(candidate.line, shading, layout, in: context, dashed: !selected)
        }
        if let tentative {
            let center = layout.position(of: tentative)
            let r = layout.dotRadius * 1.3
            context.fill(
                Path(
                    ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ),
                with: .style(.tint))
        }
        drawCursor(in: context, layout)
    }

    // The keyboard cursor ring (only while roaming — once a dot is tentative the
    // enlarged tentative dot stands in for it).
    private func drawCursor(in context: GraphicsContext, _ layout: Layout) {
        guard let cursor = keyboardCursor, tentative == nil else { return }
        let center = layout.position(of: cursor)
        let r = layout.dotRadius * 1.6
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
            with: .style(.tint), lineWidth: layout.lineWidth * 0.6)
    }

    // The playable empty positions, so you can see where a move can go —
    // placeable points a clear pinpoint, the rest of the lattice near-nothing
    // (same coding as the main board).
    private func drawPinpoints(in context: GraphicsContext, _ layout: Layout) {
        let dots = Set(game.dots)
        let placeable = Set(movesByDot.keys)
        for x in (layout.bounds.minX - 1)...(layout.bounds.maxX + 1) {
            for y in (layout.bounds.minY - 1)...(layout.bounds.maxY + 1) {
                let p = Point(x, y)
                if dots.contains(p) || p == tentative { continue }
                let (radius, opacity) =
                    placeable.contains(p)
                    ? (layout.openPointRadius, 0.45) : (layout.pinpointRadius, 0.08)
                let center = layout.position(of: p)
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: center.x - radius, y: center.y - radius,
                            width: radius * 2, height: radius * 2)),
                    with: .style(.primary.opacity(opacity)))
            }
        }
    }

    private func stroke(
        _ line: Line, _ shading: GraphicsContext.Shading, _ layout: Layout,
        in context: GraphicsContext, dashed: Bool = false
    ) {
        guard let first = line.points.first, let last = line.points.last else { return }
        var path = Path()
        path.move(to: layout.position(of: first))
        path.addLine(to: layout.position(of: last))
        context.stroke(
            path, with: shading,
            style: StrokeStyle(
                lineWidth: layout.lineWidth, lineCap: .round,
                dash: dashed ? [layout.lineWidth * 2.5, layout.lineWidth * 2.5] : []))
    }

    private func handleTap(at location: CGPoint, _ layout: Layout) {
        // A candidate tap commits; otherwise place/cancel a tentative dot.
        if tentative != nil, let move = nearestCandidate(to: location, layout) {
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

    private func nearestCandidate(to location: CGPoint, _ layout: Layout) -> Move? {
        var best: (Move, CGFloat)?
        for candidate in candidates {
            guard let first = candidate.line.points.first, let last = candidate.line.points.last
            else { continue }
            let d = distanceToSegment(
                location, layout.position(of: first), layout.position(of: last))
            if d <= layout.cell * 0.4, d < (best?.1 ?? .infinity) { best = (candidate, d) }
        }
        return best?.0
    }

    private func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let len2 = ab.x * ab.x + ab.y * ab.y
        let t = len2 == 0 ? 0 : max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / len2))
        let n = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        return hypot(p.x - n.x, p.y - n.y)
    }
}
