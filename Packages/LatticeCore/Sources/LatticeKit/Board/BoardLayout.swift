import LatticeCore
import SwiftUI

/// Board geometry: content bounds and the fit-to-content layout shared by
/// the interactive board, the replay render, and the share card.
struct Bounds {
    let minX, maxX, minY, maxY: Int

    /// An explicit window — the help diagrams pin their own extent so a row of
    /// them shares one dot pitch instead of each fitting its own dots.
    init(minX: Int, maxX: Int, minY: Int, maxY: Int) {
        (self.minX, self.maxX, self.minY, self.maxY) = (minX, maxX, minY, maxY)
    }

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

    /// `insets` reserve edges of `size` that the fitted board must not enter —
    /// used to keep content clear of the floating board controls, since at the
    /// fit zoom there's no panning to reveal what they'd cover. Defaults to none
    /// (replay/share-card/duel render edge-to-edge).
    init(fitting bounds: Bounds, in size: CGSize, insets: EdgeInsets = EdgeInsets()) {
        let available = CGSize(
            width: max(1, size.width - insets.leading - insets.trailing),
            height: max(1, size.height - insets.top - insets.bottom))
        // One empty cell of margin on every side.
        let columns = CGFloat(bounds.maxX - bounds.minX + 3)
        let rows = CGFloat(bounds.maxY - bounds.minY + 3)
        cell = min(available.width / columns, available.height / rows)
        let contentWidth = columns * cell
        let contentHeight = rows * cell
        // Centre within the inset area, then shift by the leading/top inset.
        originOffset = CGPoint(
            x: insets.leading + (available.width - contentWidth) / 2 + cell * 1.5,
            y: insets.top + (available.height - contentHeight) / 2 + cell * 1.5)
        self.bounds = bounds
    }

    /// The fitted content's on-screen extent (dots + the 1.5-cell edge margin),
    /// used to measure how much slack a fit leaves on each axis.
    var contentWidth: CGFloat { CGFloat(bounds.maxX - bounds.minX + 3) * cell }
    var contentHeight: CGFloat { CGFloat(bounds.maxY - bounds.minY + 3) * cell }

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

    /// The bottom-trailing area the floating board controls occupy, which the
    /// fit must keep clear. Height covers the tallest the stack gets — help and
    /// Undo always, Fit once the camera moves (see BoardControls) — at 44pt a
    /// button, 10 apart, in 12 of padding. Width is one button plus padding.
    static let controlsCorner = CGSize(width: 68, height: 44 * 3 + 10 * 2 + 12 * 2)

    /// An inset that keeps the fitted board clear of the floating controls
    /// (bottom-trailing) at the fit zoom, where there's no panning to reveal a
    /// covered dot. Preference:
    /// 1. If an axis has enough slack to swallow the whole corner, reserve it
    ///    fully — the board just shifts within its margin, no shrink. Pick the
    ///    roomier axis (bottom for a wide Mac window, trailing for a tall phone).
    /// 2. If NEITHER axis has room (a near-square window), reserve the full
    ///    corner on both axes and accept a small shrink — a covered dot is worse.
    /// No-op when the content already clears the corner.
    static func controlsClearInset(bounds: Bounds, in size: CGSize) -> EdgeInsets {
        let plain = Layout(fitting: bounds, in: size)
        let right = plain.position(of: Point(bounds.maxX, bounds.minY)).x + plain.cell
        let bottom = plain.position(of: Point(bounds.minX, bounds.minY)).y + plain.cell
        let cornerLeft = size.width - controlsCorner.width
        let cornerTop = size.height - controlsCorner.height
        guard right > cornerLeft, bottom > cornerTop else { return EdgeInsets() }
        let horizontalSlack = size.width - plain.contentWidth
        let verticalSlack = size.height - plain.contentHeight
        let fitsVertically = verticalSlack >= controlsCorner.height
        let fitsHorizontally = horizontalSlack >= controlsCorner.width
        if fitsVertically, verticalSlack >= horizontalSlack {
            return EdgeInsets(top: 0, leading: 0, bottom: controlsCorner.height, trailing: 0)
        }
        if fitsHorizontally {
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: controlsCorner.width)
        }
        if fitsVertically {
            return EdgeInsets(top: 0, leading: 0, bottom: controlsCorner.height, trailing: 0)
        }
        // Neither fits — reserve the full corner on both axes (small shrink).
        return EdgeInsets(
            top: 0, leading: 0, bottom: controlsCorner.height, trailing: controlsCorner.width)
    }
}
