import LatticeCore
import SwiftUI

/// The whole solitaire screen: score header, the board, game-over state.
public struct GameView: View {
    @StateObject private var session = GameSession()
    @StateObject private var camera = BoardCamera()

    public init() {}

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
            .disabled(session.game.moves.isEmpty)
            Button {
                session.newGame()
                camera.reset()
            } label: {
                Text("New Game", bundle: .module)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    private var gameOver: some View {
        Text("No moves left — final score \(session.game.score)", bundle: .module)
            .font(.title3.weight(.semibold))
    }
}
