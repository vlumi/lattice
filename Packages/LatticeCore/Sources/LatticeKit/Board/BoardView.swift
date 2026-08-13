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
        /// Sweeping empty board to feel where dots can go (haptics per point).
        case feel
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
    /// The lattice point a feel-sweep last ticked on, so the cue fires once per
    /// point crossed rather than once per touch event.
    @State private var feltPoint: Point?
    /// Long-press arms a feel-sweep on a zoomed board, where a plain drag pans.
    @State private var feelArmed = false
    /// Where a rejected tap landed, and how faded its marker is (1 → 0). A
    /// `Canvas` can't animate a subview, so the fade is animated state the draw
    /// reads.
    @State var rejectedPoint: Point?
    @State var rejectedFade: Double = 0

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
            // One drag gesture for tap / scrub-select / feel-sweep / camera
            // pan. Starting on a selectable target makes it a scrub: the
            // nearest target highlights as the finger moves, lifting selects
            // it. Over empty board it's a feel-sweep (see `mode(startingAt:)`).
            // Otherwise it pans; a sub-threshold pan is a tap.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragMode == .undecided {
                            dragMode = mode(startingAt: toWorld(value.startLocation), layout)
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
                        case .feel:
                            feel(at: toWorld(value.location), layout)
                        case .pan:
                            gesturePan = value.translation
                        case .undecided:
                            break
                        }
                    }
                    .onEnded { value in
                        switch dragMode {
                        // Lifting selects whatever is under the finger: a
                        // candidate line commits, a playable point becomes the
                        // tentative dot (freely cancellable).
                        case .scrub:
                            select(target(at: toWorld(value.location), layout))
                        case .feel:
                            // A sweep that never moved is just a tap — keep the
                            // tap semantics (tapping empty board cancels a
                            // tentative dot), which a bare `select` would drop.
                            if abs(value.translation.width) + abs(value.translation.height) < 6 {
                                handleTap(at: toWorld(value.location), layout)
                            } else {
                                select(target(at: toWorld(value.location), layout))
                            }
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
                        feltPoint = nil
                        feelArmed = false
                    }
            )
            // Zoomed in, a plain drag pans — hold first to sweep instead. The
            // arming press fires its own tick as the "you're in feel mode" cue.
            // It must not touch a drag that's already doing something: a careful
            // scrub between overlapping candidates easily exceeds this hold.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onEnded { _ in
                        guard camera.zoom > 1, session.tentative == nil,
                            dragMode == .pan, gesturePan == .zero
                        else { return }
                        feelArmed = true
                        dragMode = .feel
                        feedback.cursorMoved(.placeable)
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

    /// Which mode a drag starting here becomes. A selectable target scrubs. On
    /// a FITTED board there is nothing to pan (`clampPan` returns zero at zoom
    /// 1), so a drag over empty board is free to be a feel-sweep; zoomed in,
    /// panning wins unless a long press armed the sweep first.
    ///
    /// While a dot is tentative the drag is ALWAYS a scrub: the whole gesture
    /// belongs to choosing among that dot's candidate lines, including the part
    /// of it that passes over empty board between the ghosts.
    private func mode(startingAt location: CGPoint, _ layout: Layout) -> DragMode {
        if session.tentative != nil { return .scrub }
        if target(at: location, layout) != nil { return .scrub }
        return camera.zoom <= 1 || feelArmed ? .feel : .pan
    }

    /// Tick as the sweep crosses a point you can actually play, and stay silent
    /// everywhere else — a buzz means "a dot goes here". Discriminating three
    /// intensities under a moving finger asks too much; one unambiguous cue
    /// against silence reads instantly.
    private func feel(at location: CGPoint, _ layout: Layout) {
        let point = layout.point(near: location)
        guard point != feltPoint else { return }
        feltPoint = point
        guard let point, session.isPlaceable(point) else {
            hot = nil
            return
        }
        feedback.cursorMoved(.placeable)
        // Preview it the same way hover does — the sweep is visible as well as
        // tactile.
        hot = .place(point)
    }

    /// A tap that can't become a move: shake a ring where the finger landed, so
    /// the "why nothing happened" is answered where the player is looking rather
    /// than in a message they have to read.
    private func reject(_ p: Point) {
        // Don't nag about tapping an existing dot — that's self-evident. The
        // teachable case is empty space no line can reach.
        guard !session.game.dots.contains(p) else { return }
        feedback.rejected()
        rejectedPoint = p
        rejectedFade = 1
        withAnimation(.easeOut(duration: 0.45)) { rejectedFade = 0 }
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
            reject(p)
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
