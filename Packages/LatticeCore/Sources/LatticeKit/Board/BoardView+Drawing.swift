import LatticeCore
import SwiftUI

/// What the interactive board draws, in paint order. The primitives themselves
/// are shared with the duel/replay/share renderers — see BoardRendering.
extension BoardView {
    func draw(in context: GraphicsContext, _ layout: Layout) {
        drawDeadGaps(in: context, layout)
        drawPinpoints(in: context, layout)
        drawPlayedLines(in: context, layout)
        drawDots(in: context, layout)
        drawInteractiveState(in: context, layout)
    }

    /// The interactive accent: the system tint — except in pass-and-play, where
    /// it's the CURRENT player's colour, so the board says whose turn it is.
    func accent(_ opacity: Double = 1) -> GraphicsContext.Shading {
        guard session.mode == .passAndPlay else { return .style(.tint.opacity(opacity)) }
        return .color(
            PlayerStyle.color(for: session.playerToMove, scheme: colorScheme)
                .opacity(opacity))
    }

    /// Pass-and-play: a played line keeps its owner's colour.
    private func lineShading(forMoveAt index: Int, opacity: Double) -> GraphicsContext.Shading {
        guard session.mode == .passAndPlay else {
            return .style(.primary.opacity(opacity))
        }
        return .color(
            PlayerStyle.color(for: index % 2 + 1, scheme: colorScheme).opacity(opacity))
    }

    /// Thin, faint and SOLID regardless of span length — dashes rendered
    /// raggedly across the varying lengths. Under the real lines/dots, which
    /// legitimately cross these points.
    private func drawDeadGaps(in context: GraphicsContext, _ layout: Layout) {
        for span in session.deadGaps {
            context.stroke(
                line: span, .color(.red.opacity(0.4)),
                width: layout.lineWidth * 0.35, layout)
        }
    }

    private func drawPinpoints(in context: GraphicsContext, _ layout: Layout) {
        let dots = session.game.dots
        layout.forEachDrawnPoint { p in
            guard !dots.contains(p), p != session.tentative else { return }
            let (radius, shade) = Pinpoint.style(placeable: session.isPlaceable(p), layout)
            // A background casing so an underlying dead-gap line stops short of
            // the pinpoint (same idea as the filled dots' casing ring).
            context.fill(dot: p, radius: radius * 1.8, .style(.background), layout)
            context.fill(dot: p, radius: radius, .style(.primary.opacity(shade)), layout)
        }
    }

    private func drawPlayedLines(in context: GraphicsContext, _ layout: Layout) {
        let moves = session.game.moves
        context.strokePlayed(
            moves: moves, layout,
            shading: { lineShading(forMoveAt: $0, opacity: 0.75) },
            // The freshest line pops: full-strength owner colour in versus, the
            // accent otherwise.
            last: session.mode == .passAndPlay
                ? lineShading(forMoveAt: moves.count - 1, opacity: 1)
                : .style(.tint))
    }

    private func drawDots(in context: GraphicsContext, _ layout: Layout) {
        // Casings first, as a layer: a ring drawn per-dot would be painted over
        // by the next dot's casing where 5T's lines share endpoints.
        for dot in session.game.dots {
            context.fill(dot: dot, radius: layout.casingRadius, .style(.background), layout)
        }
        for dot in session.game.dots {
            context.fill(dot: dot, radius: layout.dotRadius, .style(.primary), layout)
        }
    }

    private func drawInteractiveState(in context: GraphicsContext, _ layout: Layout) {
        // Unlinked ("+") rules: free lines stand as faint offers even before a
        // dot is placed — placing any dot makes them selectable.
        if session.tentative == nil {
            for line in session.freeLines {
                let width = layout.lineWidth * 0.8
                context.stroke(
                    line: line, accent(0.3), width: width, dash: width * 2.5, layout)
            }
        }
        for ghost in ghostGeometry(layout) {
            var path = Path()
            path.move(to: ghost.a)
            path.addLine(to: ghost.b)
            let isHot = highlightedMove == ghost.move
            context.stroke(
                path, with: accent(isHot ? 0.9 : 0.5),
                style: StrokeStyle(
                    lineWidth: layout.lineWidth * (isHot ? 1.4 : 1), lineCap: .round,
                    dash: [layout.lineWidth * 2.5, layout.lineWidth * 2.5]))
        }
        if let tentative = session.tentative {
            context.fill(
                dot: tentative, radius: layout.casingRadius, .style(.background), layout)
            context.fill(dot: tentative, radius: layout.dotRadius * 1.25, accent(), layout)
        }
        drawFocusRing(in: context, layout)
        drawRejection(in: context, layout)
    }

    /// A tap that couldn't become a move: a red ring that fades where the finger
    /// landed. Answers "why did nothing happen?" at the point the player is
    /// looking, in the board's existing vocabulary (red = you can't) rather than
    /// with a message to read.
    private func drawRejection(in context: GraphicsContext, _ layout: Layout) {
        guard let point = rejectedPoint, rejectedFade > 0 else { return }
        context.strokeRing(
            around: point, .color(.red.opacity(0.7 * rejectedFade)), layout)
    }

    /// The hover/scrub preview, or — with no pointer — the roaming keyboard
    /// cursor. (The stage-two candidate highlight rides the ghost geometry
    /// above, so collinear candidates stay fanned apart.)
    private func drawFocusRing(in context: GraphicsContext, _ layout: Layout) {
        let focus: Point?
        switch hot {
        case .place(let p): focus = p
        case .cancelTentative: focus = session.tentative
        case .ghost: focus = nil
        case nil: focus = session.tentative == nil ? session.keyboardCursor : nil
        }
        guard let focus else { return }
        context.strokeRing(around: focus, accent(), layout)
    }

    /// The candidate to draw as hot: the mouse's scrub target, else the
    /// keyboard-selected candidate.
    private var highlightedMove: Move? {
        if case .ghost(let move) = hot { return move }
        guard hot == nil, session.tentative != nil,
            session.candidates.indices.contains(session.candidateIndex)
        else { return nil }
        return session.candidates[session.candidateIndex]
    }
}
