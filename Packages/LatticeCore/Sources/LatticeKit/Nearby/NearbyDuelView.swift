import LatticeCore
import SwiftUI

/// The Nearby duel screen: lobby (host a game or join one) → live match →
/// standings. Thin over `NearbyMatch`; the board reuses `DuelBoardView`.
/// Verified on devices (the transport can't run headlessly).
struct NearbyDuelView: View {
    // Non-private: the +Finished extension (result screen, action bar) reads them.
    @StateObject var duel: NearbyMatch
    @Environment(\.dismiss) var dismiss

    // Host config flow.
    @State private var configuringHost = false
    @State private var chosenVariant = DuelTier.eligibleVariants.first ?? "5T"
    @State private var chosenMode: ModeChoice = .lockStep
    @State private var chosenTier = 0
    /// Keyboard row cursor for the list-like lobby stages (guest games, host
    /// join-requests). Its meaning is per-stage; reset on any stage change.
    @State private var cursor = 0
    /// Keyboard focus row within host config (↑/↓ move, ←/→ change selection).
    @State private var configCursor: ConfigRow = .mode

    private enum ModeChoice: Hashable { case lockStep, race }
    /// Host-config rows ↑/↓ cycles (target only in race mode).
    fileprivate enum ConfigRow: Hashable { case mode, variant, target }

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
                case .hostLeft:
                    endMessage(
                        Text("The host left the game", bundle: .module),
                        systemImage: "wifi.slash")
                }
            }
            .frame(maxHeight: .infinity)
            dismissButton
        }
        .padding()
        #if os(macOS)
        // One KeyCatcher per window: the lobby stages use this one; during a
        // match DuelBoardView hosts its own (and handles Esc→resign there).
        .background(Group { if duel.stage != .dueling { KeyCatcher(onKey: handle) } })
        .onChangeCompat(of: duel.stage) { _ in cursor = 0 }
        #endif
        .onAppear { duel.start() }
        .onDisappear { duel.stop() }
    }

    // Resign concedes but stays in the screen: a 2-player match ends → the
    // result (with Rematch), and in a bigger match you watch the rest from the
    // standings. Leaving is a separate, explicit Close.
    private func resign() {
        duel.resign()
    }

    // MARK: Guest lobby — host button + games to join

    private var guestLobby: some View {
        VStack(spacing: 16) {
            Button {
                configCursor = .mode
                configuringHost = true
            } label: {
                Label {
                    Text("Host a game", bundle: .module)
                } icon: {
                    Image(systemName: "plus.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .rowCursor(cursor == 0)

            Text("Games nearby", bundle: .module).font(.headline)
            if duel.games.isEmpty {
                Text("Looking for a game to join…", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(duel.games.enumerated()), id: \.element.id) { index, game in
                Button {
                    duel.join(game)
                } label: {
                    Text(verbatim: game.label).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .rowCursor(cursor == index + 1)
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
            .rowCursor(configCursor == .mode)

            Picker(selection: $chosenVariant) {
                ForEach(duel.eligibleVariants, id: \.self) { v in
                    Text(verbatim: v).tag(v)
                }
            } label: {
                Text("Variant", bundle: .module)
            }
            .pickerStyle(.segmented)
            .rowCursor(configCursor == .variant)

            if chosenMode == .race {
                Picker(selection: $chosenTier) {
                    ForEach(duel.offerableTiers(variantKey: chosenVariant), id: \.self) { tier in
                        Text(verbatim: "\(tier)").tag(tier)
                    }
                } label: {
                    Text("Target", bundle: .module)
                }
                .pickerStyle(.segmented)
                .rowCursor(configCursor == .target)
            }

            Button(action: advertise) {
                Text("Advertise", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        // Keep the target a valid tier for the current variant.
        .onChangeCompat(of: chosenVariant) { _ in clampTier() }
        .onAppear(perform: clampTier)
    }

    private func clampTier() {
        let tiers = duel.offerableTiers(variantKey: chosenVariant)
        if !tiers.contains(chosenTier) { chosenTier = tiers.first ?? 0 }
    }

    private func advertise() {
        switch chosenMode {
        case .lockStep: duel.host(mode: .lockStep, variantKey: chosenVariant)
        case .race: duel.host(mode: .race(tier: chosenTier), variantKey: chosenVariant)
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
                ForEach(Array(duel.joinRequests.enumerated()), id: \.element.id) { index, request in
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
                    .rowCursor(cursor == index)
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

    private func liveBoard(_ m: DuelMatch) -> some View {
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

    private func waiting(_ label: Text) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            label.foregroundStyle(.secondary)
        }
    }
}

#if os(macOS)
// Lobby keyboard nav (the match board handles its own keys in DuelBoardView),
// dispatched by the same stage/role/config the body switches on.
extension NearbyDuelView {
    fileprivate func handle(_ key: KeyCatcher.Key) {
        switch duel.stage {
        case .lobby where duel.role == .hosting: handleHostLobby(key)
        case .lobby where configuringHost: handleHostConfig(key)
        case .lobby: handleGuestLobby(key)
        case .finished where duel.role == .hosting:
            if key == .enter || key == .space { duel.rematch() }  // primary action
            if key == .escape { dismiss() }
        default: if key == .escape { dismiss() }  // waitingForHost / hostLeft / guest
        }
    }

    private func handleGuestLobby(_ key: KeyCatcher.Key) {
        let count = duel.games.count + 1  // row 0 = Host, then each game
        switch key {
        case .up: cursor = max(cursor - 1, 0)
        case .down: cursor = min(cursor + 1, count - 1)
        case .enter, .space:
            if cursor == 0 {
                configCursor = .mode
                configuringHost = true
            } else if duel.games.indices.contains(cursor - 1) {
                duel.join(duel.games[cursor - 1])
            }
        case .escape: dismiss()
        default: break
        }
    }

    private func handleHostConfig(_ key: KeyCatcher.Key) {
        switch key {
        case .up: moveConfigRow(-1)
        case .down: moveConfigRow(1)
        case .left: changeConfigRow(-1)
        case .right: changeConfigRow(1)
        case .enter, .space: advertise()  // Return anywhere = Advertise
        case .escape: configuringHost = false
        default: break
        }
    }

    /// The rows ↑/↓ cycles — Target only in race mode. Advertise isn't a row:
    /// Return advertises from anywhere.
    private var configRows: [ConfigRow] {
        chosenMode == .race ? [.mode, .variant, .target] : [.mode, .variant]
    }

    private func moveConfigRow(_ step: Int) {
        let rows = configRows
        let current = rows.firstIndex(of: configCursor) ?? 0
        configCursor = rows[min(max(current + step, 0), rows.count - 1)]
    }

    // ←/→ change the focused row's selection (clamped within the options).
    private func changeConfigRow(_ step: Int) {
        switch configCursor {
        case .mode:
            chosenMode = step < 0 ? .lockStep : .race
        case .variant:
            let options = duel.eligibleVariants
            if let i = options.firstIndex(of: chosenVariant) {
                chosenVariant = options[min(max(i + step, 0), options.count - 1)]
            }
        case .target:
            let options = duel.offerableTiers(variantKey: chosenVariant)
            if let i = options.firstIndex(of: chosenTier) {
                chosenTier = options[min(max(i + step, 0), options.count - 1)]
            }
        }
    }

    private func handleHostLobby(_ key: KeyCatcher.Key) {
        let requests = duel.joinRequests
        switch key {
        case .up: cursor = max(cursor - 1, 0)
        case .down: cursor = min(cursor + 1, max(requests.count - 1, 0))
        case .enter, .space:
            // With pending requests, Return accepts the cursored one; else Start.
            if requests.indices.contains(cursor) {
                duel.accept(requests[cursor])
            } else if duel.lobbyNames.count >= 2 {
                duel.startMatch()
            }
        case .delete:
            if requests.indices.contains(cursor) { duel.decline(requests[cursor]) }
        case .escape: dismiss()
        default: break
        }
    }
}
#endif
