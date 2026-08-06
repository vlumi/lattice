import SwiftUI

/// Settings: sound & haptics, the iCloud sync opt-in (off by default), and the
/// Nearby display name. Reset-progress will join here later (roadmap).
struct SettingsView: View {
    @ObservedObject var sync: SyncController
    let feedback: Feedback
    @State private var name: String = PlayerName.current()

    // Sound off by default (opt-in); haptics on by default. Keys match
    // Feedback's; the live players are updated on change.
    @AppStorage(Feedback.soundDefaultsKey) private var soundOn = false
    @AppStorage(Feedback.hapticsDefaultsKey) private var hapticsOn = true

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
                Toggle(isOn: $hapticsOn) {
                    Text("Haptics", bundle: .module)
                }
                .onChangeCompat(of: hapticsOn) { feedback.setHaptics($0) }
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
            } header: {
                Text("Sync", bundle: .module)
            } footer: {
                syncFooter
            }
            Section {
                TextField(text: $name) {
                    Text("Name", bundle: .module)
                }
                .onChangeCompat(of: name) { PlayerName.set($0) }
            } header: {
                Text("Nearby", bundle: .module)
            } footer: {
                Text("The name other players see when you duel nearby.", bundle: .module)
            }
        }
        .formStyle(.grouped)
    }
}
