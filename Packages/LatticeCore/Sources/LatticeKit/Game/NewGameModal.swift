import LatticeCore
import SwiftUI

/// New Game chooser: pick a variant, a random start, or a code, then Start.
/// Every row is a selector; only Start launches. Keyboard: Up/Down move rows,
/// Left/Right pick a variant, Return/Space start. (Esc-to-close is bound by the
/// presenting GameView — keys don't reach a hidden button inside an overlay.)
struct NewGameModal: View {
    @ScaledMetric(relativeTo: .body) private var codeFieldWidth: CGFloat = 120
    @ObservedObject var session: GameSession
    let dismiss: () -> Void
    let onVariant: (Rules) -> Void
    let onRandom: () -> Void
    let onCode: (UInt64) -> Void
    /// iOS scanner (nil where unsupported).
    let onScan: (() -> Void)?

    /// The picked mode; the variant index tracks which chip in the variant row
    /// is selected (so Left/Right and the default both address it). Start isn't
    /// a row — Return/Space commits whatever's picked here.
    private enum Row: Int, CaseIterable { case variant, random, code }

    @State private var row: Row = .variant
    @State private var variantIndex = 0
    @State private var code = ""
    @FocusState private var codeFocused: Bool

    private var variantKeys: [String] { Rules.selectable.map(\.storageKey) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
            card
        }
        #if os(macOS)
        .background(KeyCatcher(onKey: handle, yieldsToTextFields: true))
        #endif
        .onAppear {
            // Preselect what's playing: a seeded game → Random, else its variant.
            if session.seed != nil {
                row = .random
            } else {
                row = .variant
                variantIndex = variantKeys.firstIndex(of: session.variantKey) ?? 0
            }
        }
    }

    #if os(macOS)
    private func handle(_ key: KeyCatcher.Key) {
        if codeFocused {
            leaveCodeField(key)
            return
        }
        switch key {
        case .up: move(-1)
        case .down, .tab: move(1)
        case .backTab: move(-1)
        case .left: stepVariant(-1)
        case .right: stepVariant(1)
        case .enter, .space: activate()
        case .escape: dismiss()
        default: break
        }
    }

    // KeyCatcher hands focus back and forwards Enter/Esc/Tab from the code field.
    // Enter starts; Esc/Tab step back to row nav (never close the modal).
    private func leaveCodeField(_ key: KeyCatcher.Key) {
        switch key {
        case .enter: codeFocused = false; start()
        case .escape, .tab, .backTab: codeFocused = false; row = .code
        default: break
        }
    }
    #endif

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            variantRow
            randomRow
            codeRow
            startRow
        }
        .padding(20)
        .fixedSize()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
    }

    private var header: some View {
        HStack {
            Text("New Game", bundle: .module).font(.headline)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close", bundle: .module))
        }
    }

    private var variantRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Variant", bundle: .module).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Array(variantKeys.enumerated()), id: \.element) { index, storageKey in
                    chip(storageKey, selected: row == .variant && variantIndex == index) {
                        row = .variant
                        variantIndex = index
                    }
                }
            }
            // "5T" means nothing to a newcomer, and five chips leave no room for
            // per-chip text — so one line under the row explains whichever is
            // selected, and changes as you move along it.
            Self.variantSummary(for: variantKeys[variantIndex])
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
        }
        .rowCursor(row == .variant)
    }

    /// One line per variant: what it is, not how it works. The rules themselves
    /// are in How to play. Every key in `Rules.selectable` must appear here —
    /// see VariantSummaryTests, which fails on a missing one rather than letting
    /// the modal render a blank line.
    static func variantSummary(for storageKey: String) -> Text {
        switch storageKey {
        case "5T":
            return Text(
                "The classic game — lines of five, sharing end dots allowed.",
                bundle: .module)
        case "5T+":
            return Text(
                "Relaxed: a dot and its line come apart, so more moves fit.",
                bundle: .module)
        case "5D":
            return Text(
                "Stricter: lines in the same direction may not touch at all.",
                bundle: .module)
        case "4T":
            return Text(
                "Shorter, with lines of four — solved, so 62 is perfect.", bundle: .module)
        case "4D":
            return Text("Shorter and strict — solved, so 35 is perfect.", bundle: .module)
        default:
            return Text(verbatim: "")
        }
    }

    private var randomRow: some View {
        chip(selected: row == .random) {
            row = .random
        } label: {
            Label {
                Text("Random Start (5T#)", bundle: .module)
            } icon: {
                Image(systemName: "shuffle")
            }
        }
        .rowCursor(row == .random)
    }

    private var codeRow: some View {
        // From Code selects the code row (before the field); typing does too.
        HStack(spacing: 8) {
            chip(selected: row == .code) {
                row = .code
            } label: {
                Text("From Code", bundle: .module)
            }
            TextField(text: $code) {
                Text("Code", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .frame(width: codeFieldWidth)
            .focused($codeFocused)
            .onChangeCompat(of: code) { _ in row = .code }
            .onSubmit(start)  // iOS Return; on macOS KeyCatcher owns the field keys
            if let onScan {
                Button(action: onScan) {
                    Label {
                        Text("Scan Code…", bundle: .module)
                    } icon: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
            }
        }
        .rowCursor(row == .code)
    }

    private var startRow: some View {
        HStack {
            Spacer()
            Button(action: dismiss) {
                Text("Cancel", bundle: .module)
            }
            Button(action: start) {
                Text("Start", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart)
        }
    }

    private var canStart: Bool {
        switch row {
        case .variant, .random: return true
        case .code: return SeedCode.decode(code) != nil
        }
    }

    // MARK: Keyboard moves

    private func move(_ step: Int) {
        let all = Row.allCases
        let current = row.rawValue
        row = all[min(max(current + step, 0), all.count - 1)]
    }

    private func stepVariant(_ step: Int) {
        guard row == .variant else { return }
        variantIndex = min(max(variantIndex + step, 0), variantKeys.count - 1)
    }

    /// Return/Space: on the code row, focus the field to type; otherwise start.
    private func activate() {
        if row == .code {
            codeFocused = true
        } else {
            start()
        }
    }

    private func start() {
        switch row {
        case .variant:
            let key = variantKeys[variantIndex]
            if let rules = Rules.selectable.first(where: { $0.storageKey == key }) {
                onVariant(rules)
            }
        case .random:
            onRandom()
        case .code:
            guard let seed = SeedCode.decode(code) else { return }
            onCode(seed)
        }
        dismiss()
    }

    /// A selectable text chip.
    private func chip(_ title: String, selected: Bool, _ select: @escaping () -> Void)
        -> some View
    {
        Button(action: select) {
            Text(verbatim: title).frame(minWidth: 36)
        }
        .buttonStyle(.bordered)
        .tint(selected ? .accentColor : nil)
    }

    /// A selectable chip with a custom label.
    private func chip(
        selected: Bool, _ select: @escaping () -> Void, @ViewBuilder label: () -> some View
    ) -> some View {
        Button(action: select, label: label)
            .buttonStyle(.bordered)
            .tint(selected ? .accentColor : nil)
    }
}
