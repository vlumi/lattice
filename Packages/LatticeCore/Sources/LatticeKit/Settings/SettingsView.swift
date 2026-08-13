import SwiftUI

/// Settings: sound & haptics and the iCloud sync opt-in (off by default).
/// Reset-progress will join here later (roadmap). The Nearby name lives on the
/// Nearby screen (set it where you broadcast it).
struct SettingsView: View {
    @ObservedObject var sync: SyncController
    let feedback: Feedback
    /// Closes the presenting sheet (macOS); no-op for the iOS tab.
    var onClose: () -> Void = {}
    /// Erases all progress — owned by AppModel, which holds the sessions.
    var onReset: () -> Void = {}

    // Sound off by default (opt-in); haptics on by default. Keys match
    // Feedback's; the live players are updated on change.
    @AppStorage(Feedback.soundDefaultsKey) private var soundOn = false
    @AppStorage(Feedback.hapticsDefaultsKey) private var hapticsOn = true

    // Keyboard row cursor: Up/Down move, Space toggles the focused row.
    private enum Row: Int, CaseIterable { case sound, haptics, sync, reset }
    @State private var cursor: Row = .sound
    @State private var showAbout = false
    @State private var confirmingReset = false
    @State private var showHowTo = false

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
                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    Text("Reset progress…", bundle: .module)
                }
                .rowCursor(cursor == .reset)
            } footer: {
                Text(
                    """
                    Clears your best scores, replays, daily streak and any game \
                    in progress. Settings stay as they are.
                    """, bundle: .module)
            }
            // iOS only: the Mac reaches About from the app menu, where the
            // platform expects it — a Settings row there would be redundant.
            #if !os(macOS)
            Section {
                Button {
                    showHowTo = true
                } label: {
                    Label {
                        Text("How to play", bundle: .module)
                    } icon: {
                        Image(systemName: "questionmark.circle")
                    }
                }
                Button {
                    showAbout = true
                } label: {
                    Label {
                        Text("About Lattice Five", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .confirmationDialog(
            sync.canWipeCloud
                ? Text("Erase progress on all your devices?", bundle: .module)
                : Text("Reset all progress?", bundle: .module),
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                onReset()
            } label: {
                sync.canWipeCloud
                    ? Text("Erase everywhere", bundle: .module)
                    : Text("Reset progress", bundle: .module)
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", bundle: .module)
            }
        } message: {
            // Say which it is. With sync off the cloud copy is deliberately left
            // alone, and turning sync back on would restore it — the user has to
            // know that rather than be surprised later.
            sync.canWipeCloud
                ? Text(
                    """
                    This erases your best scores, replays and daily streak on \
                    every device signed in to your iCloud. It can't be undone.
                    """, bundle: .module)
                : Text(
                    """
                    This resets your best scores, replays and daily streak on \
                    this device. It can't be undone.
                    """, bundle: .module)
        }
        .sheet(isPresented: $showAbout) {
            AboutSheet(dismiss: { showAbout = false })
        }
        .sheet(isPresented: $showHowTo) {
            HowToPlaySheet(dismiss: { showHowTo = false })
        }
        #if os(macOS)
        .background(KeyCatcher(onKey: handle))
        #endif
    }

    #if os(macOS)
    private func handle(_ key: KeyCatcher.Key) {
        switch key {
        case .up, .backTab: move(-1)
        case .down, .tab: move(1)
        case .space: activate()  // toggle the focused row
        case .enter, .escape: onClose()  // Done
        default: break
        }
    }

    private func move(_ step: Int) {
        let all = Row.allCases
        cursor = all[min(max(cursor.rawValue + step, 0), all.count - 1)]
    }

    private func activate() {
        switch cursor {
        case .sound: soundOn.toggle()
        case .haptics: hapticsOn.toggle()
        case .sync: if sync.isAvailable { sync.isOn.toggle() }
        // Space opens the confirmation, never resets outright.
        case .reset: confirmingReset = true
        }
    }
    #endif
}
