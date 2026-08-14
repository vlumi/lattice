import LatticeCore
import SwiftUI

/// The board screen's top bar: score, variant/challenge chips, and the
/// New Game / Restart / share controls.
extension GameView {
    /// One row normally. At accessibility text sizes it can't fit a narrow
    /// screen (it clipped the New Game button clean off an SE), so the status
    /// text and the controls split onto two lines rather than scroll or
    /// truncate — everything stays visible and tappable without a gesture.
    var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                status
                Spacer()
                controls
            }
            VStack(alignment: .leading, spacing: 8) {
                status
                HStack(spacing: 16) { controls }
            }
        }
    }

    @ViewBuilder private var status: some View {
        HStack(spacing: 16) {
            // The number alone: the board is the context, and the word cost
            // the whole row its fit at accessibility sizes. VoiceOver still
            // hears "Score".
            Text(verbatim: "\(session.game.score)")
                .font(.headline.monospacedDigit())
                .accessibilityLabel(Text("Score", bundle: .module))
                .accessibilityValue(Text(verbatim: "\(session.game.score)"))
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
                    // The glyph alone — the code itself is in the popover, and
                    // spelling it out here cost the row its fit at large text.
                    Image(systemName: "qrcode")
                        .font(.subheadline)
                }
                .accessibilityLabel(Text("Share challenge", bundle: .module))
                .accessibilityValue(Text(verbatim: code))
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
        }
    }

    @ViewBuilder private var controls: some View {
        Group {
            // Only while there IS something to cancel. It used to be always
            // present (hidden) to keep the header's width constant, but at
            // accessibility sizes a whole invisible word is what pushed the row
            // off a narrow screen; the board re-fits smoothly enough without it.
            if session.tentative != nil {
                Button {
                    session.cancel()
                } label: {
                    Text("Cancel", bundle: .module)
                }
                .keyboardShortcut(.cancelAction)
            }
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
                // Reads as pressed while its modal is open — it's the control
                // that opened it, so leaving it inert looked like a dead button.
                .buttonStyle(.bordered)
                .tint(isShowingNewGame ? .accentColor : nil)
                .fixedSize()
                .accessibilityLabel(Text("New Game", bundle: .module))
                .accessibilityValue(Text(verbatim: session.variantKey))
                .accessibilityAddTraits(isShowingNewGame ? [.isSelected] : [])
            }
        }
    }

    // The New Game modal owns its own Esc via KeyCatcher; only the challenge
    // popover needs a window-level Esc here.
}
