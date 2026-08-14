import LatticeCore
import SwiftUI

/// Before the match: browsing advertised games, the host's config, and the
/// host lobby where join requests are accepted.
extension NearbyDuelView {
    // MARK: Guest lobby — host button + games to join

    var guestLobby: some View {
        VStack(spacing: 16) {
            // Your display name — defaults to the device name, so set it here
            // before hosting/joining if you'd rather not broadcast that. A
            // pencil + field border make it read as editable, not a caption.
            VStack(alignment: .leading, spacing: 4) {
                Text("Your name (others see this)", bundle: .module)
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "pencil").foregroundStyle(.secondary)
                    TextField(text: $editedName) { Text("Your name", bundle: .module) }
                        .textFieldStyle(.plain)
                        .focused($nameFocused)
                        .onSubmit { commitName() }  // iOS Return (macOS: KeyCatcher)
                        .onChangeCompat(of: editedName) { PlayerName.set($0) }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.tint.opacity(0.5)))
            }
            .rowCursor(keyboardActive && (cursor == 0))

            Button {
                duel.rename(editedName)  // apply a pending edit before hosting
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
            .rowCursor(keyboardActive && (cursor == 1))

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
                .rowCursor(keyboardActive && (cursor == index + 2))
            }
        }
    }

    // MARK: Host config — pick mode + variant, then advertise

    var hostConfig: some View {
        VStack(spacing: 16) {
            Text("Host a game", bundle: .module).font(.headline)

            Picker(selection: $chosenMode) {
                Text("Lock-step", bundle: .module).tag(ModeChoice.lockStep)
                Text("Race", bundle: .module).tag(ModeChoice.race)
            } label: {
                Text("Mode", bundle: .module)
            }
            .pickerStyle(.segmented)
            .rowCursor(keyboardActive && (configCursor == .mode))

            Picker(selection: $chosenVariant) {
                ForEach(duel.eligibleVariants, id: \.self) { v in
                    Text(verbatim: v).tag(v)
                }
            } label: {
                Text("Variant", bundle: .module)
            }
            .pickerStyle(.segmented)
            .rowCursor(keyboardActive && (configCursor == .variant))

            if chosenMode == .race {
                Picker(selection: $chosenTier) {
                    ForEach(duel.offerableTiers(variantKey: chosenVariant), id: \.self) { tier in
                        Text(verbatim: "\(tier)").tag(tier)
                    }
                } label: {
                    Text("Target", bundle: .module)
                }
                .pickerStyle(.segmented)
                .rowCursor(keyboardActive && (configCursor == .target))
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

    func clampTier() {
        let tiers = duel.offerableTiers(variantKey: chosenVariant)
        if !tiers.contains(chosenTier) { chosenTier = tiers.first ?? 0 }
    }

    func advertise() {
        switch chosenMode {
        case .lockStep: duel.host(mode: .lockStep, variantKey: chosenVariant)
        case .race: duel.host(mode: .race(tier: chosenTier), variantKey: chosenVariant)
        }
    }

    // MARK: Host lobby — accepted players + join requests + start

    var hostLobby: some View {
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
                    .rowCursor(keyboardActive && (cursor == index))
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

}
