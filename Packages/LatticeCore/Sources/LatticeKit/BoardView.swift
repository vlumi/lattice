import LatticeCore
import SwiftUI

/// The interactive board. Monochrome for committed state; the accent colour
/// marks everything not yet final (tentative dot, candidate ghosts) plus the
/// last-move highlight. Empty lattice positions render as faint pinpoints,
/// not a hairline grid — lines are reserved for played moves.
public struct BoardView: View {
    @ObservedObject private var session: GameSession

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        GeometryReader { geometry in
            let layout = Layout(fitting: Bounds(of: session.game.dots), in: geometry.size)
            Canvas { context, _ in
                draw(in: context, layout)
            }
            .gesture(
                SpatialTapGesture().onEnded { tap in
                    handleTap(at: tap.location, layout)
                })
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Drawing

    private func draw(in context: GraphicsContext, _ layout: Layout) {
        let dots = session.game.dots
        for x in (layout.bounds.minX - 1)...(layout.bounds.maxX + 1) {
            for y in (layout.bounds.minY - 1)...(layout.bounds.maxY + 1) {
                let p = Point(x, y)
                if dots.contains(p) || p == session.tentative { continue }
                fillDot(
                    p, radius: layout.pinpointRadius, .style(.primary.opacity(0.18)),
                    in: context, layout)
            }
        }

        let lastLine = session.game.moves.last?.line
        for move in session.game.moves where move.line != lastLine {
            strokeLine(
                move.line, .style(.primary.opacity(0.75)),
                width: layout.lineWidth, in: context, layout)
        }
        if let lastLine {
            strokeLine(
                lastLine, .style(.tint), width: layout.lineWidth, in: context, layout)
        }

        for dot in dots {
            fillDot(dot, radius: layout.dotRadius, .style(.primary), in: context, layout)
        }

        for candidate in session.candidates {
            strokeLine(
                candidate.line, .style(.tint.opacity(0.5)), width: layout.lineWidth,
                dashed: true, in: context, layout)
        }
        if let tentative = session.tentative {
            fillDot(
                tentative, radius: layout.dotRadius * 1.25, .style(.tint),
                in: context, layout)
        }
    }

    private func fillDot(
        _ p: Point, radius: CGFloat, _ shading: GraphicsContext.Shading,
        in context: GraphicsContext, _ layout: Layout
    ) {
        let center = layout.position(of: p)
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: shading)
    }

    private func strokeLine(
        _ line: Line, _ shading: GraphicsContext.Shading, width: CGFloat,
        dashed: Bool = false, in context: GraphicsContext, _ layout: Layout
    ) {
        guard let first = line.points.first, let last = line.points.last else { return }
        var path = Path()
        path.move(to: layout.position(of: first))
        path.addLine(to: layout.position(of: last))
        let style = StrokeStyle(
            lineWidth: width, lineCap: .round,
            dash: dashed ? [width * 2.5, width * 2.5] : [])
        context.stroke(path, with: shading, style: style)
    }

    // MARK: Input

    private func handleTap(at location: CGPoint, _ layout: Layout) {
        // Candidate ghosts win first: they overlap the dot grid.
        if session.tentative != nil,
            let chosen = closestCandidate(to: location, layout)
        {
            session.commit(chosen)
            return
        }
        guard let p = layout.point(near: location) else {
            session.cancel()
            return
        }
        if p == session.tentative {
            session.cancel()
        } else if session.isPlaceable(p) {
            session.place(p)
        } else {
            // Rejected in place; a shake/haptic is later polish.
            session.cancel()
        }
    }

    private func closestCandidate(to location: CGPoint, _ layout: Layout) -> Move? {
        var best: (move: Move, distance: CGFloat)?
        for candidate in session.candidates {
            guard let first = candidate.line.points.first,
                let last = candidate.line.points.last
            else { continue }
            let distance = distanceToSegment(
                location, layout.position(of: first), layout.position(of: last))
            if distance <= layout.cell * 0.4, distance < (best?.distance ?? .infinity) {
                best = (candidate, distance)
            }
        }
        return best?.move
    }

    private func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let lengthSquared = ab.x * ab.x + ab.y * ab.y
        let t = lengthSquared == 0 ? 0 : max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lengthSquared))
        let nearest = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        return hypot(p.x - nearest.x, p.y - nearest.y)
    }
}

struct Bounds {
    let minX, maxX, minY, maxY: Int

    init(of dots: Set<Point>) {
        guard let first = dots.first else {
            (minX, maxX, minY, maxY) = (0, 0, 0, 0)
            return
        }
        var (minX, maxX, minY, maxY) = (first.x, first.x, first.y, first.y)
        for dot in dots {
            minX = min(minX, dot.x)
            maxX = max(maxX, dot.x)
            minY = min(minY, dot.y)
            maxY = max(maxY, dot.y)
        }
        (self.minX, self.maxX, self.minY, self.maxY) = (minX, maxX, minY, maxY)
    }
}

struct Layout {
    let cell: CGFloat
    let originOffset: CGPoint
    let bounds: Bounds

    init(fitting bounds: Bounds, in size: CGSize) {
        // One empty cell of margin on every side.
        let columns = CGFloat(bounds.maxX - bounds.minX + 3)
        let rows = CGFloat(bounds.maxY - bounds.minY + 3)
        cell = min(size.width / columns, size.height / rows)
        let contentWidth = columns * cell
        let contentHeight = rows * cell
        originOffset = CGPoint(
            x: (size.width - contentWidth) / 2 + cell * 1.5,
            y: (size.height - contentHeight) / 2 + cell * 1.5)
        self.bounds = bounds
    }

    var dotRadius: CGFloat { cell * 0.18 }
    var pinpointRadius: CGFloat { cell * 0.05 }
    var lineWidth: CGFloat { cell * 0.1 }

    // Model y grows upward, screen y grows downward.
    func position(of p: Point) -> CGPoint {
        CGPoint(
            x: originOffset.x + CGFloat(p.x - bounds.minX) * cell,
            y: originOffset.y + CGFloat(bounds.maxY - p.y) * cell)
    }

    /// The lattice point within grabbing distance of a screen location, if
    /// any; inverse of `position(of:)`.
    func point(near location: CGPoint) -> Point? {
        guard cell > 0 else { return nil }
        let x = (location.x - originOffset.x) / cell + CGFloat(bounds.minX)
        let y = CGFloat(bounds.maxY) - (location.y - originOffset.y) / cell
        let candidate = Point(Int(x.rounded()), Int(y.rounded()))
        let center = position(of: candidate)
        guard hypot(location.x - center.x, location.y - center.y) <= cell * 0.4 else {
            return nil
        }
        return candidate
    }
}
