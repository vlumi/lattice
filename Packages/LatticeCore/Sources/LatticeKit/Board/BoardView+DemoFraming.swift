import SwiftUI

extension BoardView {
    /// Screenshot staging (`-demo-pending`): zoom the untouched camera to fit
    /// the pending dot's candidate lines with some board around them, centred.
    func frameDemoPending(in size: CGSize, _ layout: Layout) {
        guard DemoMode.stagesPendingDot, camera.isIdentity, size.width > 0,
            let dot = session.tentative
        else { return }
        let points = [dot] + session.candidates.flatMap(\.line.points)
        let xs = points.map { layout.position(of: $0).x }
        let ys = points.map { layout.position(of: $0).y }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max()
        else { return }
        let margin = layout.cell * 2
        let zoom = min(
            size.width / (maxX - minX + 2 * margin),
            size.height / (maxY - minY + 2 * margin),
            2.5)
        guard zoom > 1 else { return }
        let pan = CGSize(
            width: (size.width / 2 - (minX + maxX) / 2) * zoom,
            height: (size.height / 2 - (minY + maxY) / 2) * zoom)
        camera.apply(zoomDelta: zoom, panDelta: pan, in: size)
    }
}
