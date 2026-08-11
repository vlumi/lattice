import LatticeCore
import SwiftUI

/// Share-card image and PNG export naming for a finished game.
extension GameView {
    var cardSubtitle: String {
        session.dailyKey.map { key in
            String(localized: "Daily \(key) — score \(session.game.score)", bundle: .module)
        }
            ?? String(localized: "Score \(session.game.score)", bundle: .module)
    }

    var exportFilename: String {
        session.dailyKey.map { "lattice-daily-\($0)-\(session.game.score)" }
            ?? "lattice-\(session.game.score)"
    }

    var shareImage: Image? {
        ShareCard.render(game: session.game, subtitle: cardSubtitle)
    }
}
