import SwiftUI

/// Settings: the iCloud sync opt-in (off by default). Reset-progress will
/// join here later (roadmap).
struct SettingsView: View {
    @ObservedObject var sync: SyncController

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
        }
    }
}
