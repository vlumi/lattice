import LatticeCore
import SwiftUI

/// The shareable result card: the finished board rendered by the same
/// drawing vocabulary as the game (ink-on-paper — fixed light monochrome so
/// the card looks identical wherever it lands), plus the score line.
enum ShareCard {
    @MainActor
    static func render(game: Game, subtitle: String) -> Image? {
        let renderer = ImageRenderer(
            content: ShareCardView(game: game, subtitle: subtitle))
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return nil }
        return Image(cgImage, scale: 2, label: Text(verbatim: "Lattice Five"))
    }
}

private struct ShareCardView: View {
    let game: Game
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Text(verbatim: "Lattice Five")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.black.opacity(0.55))
            board
                .frame(width: 480, height: 480)
            Text(subtitle)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.black)
        }
        .padding(28)
        .background(.white)
    }

    private var board: some View {
        Canvas { context, size in
            let layout = Layout(fitting: Bounds(of: game.dots), in: size)
            for move in game.moves {
                guard let first = move.line.points.first, let last = move.line.points.last
                else { continue }
                var path = Path()
                path.move(to: layout.position(of: first))
                path.addLine(to: layout.position(of: last))
                context.stroke(
                    path, with: .color(.black.opacity(0.6)),
                    style: StrokeStyle(lineWidth: layout.lineWidth, lineCap: .round))
            }
            for dot in game.dots {
                let casing = layout.casingRadius
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: layout.position(of: dot).x - casing,
                            y: layout.position(of: dot).y - casing,
                            width: casing * 2, height: casing * 2)),
                    with: .color(.white))
                let radius = layout.dotRadius
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: layout.position(of: dot).x - radius,
                            y: layout.position(of: dot).y - radius,
                            width: radius * 2, height: radius * 2)),
                    with: .color(.black))
            }
        }
    }
}
