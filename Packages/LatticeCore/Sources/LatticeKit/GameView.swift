import LatticeCore
import SwiftUI

/// One game screen (free or daily): score header, the board, end state.
public struct GameView: View {
    @ObservedObject private var session: GameSession
    @StateObject private var camera = BoardCamera()

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            BoardView(session: session, camera: camera)
            if session.isOver {
                gameOver
            }
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Text("Score: \(session.game.score)", bundle: .module)
                .font(.headline.monospacedDigit())
            if session.mode == .daily, session.dailyStreak > 0 {
                Text("Streak: \(session.dailyStreak)", bundle: .module)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let best = session.best {
                Text("Best: \(best)", bundle: .module)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !camera.isIdentity {
                Button {
                    camera.reset()
                } label: {
                    Text("Fit", bundle: .module)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            if session.tentative != nil {
                Button {
                    session.cancel()
                } label: {
                    Text("Cancel", bundle: .module)
                }
                .keyboardShortcut(.cancelAction)
            }
            Button {
                session.undo()
            } label: {
                Text("Undo", bundle: .module)
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!session.undoAllowed)
            if session.mode == .free {
                Button {
                    session.newGame()
                    camera.reset()
                } label: {
                    Text("New Game", bundle: .module)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    private var gameOver: some View {
        HStack(spacing: 12) {
            Group {
                if session.mode == .daily {
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
                        image: image))
            }
        }
    }

    private var shareImage: Image? {
        let subtitle =
            session.dailyKey.map { key in
                String(
                    localized: "Daily \(key) — score \(session.game.score)", bundle: .module)
            }
            ?? String(localized: "Score \(session.game.score)", bundle: .module)
        return ShareCard.render(game: session.game, subtitle: subtitle)
    }
}

/// The app root: Free and Daily as tabs, each keeping its own session and
/// camera alive across switches.
public struct RootView: View {
    @StateObject private var freeSession = GameSession(mode: .free)
    @StateObject private var dailySession = GameSession(mode: .daily)

    public init() {}

    public var body: some View {
        TabView {
            GameView(session: freeSession)
                .tabItem { Text("Free", bundle: .module) }
            GameView(session: dailySession)
                .tabItem { Text("Daily", bundle: .module) }
        }
    }
}
