import LatticeCore
import SwiftUI

/// A compact interactive board for the duel: renders a `Game` and reports the
/// chosen `Move` outward (the duel owns the engine, not a GameSession). Same
/// two-stage tap flow as the main board, trimmed — no camera/pan (duel boards
/// stay small and fast), auto-fit each move.
struct DuelBoardView: View {
    let game: Game
    let onCommit: (Move) -> Void

    @State private var tentative: Point?

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
    }

    private var candidates: [Move] {
        tentative.flatMap { movesByDot[$0] } ?? []
    }

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
        for candidate in candidates {
            stroke(candidate.line, .style(.tint), layout, in: context, dashed: true)
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
