import LatticeCore
import SwiftUI

/// The interactive board. Monochrome for committed state; the accent colour
/// marks everything not yet final (tentative dot, candidate ghosts) plus the
/// last-move highlight. Empty lattice positions render as faint pinpoints,
/// not a hairline grid — lines are reserved for played moves.
public struct BoardView: View {
    /// What hover or a selection scrub is currently pointing at — previewed
    /// in accent, chosen on click/lift.
    enum HotTarget: Equatable {
        case place(Point)
        case ghost(Move)
        case cancelTentative
    }

    private enum DragMode {
        case undecided
        case scrub
        case pan
    }

    @ObservedObject private var session: GameSession
    @ObservedObject private var camera: BoardCamera

    // In-flight gesture deltas; committed (and clamped) into the camera on
    // gesture end.
    @State private var gestureZoom: CGFloat = 1
    @State private var gesturePan: CGSize = .zero
    @State private var dragMode: DragMode = .undecided
    @State private var hot: HotTarget?

    public init(session: GameSession, camera: BoardCamera) {
        self.session = session
        self.camera = camera
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let layout = Layout(fitting: Bounds(of: session.game.dots), in: size)
            let zoom = BoardCamera.clampZoom(camera.zoom * gestureZoom)
            let pan = BoardCamera.clampPan(
                CGSize(
                    width: camera.pan.width + gesturePan.width,
                    height: camera.pan.height + gesturePan.height),
                zoom: zoom, in: size)
            let toWorld: (CGPoint) -> CGPoint = { location in
                CGPoint(
                    x: (location.x - size.width / 2 - pan.width) / zoom + size.width / 2,
                    y: (location.y - size.height / 2 - pan.height) / zoom + size.height / 2)
            }
            Canvas { context, _ in
                context.translateBy(
                    x: size.width / 2 + pan.width, y: size.height / 2 + pan.height)
                context.scaleBy(x: zoom, y: zoom)
                context.translateBy(x: -size.width / 2, y: -size.height / 2)
                draw(in: context, layout)
            }
            // Pointer hover (Mac, iPad pointer/trackpad): preview the target
            // under the cursor. No-op on plain touch.
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hot = target(at: toWorld(location), layout)
                case .ended:
                    hot = nil
                }
            }
            // One drag gesture for tap / scrub-select / camera pan. Starting
            // on a selectable target makes it a scrub: the nearest target
            // highlights as the finger moves, lifting selects it. Starting
            // anywhere else pans; a sub-threshold pan is a tap.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragMode == .undecided {
                            dragMode =
                                target(at: toWorld(value.startLocation), layout) != nil
                                ? .scrub : .pan
                        }
                        switch dragMode {
                        case .scrub:
                            hot = target(at: toWorld(value.location), layout)
                        case .pan:
                            gesturePan = value.translation
                        case .undecided:
                            break
                        }
                    }
                    .onEnded { value in
                        switch dragMode {
                        case .scrub:
                            select(target(at: toWorld(value.location), layout))
                        case .pan:
                            gesturePan = .zero
                            if abs(value.translation.width) + abs(value.translation.height) < 6 {
                                handleTap(at: toWorld(value.location), layout)
                            } else {
                                camera.apply(
                                    zoomDelta: 1, panDelta: value.translation, in: size)
                            }
                        case .undecided:
                            break
                        }
                        dragMode = .undecided
                        hot = nil
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { gestureZoom = $0 }
                    .onEnded { value in
                        gestureZoom = 1
                        camera.apply(zoomDelta: value, panDelta: .zero, in: size)
                    })
        }
        .clipped()
    }

    // MARK: Targets

    /// The selectable thing near a world location: candidate ghosts first
    /// (they overlay the grid), then the tentative dot (cancel), then any
    /// placeable point.
    private func target(at location: CGPoint, _ layout: Layout) -> HotTarget? {
        if session.tentative != nil, let ghost = closestCandidate(to: location, layout) {
            return .ghost(ghost)
        }
        guard let p = layout.point(near: location) else { return nil }
        if p == session.tentative { return .cancelTentative }
        if session.isPlaceable(p) { return .place(p) }
        return nil
    }

    private func select(_ target: HotTarget?) {
        switch target {
        case .ghost(let move):
            session.commit(move)
        case .place(let p):
            session.place(p)
        case .cancelTentative:
            session.cancel()
        case nil:
            break
        }
    }

    // MARK: Drawing

    private func draw(in context: GraphicsContext, _ layout: Layout) {
        drawPinpoints(in: context, layout)
        drawPlayedLines(in: context, layout)
        drawDots(in: context, layout)
        drawInteractiveState(in: context, layout)
    }

    // Settled-vs-open grayscale coding: placeable points (a legal move
    // exists) get a clearly visible pinpoint, all other empty points fade to
    // near-nothing. Deliberately NOT a uniform lattice — a regular grid of
    // faint marks under bright dots triggers the scintillating-grid illusion
    // (phantom dark cores in the dots).
    private func drawPinpoints(in context: GraphicsContext, _ layout: Layout) {
        let dots = session.game.dots
        for x in (layout.bounds.minX - 1)...(layout.bounds.maxX + 1) {
            for y in (layout.bounds.minY - 1)...(layout.bounds.maxY + 1) {
                let p = Point(x, y)
                if dots.contains(p) || p == session.tentative { continue }
                if session.isPlaceable(p) {
                    fillDot(
                        p, radius: layout.openPointRadius, .style(.primary.opacity(0.45)),
                        in: context, layout)
                } else {
                    fillDot(
                        p, radius: layout.pinpointRadius, .style(.primary.opacity(0.08)),
                        in: context, layout)
                }
            }
        }
    }

    private func drawPlayedLines(in context: GraphicsContext, _ layout: Layout) {
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
    }

    // Casing: a background-colour ring under each dot separates it from
    // crossing lines — kills the bright-intersection clustering that feeds
    // the illusion, and makes 5T's shared-endpoint dots readable.
    private func drawDots(in context: GraphicsContext, _ layout: Layout) {
        let dots = session.game.dots
        for dot in dots {
            fillDot(dot, radius: layout.casingRadius, .style(.background), in: context, layout)
        }
        for dot in dots {
            fillDot(dot, radius: layout.dotRadius, .style(.primary), in: context, layout)
        }
    }

    private func drawInteractiveState(in context: GraphicsContext, _ layout: Layout) {
        for ghost in ghostGeometry(layout) {
            var path = Path()
            path.move(to: ghost.a)
            path.addLine(to: ghost.b)
            let isHot = hot == .ghost(ghost.move)
            context.stroke(
                path, with: .style(.tint.opacity(isHot ? 0.9 : 0.5)),
                style: StrokeStyle(
                    lineWidth: layout.lineWidth * (isHot ? 1.4 : 1), lineCap: .round,
                    dash: [layout.lineWidth * 2.5, layout.lineWidth * 2.5]))
        }
        if let tentative = session.tentative {
            fillDot(
                tentative, radius: layout.casingRadius, .style(.background), in: context, layout)
            fillDot(
                tentative, radius: layout.dotRadius * 1.25, .style(.tint),
                in: context, layout)
        }
        // Hover / scrub preview: an accent ring on the would-be selection.
        switch hot {
        case .place(let p):
            strokeRing(around: p, in: context, layout)
        case .cancelTentative:
            if let tentative = session.tentative {
                strokeRing(around: tentative, in: context, layout)
            }
        case .ghost, nil:
            break
        }
    }

    private func strokeRing(around p: Point, in context: GraphicsContext, _ layout: Layout) {
        let center = layout.position(of: p)
        let radius = layout.dotRadius * 1.7
        context.stroke(
            Path(
                ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2)),
            with: .style(.tint),
            style: StrokeStyle(lineWidth: layout.lineWidth * 0.8))
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
        for ghost in ghostGeometry(layout) {
            let distance = distanceToSegment(location, ghost.a, ghost.b)
            if distance <= layout.cell * 0.4, distance < (best?.distance ?? .infinity) {
                best = (ghost.move, distance)
            }
        }
        return best?.move
    }

    /// Screen geometry of the candidate ghosts. Collinear candidates
    /// overlapping lengthwise are indistinguishable drawn in place, so each
    /// axis's candidates fan out side by side with a small perpendicular
    /// offset — visually separate and individually tappable. A single
    /// candidate on an axis stays exactly on-axis.
    private struct Ghost {
        let move: Move
        let a: CGPoint
        let b: CGPoint
    }

    private func ghostGeometry(_ layout: Layout) -> [Ghost] {
        var result: [Ghost] = []
        for axis in LatticeCore.Axis.allCases {
            let step = axis.step
            func rank(_ move: Move) -> Int {
                step.dx * move.line.origin.x + step.dy * move.line.origin.y
            }
            let group = session.candidates
                .filter { $0.line.axis == axis }
                .sorted { rank($0) < rank($1) }
            for (index, move) in group.enumerated() {
                guard let first = move.line.points.first, let last = move.line.points.last
                else { continue }
                let a = layout.position(of: first)
                let b = layout.position(of: last)
                let length = hypot(b.x - a.x, b.y - a.y)
                let shift = (CGFloat(index) - CGFloat(group.count - 1) / 2) * layout.cell * 0.2
                let perp = CGPoint(
                    x: -(b.y - a.y) / length * shift, y: (b.x - a.x) / length * shift)
                result.append(
                    Ghost(
                        move: move, a: CGPoint(x: a.x + perp.x, y: a.y + perp.y),
                        b: CGPoint(x: b.x + perp.x, y: b.y + perp.y)
                    ))
            }
        }
        return result
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
    var casingRadius: CGFloat { cell * 0.28 }
    var pinpointRadius: CGFloat { cell * 0.05 }
    var openPointRadius: CGFloat { cell * 0.09 }
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
