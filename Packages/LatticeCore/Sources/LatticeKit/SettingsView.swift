import SwiftUI

/// Settings: sound & haptics, the iCloud sync opt-in (off by default), and the
/// Nearby display name. Reset-progress will join here later (roadmap).
struct SettingsView: View {
    @ObservedObject var sync: SyncController
    let feedback: Feedback
    /// Closes the presenting sheet (macOS); no-op for the iOS tab.
    var onClose: () -> Void = {}
    @State private var name: String = PlayerName.current()

    // Sound off by default (opt-in); haptics on by default. Keys match
    // Feedback's; the live players are updated on change.
    @AppStorage(Feedback.soundDefaultsKey) private var soundOn = false
    @AppStorage(Feedback.hapticsDefaultsKey) private var hapticsOn = true

    // Keyboard row cursor: Up/Down move, Space/Return toggle or enter the field.
    private enum Row: Int, CaseIterable { case sound, haptics, sync, name }
    @State private var cursor: Row = .sound
    @FocusState private var nameFocused: Bool

    private var syncFooter: Text {
        if sync.isAvailable {
            return Text(
                """
                Keep your best scores and daily streak across your devices. \
                Games and replays stay on each device.
                """, bundle: .module)
        }
        return Text("Sign in to iCloud to sync across your devices.", bundle: .module)
    }

    var body: some View {
        Form {
            // First — the quickest setting to reach; sound is a bit more
            // prominent than the buried haptics toggle below it.
            Section {
                Toggle(isOn: $soundOn) {
                    Text("Sound effects", bundle: .module)
                }
                .onChangeCompat(of: soundOn) { feedback.setSound($0) }
                .rowCursor(cursor == .sound)
                Toggle(isOn: $hapticsOn) {
                    Text("Haptics", bundle: .module)
                }
                .onChangeCompat(of: hapticsOn) { feedback.setHaptics($0) }
                .rowCursor(cursor == .haptics)
            } header: {
                Text("Sound & Haptics", bundle: .module)
            } footer: {
                Text(
                    "Subtle ticks while playing. Sound follows your ring/silent switch.",
                    bundle: .module)
            }
            Section {
                Toggle(isOn: $sync.isOn) {
                    Text("iCloud Sync", bundle: .module)
                }
                .disabled(!sync.isAvailable)
                .rowCursor(cursor == .sync)
            } header: {
                Text("Sync", bundle: .module)
            } footer: {
                syncFooter
            }
            Section {
                TextField(text: $name) {
                    Text("Name", bundle: .module)
                }
                .focused($nameFocused)
                .onChangeCompat(of: name) { PlayerName.set($0) }
                .rowCursor(cursor == .name)
            } header: {
                Text("Nearby", bundle: .module)
            } footer: {
                Text("The name other players see when you duel nearby.", bundle: .module)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .background(KeyCatcher(onKey: handle, yieldsToTextFields: true))
        #endif
    }

    #if os(macOS)
    private func handle(_ key: KeyCatcher.Key) {
        // Editing the name: Enter/Esc commit and leave the field.
        if nameFocused {
            if key == .enter || key == .escape { nameFocused = false }
            return
        }
        switch key {
        case .up, .backTab: move(-1)
        case .down, .tab: move(1)
        case .space: activate()  // Space toggles the focused row
        case .enter: onClose()  // Return = Done
        case .escape: onClose()
        default: break
        }
    }

    private func move(_ step: Int) {
        let all = Row.allCases
        cursor = all[min(max(cursor.rawValue + step, 0), all.count - 1)]
    }

    // Space on the focused row: flip a toggle, or enter the name field.
    private func activate() {
        switch cursor {
        case .sound: soundOn.toggle()
        case .haptics: hapticsOn.toggle()
        case .sync: if sync.isAvailable { sync.isOn.toggle() }
        case .name: nameFocused = true
        }
    }
    #endif
}
