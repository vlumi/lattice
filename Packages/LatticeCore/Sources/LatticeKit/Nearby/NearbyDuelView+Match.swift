import LatticeCore
import SwiftUI

/// The live match: the duel board, live standings, and the reach/dead-end
/// feedback panel.
extension NearbyDuelView {
    // MARK: Live match

    var matchView: some View {
        VStack(spacing: 12) {
            standingsBar
            if let m = duel.match {
                // Once you've finished (reached the target / dead-ended) your
                // board is done — the others play on, so watch the standings
                // above rather than a dead board.
                switch m.players[m.local]?.status {
                case .placed(let rank): finishedPanel(reached: true, rank: rank)
                case .eliminated: finishedPanel(reached: false, rank: nil)
                default: liveBoard(m)
                }
            }
        }
    }

    func liveBoard(_ m: DuelMatch) -> some View {
        let waiting = m.localWaitingForRound
        return DuelBoardView(
            game: m.game, waiting: waiting,
            onCommit: { duel.commitMove($0) }, onExit: resign
        )
        // Lock-step barrier: once you've moved you wait for the others — the
        // board is locked and dimmed until the round resolves.
        .disabled(waiting)
        .opacity(waiting ? 0.4 : 1)
        .overlay {
            if waiting {
                Text("Waiting for the others…", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder var standingsBar: some View {
        if let m = duel.match {
            VStack(spacing: 4) {
                ForEach(m.order, id: \.self) { tag in
                    if let p = m.players[tag] {
                        HStack {
                            Text(verbatim: p.name)
                                .fontWeight(tag == m.local ? .bold : .regular)
                            Spacer()
                            scoreLabel(m, tag: tag, state: p)
                        }
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(p.status == .eliminated ? .secondary : .primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func scoreLabel(_ m: DuelMatch, tag: String, state: DuelMatch.PlayerState) -> some View {
        switch m.mode {
        case .race(let tier):
            // Progress toward the target — the whole point of race.
            Text("\(state.score) / \(tier)", bundle: .module)
        case .lockStep:
            if state.status == .eliminated {
                Text("out", bundle: .module)
            } else if let remaining = duel.clocks[tag] {
                // On the clock — someone moved first, this player must keep up.
                Text("\(remaining, specifier: "%.1f")s", bundle: .module)
                    .foregroundStyle(remaining < 3 ? .red : .primary)
            } else if state.movedThisRound {
                // Committed this round, waiting at the barrier.
                Image(systemName: "checkmark")
            } else {
                // Thinking, no clock yet (nobody has moved this round).
                Image(systemName: "ellipsis")
            }
        }
    }

    func waiting(_ label: Text) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            label.foregroundStyle(.secondary)
        }
    }
}
