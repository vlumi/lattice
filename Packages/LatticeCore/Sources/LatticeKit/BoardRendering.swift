import LatticeCore
import SwiftUI

/// The board's drawing vocabulary, shared by every renderer: the interactive
/// board, the duel board, the replay, and the share card. They differ in what
/// they draw and in what colours — not in how a dot or a line is put on screen.
extension GraphicsContext {
    func fill(dot p: Point, radius: CGFloat, _ shading: Shading, _ layout: Layout) {
        let center = layout.position(of: p)
        fill(
            Path(
                ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2)),
            with: shading)
    }

    func stroke(
        line: Line, _ shading: Shading, width: CGFloat, dash: CGFloat? = nil,
        _ layout: Layout
    ) {
        guard let first = line.points.first, let last = line.points.last else { return }
        var path = Path()
        path.move(to: layout.position(of: first))
        path.addLine(to: layout.position(of: last))
        stroke(
            path, with: shading,
            style: StrokeStyle(
                lineWidth: width, lineCap: .round,
                dash: dash.map { [$0, $0] } ?? []))
    }

    /// A dot with its background casing ring — the ring separates the dot from
    /// crossing lines, which is what keeps 5T's shared endpoints readable.
    func fill(casedDot p: Point, _ shading: Shading, _ layout: Layout) {
        fill(dot: p, radius: layout.casingRadius, .style(.background), layout)
        fill(dot: p, radius: layout.dotRadius, shading, layout)
    }

    /// The hover / scrub / keyboard-cursor focus ring.
    func strokeRing(around p: Point, _ shading: Shading, _ layout: Layout) {
        let center = layout.position(of: p)
        let radius = layout.dotRadius * 1.7
        stroke(
            Path(
                ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2)),
            with: shading,
            style: StrokeStyle(lineWidth: layout.lineWidth * 0.8))
    }

    /// Every played line, the freshest one emphasised. `shading` maps a move
    /// index to its colour so pass-and-play can give each player their own.
    func strokePlayed(
        moves: [Move], _ layout: Layout,
        shading: (Int) -> Shading, last: Shading
    ) {
        for (index, move) in moves.enumerated() where index != moves.count - 1 {
            stroke(line: move.line, shading(index), width: layout.lineWidth, layout)
        }
        if let move = moves.last {
            stroke(line: move.line, last, width: layout.lineWidth * 1.2, layout)
        }
    }
}

/// Settled-vs-open grayscale coding for the empty lattice: a point with a legal
/// move gets a clearly visible pinpoint, every other empty point fades to
/// near-nothing. Deliberately NOT a uniform lattice — a regular grid of faint
/// marks under bright dots triggers the scintillating-grid illusion (phantom
/// dark cores in the dots).
enum Pinpoint {
    static let openShade = 0.45
    static let settledShade = 0.08

    /// Radius and shade opacity for an empty lattice point.
    static func style(placeable: Bool, _ layout: Layout) -> (radius: CGFloat, shade: Double) {
        placeable
            ? (layout.openPointRadius, openShade)
            : (layout.pinpointRadius, settledShade)
    }
}

extension Layout {
    /// The drawn area: the dots' bounds plus the one-cell margin the fit
    /// reserves. Every renderer's empty-lattice pass walks exactly this.
    /// A closure rather than a collection — this runs per frame, so it must not
    /// allocate.
    func forEachDrawnPoint(_ body: (Point) -> Void) {
        for x in (bounds.minX - 1)...(bounds.maxX + 1) {
            for y in (bounds.minY - 1)...(bounds.maxY + 1) {
                body(Point(x, y))
            }
        }
    }

    /// The candidate line nearest a tap, within grabbing distance — how both
    /// boards resolve a tap that landed on overlapping ghosts.
    func nearestLine(to location: CGPoint, among moves: [Move]) -> Move? {
        var best: (Move, CGFloat)?
        for move in moves {
            guard let first = move.line.points.first, let last = move.line.points.last
            else { continue }
            let d = distance(
                from: location, toSegment: position(of: first), position(of: last))
            if d <= cell * 0.4, d < (best?.1 ?? .infinity) { best = (move, d) }
        }
        return best?.0
    }

    func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let len2 = ab.x * ab.x + ab.y * ab.y
        let t = len2 == 0 ? 0 : max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / len2))
        let n = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        return hypot(p.x - n.x, p.y - n.y)
    }
}
