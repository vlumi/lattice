import LatticeCore
import SwiftUI

extension NearbyDuelView {
    // Shown after the local player finishes: reached the target (with the place
    // they took) or dead-ended. The others keep playing; the standings bar above
    // updates live until the match ends.
    func finishedPanel(reached: Bool, rank: Int?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: reached ? "flag.checkered" : "flag.slash")
                .font(.largeTitle)
                .foregroundStyle(reached ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            if reached, let rank {
                Text("Reached the target — \(placeLabel(rank))", bundle: .module)
                    .font(.headline)
            } else {
                Text("No moves left", bundle: .module).font(.headline)
            }
            Text("Waiting for the others to finish…", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func placeLabel(_ rank: Int) -> Text {
        switch rank {
        case 1: return Text("1st", bundle: .module)
        case 2: return Text("2nd", bundle: .module)
        case 3: return Text("3rd", bundle: .module)
        default: return Text("\(rank)th", bundle: .module)
        }
    }

    // MARK: Result screen

    func result(_ standings: [NearbyMatch.Standing]) -> some View {
        // Standings arrive pre-ranked (the host authors race times). Competition
        // ranking: rows with the same ranking key share a position (1, 2, 2, 4).
        var ranks: [Int] = []
        for (i, s) in standings.enumerated() {
            if i > 0, rankKey(s) == rankKey(standings[i - 1]) {
                ranks.append(ranks[i - 1])
            } else {
                ranks.append(i + 1)
            }
        }
        return VStack(spacing: 12) {
            Text("Result", bundle: .module).font(.largeTitle.weight(.bold))
            ForEach(Array(standings.enumerated()), id: \.offset) { index, standing in
                HStack {
                    Text(verbatim: "\(ranks[index]).")
                    Text(verbatim: standing.name)
                    Spacer()
                    resultValue(standing).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(ranks[index] == 1 ? .title3.weight(.bold) : .body)
            }
        }
    }

    /// The tie key: a finisher's reach-time, else (nil) their move count negated
    /// so more moves ranks higher — matching the host's sort.
    private func rankKey(_ s: NearbyMatch.Standing) -> Double {
        s.reachTime ?? Double(-s.score)
    }

    // Finishers show their time to the target; non-finishers show move count.
    @ViewBuilder private func resultValue(_ s: NearbyMatch.Standing) -> some View {
        if let time = s.reachTime {
            Text(verbatim: timeString(time))
        } else {
            Text("\(s.score) moves", bundle: .module)
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    func endMessage(_ label: Text, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.largeTitle).foregroundStyle(.secondary)
            label.font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Bottom action bar

    // Playing: Resign. Finished (host): Rematch / Back to lobby / Close — play
    // again with the same players, keeping the connection. Otherwise: Close.
    @ViewBuilder var dismissButton: some View {
        switch duel.stage {
        case .dueling where duel.localIsActive:
            // Resign concedes but stays: the match ends to the result (2-player)
            // or you watch the rest from the standings. Close leaves separately.
            Button(role: .destructive) {
                duel.resign()
            } label: {
                Text("Resign", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        case .dueling:
            // Already out (resigned / dead-ended): just watching — Close leaves.
            closeButton
        case .finished where duel.role == .hosting && duel.hasAcceptedPeers:
            VStack(spacing: 8) {
                Button(action: duel.rematch) {
                    Text("Rematch", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(action: duel.backToLobby) {
                    Text("Back to Lobby", bundle: .module).frame(maxWidth: .infinity)
                }
                closeButton
            }
        default:
            // No peers left (everyone closed) → only Close.
            closeButton
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Close", bundle: .module).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
