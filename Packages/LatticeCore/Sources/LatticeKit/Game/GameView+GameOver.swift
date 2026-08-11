import LatticeCore
import SwiftUI

/// The end-of-game panel: final score, share/save, and the versus winner row.
extension GameView {
    var gameOver: some View {
        HStack(spacing: 12) {
            Group {
                if let winner = session.winner {
                    playerChip(
                        winner,
                        label: Text(
                            "Player \(winner) wins — \(session.game.score) lines",
                            bundle: .module))
                } else if session.mode == .daily {
                    Text("Done for today — final score \(session.game.score)", bundle: .module)
                } else {
                    Text("No moves left — final score \(session.game.score)", bundle: .module)
                }
            }
            .font(.title3.weight(.semibold))
            if let image = shareImage {
                ShareLink(
                    item: image,
                    preview: SharePreview(
                        Text("Lattice Five — \(session.game.score)", bundle: .module),
                        image: image)
                )
            }
            Button {
                exportDocument = ShareCard.pngData(game: session.game, subtitle: cardSubtitle)
                    .map(PNGDocument.init)
                isExporting = exportDocument != nil
            } label: {
                Text("Save Image", bundle: .module)
            }
            .fileExporter(
                isPresented: $isExporting, document: exportDocument,
                contentType: .png, defaultFilename: exportFilename
            ) { _ in
                exportDocument = nil
            }
        }
    }

    func playerChip(_ player: Int, label: Text) -> some View {
        label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(PlayerStyle.color(for: player, scheme: colorScheme)))
    }
}
