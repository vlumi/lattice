import LatticeCore
import SwiftUI

/// The Nearby duel screen: lobby → (host) tier pick → live duel. Thin over
/// `NearbyDuel`; the duel board reuses the game's own rendering. Verified on
/// two devices (the transport can't run headlessly).
struct NearbyDuelView: View {
    @StateObject private var duel: NearbyDuel
    @Environment(\.dismiss) private var dismiss

    init(name: String, bests: BestScores) {
        _duel = StateObject(wrappedValue: NearbyDuel(name: name, bests: bests))
    }

    var body: some View {
        VStack(spacing: 16) {
            Group {
                switch duel.stage {
                case nil:
                    lobby
                case .connecting:
                    waiting(Text("Connecting…", bundle: .module))
                case .choosingTier(let variants):
                    tierPicker(variants)
                case .awaitingAccept:
                    waiting(Text("Waiting for the host to choose…", bundle: .module))
                case .dueling:
                    duelBoard
                case .finished(let outcome):
                    result(outcome)
                case .failed:
                    waiting(Text("Connection lost.", bundle: .module))
                }
            }
            .frame(maxHeight: .infinity)
            dismissButton
        }
        .padding()
        .onAppear { duel.start() }
        .onDisappear { duel.stop() }
    }

    // Leaving mid-duel disconnects, which the opponent scores as a win — so it
    // reads as "Resign" while playing, a plain "Close" otherwise.
    @ViewBuilder private var dismissButton: some View {
        if case .dueling = duel.stage {
            Button(role: .destructive) {
                dismiss()
            } label: {
                Text("Resign", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else {
            Button {
                dismiss()
            } label: {
                Text("Close", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var lobby: some View {
        VStack(spacing: 16) {
            Text("Nearby players", bundle: .module).font(.headline)
            if duel.peers.isEmpty {
                Text("Looking for someone nearby…", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(duel.peers, id: \.self) { peer in
                Button(peer.displayName) { duel.invite(peer) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func waiting(_ label: Text) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            label.foregroundStyle(.secondary)
            if let name = duel.opponentName {
                Text("with \(name)", bundle: .module).font(.subheadline)
            }
        }
    }

    private func tierPicker(_ variants: [String]) -> some View {
        VStack(spacing: 16) {
            Text("Choose the challenge", bundle: .module).font(.headline)
            if let name = duel.opponentName {
                Text("vs \(name)", bundle: .module).foregroundStyle(.secondary)
            }
            ForEach(variants, id: \.self) { variant in
                let tiers = duel.offerableTiers(variantKey: variant)
                if !tiers.isEmpty {
                    Text(verbatim: variant).font(.subheadline.weight(.semibold))
                    HStack {
                        ForEach(tiers, id: \.self) { tier in
                            Button("\(tier)") {
                                duel.hostChoose(variantKey: variant, tier: tier)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private var duelBoard: some View {
        VStack(spacing: 12) {
            HStack {
                if let d = duel.duel {
                    Text("Score \(d.game.score) / \(d.tier)", bundle: .module)
                        .font(.headline.monospacedDigit())
                }
                Spacer()
                if let remaining = duel.clockRemaining {
                    Text("\(remaining, specifier: "%.1f")s", bundle: .module)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(remaining < 3 ? .red : .primary)
                }
            }
            if let d = duel.duel {
                DuelBoardView(game: d.game) { move in duel.commitMove(move) }
            }
        }
    }

    @ViewBuilder
    private func result(_ outcome: DuelProtocol.Outcome) -> some View {
        VStack(spacing: 12) {
            if outcome == .won {
                Text("You win!", bundle: .module).font(.largeTitle.weight(.bold))
            } else {
                Text("You lose.", bundle: .module).font(.largeTitle.weight(.bold))
            }
            if let name = duel.opponentName {
                Text("vs \(name)", bundle: .module).foregroundStyle(.secondary)
            }
        }
    }
}
