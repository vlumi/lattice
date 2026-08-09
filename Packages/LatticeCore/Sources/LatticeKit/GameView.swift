import Charts
import LatticeCore
import SwiftUI

/// One game screen (free or daily): score header, the board, end state.
public struct GameView: View {
    @ObservedObject private var session: GameSession
    @StateObject private var camera = BoardCamera()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var feedback: Feedback
    @State private var exportDocument: PNGDocument?
    @State private var isExporting = false
    @State private var isShowingChallenge = false
    @State private var isScanning = false
    @State private var isShowingNearby = false
    @State private var isShowingNewGame = false
    /// App-wide "show keyboard shortcuts" state, owned by RootView (drives the
    /// board cheatsheet + control badges here, tab badges there).
    @Binding private var showShortcuts: Bool

    public init(session: GameSession, showShortcuts: Binding<Bool> = .constant(false)) {
        self.session = session
        _showShortcuts = showShortcuts
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            BoardView(
                session: session, camera: camera,
                keyboardEnabled: !isShowingNewGame && !showShortcuts && !isShowingChallenge
            )
            // Undo and Fit float over the board (bottom-trailing) rather
            // than crowding the header — the frequent in-game actions sit
            // under the thumb, near what they affect.
            .overlay(alignment: .bottomTrailing) {
                BoardControls(session: session, camera: camera, showShortcuts: showShortcuts)
            }
            // At most one overlay at a time.
            .overlay {
                if showShortcuts && !isShowingNewGame {
                    KeyboardCheatsheet { showShortcuts = false }
                }
            }
            .overlay {
                if isShowingNewGame { newGameModal }
            }
            if session.pbCurve != nil {
                ghost
            }
            if session.isOver {
                gameOver
            }
        }
        .padding()
        // Overlay dismissals live here at window level: hidden shortcut buttons
        // inside an .overlay/.popover don't reliably receive keys.
        .background(overlayDismissKeys)
        // RootView's app-wide "?" can't see the modal; keep the cheatsheet off
        // while it's up so the two don't coexist.
        .onChangeCompat(of: showShortcuts) { on in
            if on && isShowingNewGame { showShortcuts = false }
        }
        // The game-over feedback (sound + a neutral notification haptic) — the
        // plain end-state was easy to miss. Fire once, on the transition to
        // over (onChangeCompat bridges the iOS-16 floor).
        .onChangeCompat(of: session.isOver) { isOver in
            if isOver { feedback.gameOver() }
        }
        .sheet(isPresented: $isShowingNearby) {
            NearbyDuelView(name: PlayerName.current(), bests: session.bests)
        }
        #if os(iOS)
        .sheet(isPresented: $isScanning) {
            NavigationStack {
                CodeScannerView { payload in
                    // The QR encodes the universal link; accept a bare
                    // code too.
                    let seed =
                        URL(string: payload).flatMap(ChallengeLink.seed(from:))
                        ?? SeedCode.decode(payload)
                    guard let seed else { return }
                    isScanning = false
                    session.newChallenge(seed: seed)
                    camera.reset()
                }
                .ignoresSafeArea()
                .navigationTitle(Text("Scan Code", bundle: .module))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button {
                        isScanning = false
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
            }
        }
        #endif
    }

    // The personal-best ghost: the PB game's openness curve dimmed under
    // the live game's — "is my position more alive than my best game was
    // at this point?" A pace race, not a board overlay: two games' dots on
    // one board would fight the visual identity.
    private var ghost: some View {
        Chart {
            if let pbCurve = session.pbCurve {
                ForEach(Array(pbCurve.enumerated()), id: \.offset) { index, count in
                    LineMark(
                        x: .value("Move", index),
                        y: .value("Open", count),
                        series: .value("Series", "best")
                    )
                    .foregroundStyle(.primary.opacity(0.2))
                }
            }
            ForEach(Array(session.opennessHistory.enumerated()), id: \.offset) { index, count in
                LineMark(
                    x: .value("Move", index),
                    y: .value("Open", count),
                    series: .value("Series", "live")
                )
                .foregroundStyle(.primary.opacity(0.6))
            }
            if let current = session.opennessHistory.last {
                PointMark(
                    x: .value("Move", session.opennessHistory.count - 1),
                    y: .value("Open", current)
                )
                .foregroundStyle(.tint)
            }
        }
        .chartXScale(
            domain: 0...max(session.pbCurve?.count ?? 1, session.opennessHistory.count, 2)
        )
        .frame(height: 80)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Score: \(session.game.score)", bundle: .module)
                .font(.headline.monospacedDigit())
            if session.mode == .passAndPlay {
                // The turn chip: the current player's colour, filled — the
                // same colour the board's interactive accent and their drawn
                // lines wear.
                if !session.isOver {
                    playerChip(
                        session.playerToMove,
                        label: Text("Player \(session.playerToMove) to move", bundle: .module))
                }
                // Live same-room duel — the one online mode. Distinct from
                // pass-and-play's shared device; a match is its own event.
                Button {
                    isShowingNearby = true
                } label: {
                    Image(systemName: "person.line.dotted.person.fill")
                }
                .keyboardShortcut("d", modifiers: .command)
                .accessibilityLabel(Text("Nearby", bundle: .module))
            } else if session.mode == .daily, session.dailyStreak > 0 {
                Text(
                    "Streak: \(session.dailyStreak) (best \(session.dailyLongestStreak))",
                    bundle: .module
                )
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            } else if let best = session.best {
                Text("Best: \(best)", bundle: .module)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let code = session.seedCode, let seed = session.seed {
                Button {
                    isShowingChallenge = true
                } label: {
                    Label {
                        Text(verbatim: code)
                    } icon: {
                        Image(systemName: "qrcode")
                    }
                    .font(.subheadline.monospaced())
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .accessibilityLabel(Text("Share challenge", bundle: .module))
                // Popover on Mac/iPad; adapts to a sheet on iPhone (the
                // compact-popover modifier needs iOS 16.4; floor is 16.0).
                .popover(isPresented: $isShowingChallenge) {
                    ChallengeShareView(
                        code: code, url: ChallengeLink.url(for: seed),
                        dismiss: { isShowingChallenge = false }
                    )
                    .padding()
                    .presentationDetents([.medium])
                }
            }
            Spacer()
            // Always present (hidden when there's nothing to cancel) so the
            // header's size stays constant — otherwise the button appearing
            // reflowed the row and nudged the board's fitted size (a wobble).
            Button {
                session.cancel()
            } label: {
                Text("Cancel", bundle: .module)
            }
            // Claim Esc only when there's a move to cancel — a disabled button
            // still swallows its shortcut on macOS, which ate overlays' Esc.
            .keyboardShortcut(session.tentative == nil ? nil : .cancelAction)
            .disabled(session.tentative == nil)
            .opacity(session.tentative == nil ? 0 : 1)
            if session.mode != .daily {
                // Restart the same board. Disabled on an unplayed board: nothing
                // to restart, and it blocks a mis-tap toward Undo.
                Button {
                    session.newGame()
                    camera.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(session.game.moves.isEmpty)
                .accessibilityLabel(Text("Restart", bundle: .module))
            }
            if session.mode == .free {
                Button {
                    showShortcuts = false
                    isShowingNewGame = true
                } label: {
                    Label {
                        Text(verbatim: session.variantKey)
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .fixedSize()
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityLabel(Text("New Game", bundle: .module))
                .accessibilityValue(Text(verbatim: session.variantKey))
            }
        }
    }

    @ViewBuilder private var overlayDismissKeys: some View {
        if isShowingChallenge {
            HiddenShortcut(key: .escape) { isShowingChallenge = false }
        }
        if isShowingNewGame {
            HiddenShortcut(key: .escape) { isShowingNewGame = false }
        }
    }

    private var newGameModal: some View {
        NewGameModal(
            session: session,
            dismiss: { isShowingNewGame = false },
            onVariant: { rules in
                session.newGame(rules: rules)
                camera.reset()
            },
            onRandom: {
                session.newChallenge(seed: SeedCode.randomSeed())
                camera.reset()
            },
            onCode: { seed in
                session.newChallenge(seed: seed)
                camera.reset()
            },
            onScan: scanAction)
    }

    /// The iOS scanner action, if the device supports it (nil otherwise / macOS).
    private var scanAction: (() -> Void)? {
        #if os(iOS)
        guard CodeScannerView.isSupported else { return nil }
        return {
            isShowingNewGame = false
            isScanning = true
        }
        #else
        return nil
        #endif
    }

    private var gameOver: some View {
        HStack(spacing: 12) {
            Group {
                if let winner = session.winner {
                    playerChip(
                        winner,
                        label: Text(
                            "Player \(winner) wins — \(session.game.score) lines",
                            bundle: .module))
                } else if session.mode == .daily {
                    Text("Done for today — final score \(session.game.score)", bundle: .module)
                } else {
                    Text("No moves left — final score \(session.game.score)", bundle: .module)
                }
            }
            .font(.title3.weight(.semibold))
            if let image = shareImage {
                ShareLink(
                    item: image,
                    preview: SharePreview(
                        Text("Lattice Five — \(session.game.score)", bundle: .module),
                        image: image)
                )
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            Button {
                exportDocument = ShareCard.pngData(game: session.game, subtitle: cardSubtitle)
                    .map(PNGDocument.init)
                isExporting = exportDocument != nil
            } label: {
                Text("Save Image", bundle: .module)
            }
            .keyboardShortcut("s", modifiers: .command)
            .fileExporter(
                isPresented: $isExporting, document: exportDocument,
                contentType: .png, defaultFilename: exportFilename
            ) { _ in
                exportDocument = nil
            }
        }
    }

    private func playerChip(_ player: Int, label: Text) -> some View {
        label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(PlayerStyle.color(for: player, scheme: colorScheme)))
    }
}

// Share-card / export text for the game-over row.
extension GameView {
    fileprivate var cardSubtitle: String {
        session.dailyKey.map { key in
            String(localized: "Daily \(key) — score \(session.game.score)", bundle: .module)
        }
            ?? String(localized: "Score \(session.game.score)", bundle: .module)
    }

    fileprivate var exportFilename: String {
        session.dailyKey.map { "lattice-daily-\($0)-\(session.game.score)" }
            ?? "lattice-\(session.game.score)"
    }

    fileprivate var shareImage: Image? {
        ShareCard.render(game: session.game, subtitle: cardSubtitle)
    }
}

/// The challenge hand-off: scan the QR (it's the universal link), share the
/// link, or read the code aloud — three transports for the same seed.
private struct ChallengeShareView: View {
    let code: String
    let url: URL
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let qr = QRCode.image(for: url.absoluteString) {
                qr
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .accessibilityLabel(Text("Challenge QR code", bundle: .module))
            }
            Text(verbatim: code)
                .font(.title3.monospaced().weight(.semibold))
                .textSelection(.enabled)
            ShareLink(item: url) {
                Label {
                    Text("Share Challenge", bundle: .module)
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            // Esc lives on the parent (see challengePopoverKeys); this is the
            // click affordance.
            Button(action: dismiss) {
                Text("Done", bundle: .module)
            }
        }
    }
}
