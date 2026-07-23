import LatticeCore
import SwiftUI

/// The Nearby duel screen: lobby (host a game or join one) → live match →
/// standings. Thin over `NearbyMatch`; the board reuses `DuelBoardView`.
/// Verified on devices (the transport can't run headlessly).
struct NearbyDuelView: View {
    @StateObject private var duel: NearbyMatch
    @Environment(\.dismiss) private var dismiss

    // Host config flow.
    @State private var configuringHost = false
    @State private var chosenVariant = DuelTier.eligibleVariants.first ?? "5T"
    @State private var chosenMode: ModeChoice = .lockStep

    private enum ModeChoice: Hashable { case lockStep, race }

    init(name: String, bests: BestScores) {
        _duel = StateObject(wrappedValue: NearbyMatch(name: name, bests: bests))
    }

    var body: some View {
        VStack(spacing: 16) {
            Group {
                switch duel.stage {
                case .lobby:
                    if duel.role == .hosting {
                        hostLobby
                    } else if configuringHost {
                        hostConfig
                    } else {
                        guestLobby
                    }
                case .waitingForHost:
                    waiting(Text("Waiting for the host to start…", bundle: .module))
                case .dueling:
                    matchView
                case .finished(let standings):
                    result(standings)
                }
            }
            .frame(maxHeight: .infinity)
            dismissButton
        }
        .padding()
        .onAppear { duel.start() }
        .onDisappear { duel.stop() }
    }

    // Leaving mid-match forfeits (the others score it as a drop) — so it reads
    // "Resign" while playing, a plain "Close" otherwise.
    @ViewBuilder private var dismissButton: some View {
        if duel.stage == .dueling {
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

    // MARK: Guest lobby — host button + games to join

    private var guestLobby: some View {
        VStack(spacing: 16) {
            Button {
                configuringHost = true
            } label: {
                Label {
                    Text("Host a game", bundle: .module)
                } icon: {
                    Image(systemName: "plus.circle")
                }
            }
            .buttonStyle(.borderedProminent)

            Text("Games nearby", bundle: .module).font(.headline)
            if duel.games.isEmpty {
                Text("Looking for a game to join…", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(duel.games) { game in
                Button {
                    duel.join(game)
                } label: {
                    Text(verbatim: game.label).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Host config — pick mode + variant, then advertise

    private var hostConfig: some View {
        VStack(spacing: 16) {
            Text("Host a game", bundle: .module).font(.headline)
            Picker(selection: $chosenMode) {
                Text("Lock-step", bundle: .module).tag(ModeChoice.lockStep)
                Text("Race", bundle: .module).tag(ModeChoice.race)
            } label: {
                Text("Mode", bundle: .module)
            }
            .pickerStyle(.segmented)

            Picker(selection: $chosenVariant) {
                ForEach(duel.eligibleVariants, id: \.self) { v in
                    Text(verbatim: v).tag(v)
                }
            } label: {
                Text("Variant", bundle: .module)
            }

            if chosenMode == .race {
                Text("Target", bundle: .module).font(.subheadline).foregroundStyle(.secondary)
                raceTierPicker
            } else {
                Button {
                    duel.host(mode: .lockStep, variantKey: chosenVariant)
                } label: {
                    Text("Advertise", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var raceTierPicker: some View {
        HStack {
            ForEach(duel.offerableTiers(variantKey: chosenVariant), id: \.self) { tier in
                Button("\(tier)") {
                    duel.host(mode: .race(tier: tier), variantKey: chosenVariant)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Host lobby — accepted players + join requests + start

    private var hostLobby: some View {
        VStack(spacing: 16) {
            Text("Your game", bundle: .module).font(.headline)
            ForEach(duel.lobbyNames, id: \.self) { name in
                Text(verbatim: name)
            }
            if !duel.joinRequests.isEmpty {
                Divider()
                Text("Wants to join", bundle: .module).font(.subheadline)
                ForEach(duel.joinRequests) { request in
                    HStack {
                        Text(verbatim: request.name)
                        Spacer()
                        Button {
                            duel.accept(request)
                        } label: {
                            Text("Accept", bundle: .module)
                        }
                        Button(role: .cancel) {
                            duel.decline(request)
                        } label: {
                            Text("Decline", bundle: .module)
                        }
                    }
                }
            }
            Button {
                duel.startMatch()
            } label: {
                Text("Start", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(duel.lobbyNames.count < 2)
        }
    }

    // MARK: Live match

    private var matchView: some View {
        VStack(spacing: 12) {
            standingsBar
            if let m = duel.match {
                DuelBoardView(game: m.game) { move in duel.commitMove(move) }
            }
        }
    }

    @ViewBuilder private var standingsBar: some View {
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
    private func scoreLabel(_ m: DuelMatch, tag: String, state: DuelMatch.PlayerState) -> some View
    {
        if case .race(let tier) = m.mode {
            Text("\(state.score) / \(tier)", bundle: .module)
        } else if let remaining = duel.clocks[tag] {
            Text("\(remaining, specifier: "%.1f")s", bundle: .module)
                .foregroundStyle(remaining < 3 ? .red : .primary)
        } else {
            Text(verbatim: "\(state.score)")
        }
    }

    // MARK: Result

    private func result(_ standings: [String]) -> some View {
        VStack(spacing: 12) {
            Text("Result", bundle: .module).font(.largeTitle.weight(.bold))
            ForEach(Array(standings.enumerated()), id: \.offset) { index, name in
                HStack {
                    Text(verbatim: "\(index + 1).")
                    Text(verbatim: name)
                }
                .font(index == 0 ? .title3.weight(.bold) : .body)
            }
        }
    }

    private func waiting(_ label: Text) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            label.foregroundStyle(.secondary)
        }
    }
}
