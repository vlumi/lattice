import LatticeCore
import SwiftUI

/// The Nearby duel screen: lobby (host a game or join one) → live match →
/// standings. Thin over `NearbyMatch`; the board reuses `DuelBoardView`.
/// Verified on devices (the transport can't run headlessly).
struct NearbyDuelView: View {
    // State is internal, not private: the +Lobby / +Match / +Finished extensions
    // all read it.
    @StateObject var duel: NearbyMatch
    @Environment(\.dismiss) var dismiss

    // Host config flow.
    @State var configuringHost = false
    @State var chosenVariant = DuelTier.eligibleVariants.first ?? "5T"
    @State var chosenMode: ModeChoice = .lockStep
    @State var chosenTier = 0
    /// Keyboard row cursor for the list-like lobby stages (guest games, host
    /// join-requests). Its meaning is per-stage; reset on any stage change.
    @State var cursor = 0
    /// Keyboard focus row within host config (↑/↓ move, ←/→ change selection).
    @State var configCursor: ConfigRow = .mode
    /// Hides the row ring until the keyboard is used. See NewGameModal.
    @State var keyboardActive = false
    /// The name field in the guest lobby (seeded from the stored PlayerName).
    @State var editedName = PlayerName.current()
    @FocusState var nameFocused: Bool

    enum ModeChoice: Hashable { case lockStep, race }
    /// Host-config rows ↑/↓ cycles (target only in race mode).
    enum ConfigRow: Hashable { case mode, variant, target }

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
        .background(
            Group {
                if duel.stage != .dueling {
                    KeyCatcher(onKey: handle, yieldsToTextFields: true)
                }
            }
        )
        .onChangeCompat(of: duel.stage) { _ in cursor = 0 }
        #endif
        .onAppear { duel.start() }
        .onDisappear { duel.stop() }
    }

    // Resign concedes but stays in the screen: a 2-player match ends → the
    // result (with Rematch), and in a bigger match you watch the rest from the
    // standings. Leaving is a separate, explicit Close.
    func resign() {
        duel.resign()
    }

    /// Commit the name edit and leave the field (Return / Esc).
    func commitName() {
        duel.rename(editedName)
        nameFocused = false
    }

}

#if os(macOS)
// Lobby keyboard nav (the match board handles its own keys in DuelBoardView),
// dispatched by the same stage/role/config the body switches on.
extension NearbyDuelView {
    fileprivate func handle(_ key: KeyCatcher.Key) {
        // Any key but Esc reveals the row ring — it's a keyboard affordance, so
        // a pointer user shouldn't see an outline they didn't ask for.
        if key != .escape { keyboardActive = true }
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
        // Editing the name: KeyCatcher has already handed focus back and
        // forwards Enter/Esc/Tab here. Commit + clear focus so arrow-nav resumes
        // (Tab also advances a row). Don't dismiss on Esc while editing.
        if nameFocused {
            switch key {
            case .enter, .escape: commitName()
            case .tab: commitName(); cursor = min(cursor + 1, duel.games.count + 1)
            case .backTab: commitName()
            default: break
            }
            return
        }
        // Rows: 0 = name field, 1 = Host, 2… = each nearby game.
        let count = duel.games.count + 2
        switch key {
        case .up: cursor = max(cursor - 1, 0)
        case .down: cursor = min(cursor + 1, count - 1)
        case .enter, .space: activateGuestRow()
        case .escape: dismiss()
        default: break
        }
    }

    private func activateGuestRow() {
        switch cursor {
        case 0: nameFocused = true
        case 1:
            duel.rename(editedName)
            configCursor = .mode
            configuringHost = true
        default:
            if duel.games.indices.contains(cursor - 2) {
                duel.join(duel.games[cursor - 2])
            }
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
