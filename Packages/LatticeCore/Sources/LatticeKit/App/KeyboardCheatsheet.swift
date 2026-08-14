import SwiftUI

/// "?" toggles the keyboard cheatsheet. A hidden shortcut button (the
/// iOS-16-safe pattern), placed as a background. Esc-to-close and mouse-close
/// live on the cheatsheet overlay itself (so its Esc only competes when shown).
struct ShortcutToggle: View {
    @Binding var showShortcuts: Bool

    var body: some View {
        Button {
            showShortcuts.toggle()
        } label: {
            Color.clear.frame(width: 1, height: 1)
        }
        .keyboardShortcut("?", modifiers: [])
        .opacity(0)
        .accessibilityHidden(true)
    }
}

/// A single key drawn as a rounded keycap.
struct Keycap: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(verbatim: label)
            .font(.footnote.monospaced().weight(.medium))
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(.quaternary)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.tertiary)))
    }
}

/// Four movement keys in the inverted-T layout (up over left-down-right).
private struct MovementCluster: View {
    let up: String
    let left: String
    let down: String
    let right: String

    var body: some View {
        VStack(spacing: 3) {
            Keycap(up)
            HStack(spacing: 3) {
                Keycap(left)
                Keycap(down)
                Keycap(right)
            }
        }
    }
}

/// The board-play keyboard cheatsheet, shown over the board while "?" is on
/// (Esc, "?", the ✕, or a tap-off hides it). Chrome controls get their own
/// inline shortcut badges; this panel covers the gameplay keys.
struct KeyboardCheatsheet: View {
    @ScaledMetric(relativeTo: .footnote) private var keyColumnWidth: CGFloat = 230
    let dismiss: () -> Void
    /// Opens the full rules guide — the cheatsheet is the quick reminder, this
    /// is the way to the depth behind it. Nil when Help is already what's open.
    var onHowTo: (() -> Void)?

    var body: some View {
        ZStack {
            // Tap-anywhere-off to close (mouse/touch dismissal).
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
            panel
        }
        // Esc closes it. Only in the tree while shown, so it wins over the
        // board's own Esc (which cancels a tentative during play).
        .background(
            Button(action: dismiss) { Color.clear.frame(width: 1, height: 1) }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Keyboard", bundle: .module).font(.headline)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close", bundle: .module))
            }

            // Movement: arrows and WASD as two inverted-T clusters, side by
            // side. Same key column as the rows below, so all labels align.
            row(
                HStack(spacing: 16) {
                    MovementCluster(up: "↑", left: "←", down: "↓", right: "→")
                    MovementCluster(up: "W", left: "A", down: "S", right: "D")
                }, Text("Move the cursor", bundle: .module))

            keyRow(["⏎", "space"], Text("Place a dot, then draw the line", bundle: .module))
            keyRow(["←", "→", "tab"], Text("Cycle the possible lines", bundle: .module))
            keyRow(["⌫"], Text("Undo", bundle: .module))
            keyRow(["esc"], Text("Cancel", bundle: .module))

            Divider()
            // Balloons, not keycaps: these point at the tab bar on screen, the
            // same "this key drives that control" sense the badges over Undo and
            // "?" carry. Spelled out rather than elided — there are only four,
            // and "⌘1 … ⌘5" both overcounted (Settings is not a tab here) and
            // made the reader guess the range.
            row(
                HStack(spacing: 4) {
                    ForEach(["⌘1", "⌘2", "⌘3", "⌘4"], id: \.self) { ShortcutBadge($0) }
                }, Text("Switch tabs", bundle: .module))
            if let onHowTo {
                Button(action: onHowTo) {
                    Label {
                        Text("How to play", bundle: .module)
                    } icon: {
                        Image(systemName: "questionmark.circle")
                    }
                    .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .fixedSize()  // hug the content — don't stretch to fill the board overlay
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
    }

    /// Shared width for the key column — wide enough for the two movement
    /// clusters so every label to the right aligns and nothing overflows.

    private func keyRow(_ keys: [String], _ label: Text) -> some View {
        row(
            HStack(spacing: 3) { ForEach(keys, id: \.self) { Keycap($0) } },
            label)
    }

    /// One cheatsheet row: keys centered in a column, label after. The column
    /// scales with the text size — the keycaps inside it grow too, and a fixed
    /// width would clip the longest chords at accessibility sizes.
    private func row(_ keys: some View, _ label: Text) -> some View {
        HStack(alignment: .center, spacing: 16) {
            keys.frame(width: keyColumnWidth, alignment: .center)
            label.font(.callout).foregroundStyle(.secondary)
        }
    }
}
