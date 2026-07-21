import LatticeCore
import SwiftUI

/// The whole solitaire screen: score header, the board, game-over state.
public struct GameView: View {
    @StateObject private var session = GameSession()

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            header
            BoardView(session: session)
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
