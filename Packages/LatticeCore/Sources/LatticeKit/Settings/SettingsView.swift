import LatticeCore
import SwiftUI

/// Settings: sound & haptics, the iCloud sync opt-in (off by default), and the
/// data actions — export and reset. The Nearby name lives on the Nearby screen
/// (set it where you broadcast it).
struct SettingsView: View {
    @ObservedObject var sync: SyncController
    let feedback: Feedback
    /// Closes the presenting sheet (macOS); no-op for the iOS tab.
    var onClose: () -> Void = {}
    /// Erases all progress — owned by AppModel, which holds the sessions.
    var onReset: () -> Void = {}
    /// Builds the export payload; AppModel owns the store.
    var exportData: () -> Data? = { nil }

    // Sound off by default (opt-in); haptics on by default. Keys match
    // Feedback's; the live players are updated on change.
    @AppStorage(Feedback.soundDefaultsKey) private var soundOn = false
    @AppStorage(Feedback.hapticsDefaultsKey) private var hapticsOn = true

    // Keyboard row cursor: Up/Down move, Space toggles the focused row.
    private enum Row: Int, CaseIterable { case sound, haptics, sync, reset }
    @State private var cursor: Row = .sound
    /// The row ring is a keyboard affordance — hidden until a key is used, so a
    /// pointer user never sees an unexplained outline. See NewGameModal.
    @State private var keyboardActive = false
    @State private var showAbout = false
    @State private var confirmingReset = false
    @State private var exportDocument: JSONDocument?
    @State private var isExportingData = false
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
                .rowCursor(keyboardActive && cursor == .sound)
                Toggle(isOn: $hapticsOn) {
                    Text("Haptics", bundle: .module)
                }
                .onChangeCompat(of: hapticsOn) { feedback.setHaptics($0) }
                .rowCursor(keyboardActive && cursor == .haptics)
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
                .rowCursor(keyboardActive && cursor == .sync)
            } header: {
                Text("Sync", bundle: .module)
            } footer: {
                syncFooter
            }
            Section {
                // Data portability, not a debug feature: the honest counterpart
                // to Reset below, and what lets a bug report carry the exact
                // game that misbehaved.
                Button {
                    beginExport()
                } label: {
                    Label {
                        Text("Export game data…", bundle: .module)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    Text("Reset progress…", bundle: .module)
                }
                .rowCursor(keyboardActive && cursor == .reset)
            } footer: {
                Text(
                    """
                    Export writes every finished game — with its moves — plus \
                    your bests and daily log, as JSON. Reset clears all of that; \
                    settings stay as they are.
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
        .fileExporter(
            isPresented: $isExportingData, document: exportDocument,
            contentType: .json, defaultFilename: DataExport.filename()
        ) { _ in
            exportDocument = nil
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

    private func beginExport() {
        guard let data = exportData() else { return }
        exportDocument = JSONDocument(data: data)
        isExportingData = true
    }

    #if os(macOS)
    private func handle(_ key: KeyCatcher.Key) {
        switch key {
        case .up, .backTab: keyboardActive = true; move(-1)
        case .down, .tab: keyboardActive = true; move(1)
        case .space: keyboardActive = true; activate()  // toggle the focused row
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
