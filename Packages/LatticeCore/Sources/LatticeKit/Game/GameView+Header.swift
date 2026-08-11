import LatticeCore
import SwiftUI

/// The board screen's top bar: score, variant/challenge chips, and the
/// New Game / Restart / share controls.
extension GameView {
    var header: some View {
        HStack(spacing: 16) {
            Text("Score: \(session.game.score)", bundle: .module)
                .font(.headline.monospacedDigit())
            if session.mode == .passAndPlay {
                // The turn chip: the current player's colour, filled — the
                // same colour the board's interactive accent and their drawn
                // lines wear.
                if !session.isOver {
                    playerChip(
                        session.playerToMove,
                        label: Text("Player \(session.playerToMove) to move", bundle: .module))
                }
                // Live same-room duel — the one online mode. Distinct from
                // pass-and-play's shared device; a match is its own event.
                Button {
                    isShowingNearby = true
                } label: {
                    Image(systemName: "person.line.dotted.person.fill")
                }
                .accessibilityLabel(Text("Nearby", bundle: .module))
            } else if session.mode == .daily, session.dailyStreak > 0 {
                Text(
                    "Streak: \(session.dailyStreak) (best \(session.dailyLongestStreak))",
                    bundle: .module
                )
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            } else if let best = session.best {
                Text("Best: \(best)", bundle: .module)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let code = session.seedCode, let seed = session.seed {
                Button {
                    isShowingChallenge = true
                } label: {
                    // Show the code beside the icon when it fits; on a tight
                    // header (iPhone SE) fall back to the icon alone so the row
                    // doesn't wrap — the code still shows in the popover.
                    ViewThatFits {
                        challengeLabel(code: code, iconOnly: false)
                        challengeLabel(code: code, iconOnly: true)
                    }
                }
                .accessibilityLabel(Text("Share challenge", bundle: .module))
                // Popover on Mac/iPad; adapts to a sheet on iPhone (the
                // compact-popover modifier needs iOS 16.4; floor is 16.0).
                .popover(isPresented: $isShowingChallenge) {
                    ChallengeShareView(
                        code: code, url: ChallengeLink.url(for: seed),
                        dismiss: { isShowingChallenge = false }
                    )
                    .padding()
                    .presentationDetents([.medium])
                }
            }
            Spacer()
            // Always present (hidden when there's nothing to cancel) so the
            // header's size stays constant — otherwise the button appearing
            // reflowed the row and nudged the board's fitted size (a wobble).
            Button {
                session.cancel()
            } label: {
                Text("Cancel", bundle: .module)
            }
            // Claim Esc only when there's a move to cancel — a disabled button
            // still swallows its shortcut on macOS, which ate overlays' Esc.
            .keyboardShortcut(session.tentative == nil ? nil : .cancelAction)
            .disabled(session.tentative == nil)
            .opacity(session.tentative == nil ? 0 : 1)
            if session.mode != .daily {
                // Restart the same board. Disabled on an unplayed board: nothing
                // to restart, and it blocks a mis-tap toward Undo.
                Button {
                    session.newGame()
                    camera.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .disabled(session.game.moves.isEmpty)
                .accessibilityLabel(Text("Restart", bundle: .module))
            }
            if session.mode == .free {
                Button {
                    showShortcuts = false
                    isShowingNewGame = true
                } label: {
                    Label {
                        Text(verbatim: session.variantKey)
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .fixedSize()
                .accessibilityLabel(Text("New Game", bundle: .module))
                .accessibilityValue(Text(verbatim: session.variantKey))
            }
        }
    }

    // The New Game modal owns its own Esc via KeyCatcher; only the challenge
    // popover needs a window-level Esc here.
}
