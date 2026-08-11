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

    @ObservedObject var session: GameSession
    @ObservedObject var camera: BoardCamera
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var feedback: Feedback
    private let keyboardEnabled: Bool  // off while an overlay owns the keys

    // In-flight gesture deltas; committed (and clamped) into the camera on
    // gesture end.
    @State private var gestureZoom: CGFloat = 1
    @State private var gesturePan: CGSize = .zero
    @State private var dragMode: DragMode = .undecided
    @State var hot: HotTarget?

    public init(session: GameSession, camera: BoardCamera, keyboardEnabled: Bool = true) {
        self.session = session
        self.camera = camera
        self.keyboardEnabled = keyboardEnabled
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            // Keep the fitted board clear of the floating controls in the
            // bottom-trailing corner (at the fit zoom there's no panning to
            // reveal a covered dot) — see Layout.controlsClearInset.
            let bounds = Bounds(of: session.game.dots)
            let insets = Layout.controlsClearInset(bounds: bounds, in: size)
            let layout = Layout(fitting: bounds, in: size, insets: insets)
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
                            let next = target(at: toWorld(value.location), layout)
                            // A picker-style detent each time the scrub cycles
                            // to a DIFFERENT candidate line — makes choosing
                            // between overlapping lines tactile.
                            if next != hot, case .ghost = next {
                                feedback.selectChanged()
                            }
                            hot = next
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
        .background(BoardKeyboard(session: session, enabled: keyboardEnabled))
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
            feedback.committed()
        case .place(let p):
            session.place(p)
        case .cancelTentative:
            session.cancel()
        case nil:
            break
        }
    }

}

// MARK: Input

extension BoardView {

    private func handleTap(at location: CGPoint, _ layout: Layout) {
        // Candidate ghosts win first: they overlap the dot grid.
        if session.tentative != nil,
            let chosen = closestCandidate(to: location, layout)
        {
            session.commit(chosen)
            feedback.committed()
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
            let distance = layout.distance(from: location, toSegment: ghost.a, ghost.b)
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
    struct Ghost {
        let move: Move
        let a: CGPoint
        let b: CGPoint
    }

    func ghostGeometry(_ layout: Layout) -> [Ghost] {
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

}
