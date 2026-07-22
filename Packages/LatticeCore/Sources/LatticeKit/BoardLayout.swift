import LatticeCore
import SwiftUI

/// Board geometry: content bounds and the fit-to-content layout shared by
/// the interactive board, the replay render, and the share card.
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
