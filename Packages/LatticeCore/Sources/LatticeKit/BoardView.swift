import LatticeCore
import SwiftUI

/// Renders a dot set on the lattice — monochrome, theme-aware via the
/// environment foreground color. Scaffold scope: draws the dots; interaction
/// and drawn lines arrive with the engine.
public struct BoardView: View {
    private let dots: Set<Point>

    public init(dots: Set<Point> = StartingPattern.standardCross) {
        self.dots = dots
    }

    public var body: some View {
        Canvas { context, size in
            guard let bounds = Bounds(of: dots) else { return }
            let layout = Layout(fitting: bounds, in: size)
            // Empty lattice positions as faint pinpoints (not a hairline
            // grid — lines are reserved for played moves). Rendered over the
            // content bounds + margin only, so the void beyond stays clean.
            for x in (bounds.minX - 1)...(bounds.maxX + 1) {
                for y in (bounds.minY - 1)...(bounds.maxY + 1) {
                    let p = Point(x, y)
                    if dots.contains(p) { continue }
                    fill(p, radius: layout.pinpointRadius, opacity: 0.18, in: context, layout)
                }
            }
            for dot in dots {
                fill(dot, radius: layout.dotRadius, opacity: 1, in: context, layout)
            }
        }
    }

    private func fill(
        _ p: Point, radius: CGFloat, opacity: Double,
        in context: GraphicsContext, _ layout: Layout
    ) {
        let center = layout.position(of: p)
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .style(.primary.opacity(opacity)))
    }
}

private struct Bounds {
    let minX, maxX, minY, maxY: Int

    init?(of dots: Set<Point>) {
        guard let first = dots.first else { return nil }
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

private struct Layout {
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

    // Model y grows upward, screen y grows downward.
    func position(of p: Point) -> CGPoint {
        CGPoint(
            x: originOffset.x + CGFloat(p.x - bounds.minX) * cell,
            y: originOffset.y + CGFloat(bounds.maxY - p.y) * cell)
    }
}
