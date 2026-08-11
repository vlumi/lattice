import ImageIO
import LatticeCore
import SwiftUI
import UniformTypeIdentifiers

/// The shareable result card: the finished board rendered by the same
/// drawing vocabulary as the game (ink-on-paper — fixed light monochrome so
/// the card looks identical wherever it lands), plus the score line.
enum ShareCard {
    @MainActor
    static func render(game: Game, subtitle: String) -> Image? {
        guard let cgImage = cgImage(game: game, subtitle: subtitle) else { return nil }
        return Image(cgImage, scale: 2, label: Text(verbatim: "Lattice Five"))
    }

    /// The same card as PNG bytes, for saving to a file.
    @MainActor
    static func pngData(game: Game, subtitle: String) -> Data? {
        guard let cgImage = cgImage(game: game, subtitle: subtitle) else { return nil }
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    @MainActor
    private static func cgImage(game: Game, subtitle: String) -> CGImage? {
        let renderer = ImageRenderer(
            content: ShareCardView(game: game, subtitle: subtitle))
        renderer.scale = 2
        return renderer.cgImage
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
                context.stroke(
                    line: move.line, .color(.black.opacity(0.6)),
                    width: layout.lineWidth, layout)
            }
            // Fixed ink-on-paper, not the theme's colours: the card must look
            // the same wherever it lands.
            for dot in game.dots {
                context.fill(dot: dot, radius: layout.casingRadius, .color(.white), layout)
                context.fill(dot: dot, radius: layout.dotRadius, .color(.black), layout)
            }
        }
    }
}
