import LatticeCore
import SwiftUI

/// A tiny, accurate board rendering for the help diagrams — the same drawing
/// vocabulary as the real board (`BoardRendering`: cased dots, line weights, the
/// pinpoint coding), at caption scale. The diagrams *are* the game, not
/// illustrations of it: if the board's look changes, these follow.
///
/// Fixed to a small explicit window rather than fitting the dots, so a row of
/// diagrams shares one dot pitch and reads as one system.
struct BoardDiagram: View {
    /// How to read a line in a diagram.
    enum MarkKind {
        /// A line already on the board.
        case played
        /// The move being made — the accent, like a fresh line.
        case fresh
        /// Illegal: what you can't do, in red.
        case forbidden
        /// A standing possibility: dashed accent.
        case possible
    }

    /// A line to draw, and how to read it.
    struct Mark {
        let line: Line
        let kind: MarkKind

        init(_ line: Line, _ kind: MarkKind) {
            self.line = line
            self.kind = kind
        }
    }

    /// Dots on the board.
    var dots: Set<Point>
    /// Lines, in paint order.
    var marks: [Mark] = []
    /// Dots to ring, e.g. the new dot a move places.
    var highlight: Set<Point> = []
    /// The window to draw, in board coordinates.
    var bounds: Bounds
    var cell: CGFloat = 15

    var body: some View {
        Canvas { context, size in
            let layout = Layout(fitting: bounds, in: size)
            // Empty lattice, so the diagram reads as part of a board rather
            // than free-floating dots.
            layout.forEachDrawnPoint { p in
                guard !dots.contains(p) else { return }
                let (radius, shade) = Pinpoint.style(placeable: false, layout)
                context.fill(dot: p, radius: radius, .style(.primary.opacity(shade)), layout)
            }
            for mark in marks {
                switch mark.kind {
                case .played:
                    context.stroke(
                        line: mark.line, .style(.primary.opacity(0.75)),
                        width: layout.lineWidth, layout)
                case .fresh:
                    context.stroke(
                        line: mark.line, .style(.tint), width: layout.lineWidth * 1.2, layout)
                case .possible:
                    context.stroke(
                        line: mark.line, .style(.tint.opacity(0.45)),
                        width: layout.lineWidth * 0.8, dash: layout.lineWidth * 2, layout)
                case .forbidden:
                    context.stroke(
                        line: mark.line, .color(.red.opacity(0.55)),
                        width: layout.lineWidth * 0.9, dash: layout.lineWidth * 1.5, layout)
                }
            }
            for dot in dots {
                context.fill(casedDot: dot, .style(.primary), layout)
            }
            for p in highlight {
                context.strokeRing(around: p, .style(.tint), layout)
            }
        }
        .frame(
            width: CGFloat(bounds.maxX - bounds.minX + 3) * cell,
            height: CGFloat(bounds.maxY - bounds.minY + 3) * cell
        )
        .accessibilityHidden(true)  // the prose beside it carries the meaning
    }
}

extension BoardDiagram {
    /// A horizontal run of dots at `y`, from `x0` for `count` — the common
    /// building block for these diagrams.
    static func row(_ y: Int, from x0: Int, count: Int) -> Set<Point> {
        Set((0..<count).map { Point(x0 + $0, y) })
    }

    static func line(_ from: Point, _ axis: LatticeCore.Axis, _ length: Int = 5) -> Line {
        Line(origin: from, axis: axis, length: length)
    }
}
