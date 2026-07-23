import SwiftUI

/// Settings: the iCloud sync opt-in (off by default). Reset-progress will
/// join here later (roadmap).
struct SettingsView: View {
    @ObservedObject var sync: SyncController
    @State private var name: String = PlayerName.current()

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
    }
}
