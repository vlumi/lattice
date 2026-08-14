import Charts
import LatticeCore
import SwiftUI

/// One game screen (free or daily): score header, the board, end state.
public struct GameView: View {
    @ObservedObject var session: GameSession
    /// The shared app model — this view acts on menu-command intents only when
    /// it's the selected tab (`model.selection == tab`).
    @ObservedObject var model: AppModel
    private let tab: AppModel.Tab
    @StateObject var camera = BoardCamera()
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var feedback: Feedback
    @State var exportDocument: PNGDocument?
    @State var isExporting = false
    @State var isShowingChallenge = false
    @State var isScanning = false
    @State var isShowingNearby = false
    @State var isShowingNewGame = false
    /// App-wide "show keyboard shortcuts" state, owned by RootView (drives the
    /// board cheatsheet + control badges here, tab badges there).
    @Binding var showShortcuts: Bool

    public init(
        session: GameSession, model: AppModel, tab: AppModel.Tab,
        showShortcuts: Binding<Bool> = .constant(false)
    ) {
        self.session = session
        self.model = model
        self.tab = tab
        _showShortcuts = showShortcuts
    }

    /// Lags `session.isGenerating` so a fast generate never flashes a spinner.
    @StateObject var busy = BusyIndicator()

    private var isActive: Bool { model.selection == tab }

    // What the Game menu's Share Challenge / Save Image enable on — recomputed
    // for the active tab whenever any input changes.
    private var menuAvailability: [Bool] {
        [isActive, session.seedCode != nil, session.isOver]
    }
    private func publishAvailability() {
        guard isActive else { return }
        model.canShareChallenge = session.seedCode != nil
        model.isGameOver = session.isOver
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            BoardView(
                session: session, camera: camera,
                keyboardEnabled: !isShowingNewGame && !showShortcuts && !isShowingChallenge
                    && !session.isGenerating
            )
            // Undo and Fit float over the board (bottom-trailing) rather
            // than crowding the header — the frequent in-game actions sit
            // under the thumb, near what they affect.
            .overlay(alignment: .bottomTrailing) {
                BoardControls(
                    session: session, camera: camera, showShortcuts: showShortcuts,
                    onHelp: { model.isShowingHowTo = true })
            }
            // At most one overlay at a time.
            // Generating a seeded start takes a moment; the tap already closed
            // the modal, so say what's happening over the board. The outgoing
            // board stays visible but inert — it's about to be replaced.
            .disabled(session.isGenerating)
            .overlay {
                if busy.isVisible { generatingOverlay }
            }
            if session.pbCurve != nil {
                ghost
            }
            if session.isOver {
                gameOver
            }
        }
        .padding()
        // The modals overlay the WHOLE screen, not the board: as board overlays
        // their dim stopped at the header and the tab bar, leaving pale bands
        // around a supposedly-modal panel. Only one shows at a time.
        .overlay {
            if showShortcuts && !isShowingNewGame {
                KeyboardCheatsheet(
                    dismiss: { showShortcuts = false },
                    onHowTo: {
                        showShortcuts = false
                        model.isShowingHowTo = true
                    })
            }
        }
        .overlay {
            if isShowingNewGame { newGameModal }
        }
        .onChangeCompat(of: session.isGenerating) { busy.update(busy: $0) }
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
        // Menu-command intents (LatticeCommands), acted on only by the active
        // tab. Availability still gates each: New Game / Restart are free-mode
        // (non-daily) concerns, Nearby is versus.
        .onChangeCompat(of: model.newGameRequested) { _ in
            guard isActive, session.mode == .free else { return }
            showShortcuts = false
            isShowingNewGame = true
        }
        .onChangeCompat(of: model.restartRequested) { _ in
            guard isActive, session.mode != .daily, !session.game.moves.isEmpty else { return }
            session.newGame()
            camera.reset()
        }
        .onChangeCompat(of: model.undoRequested) { _ in
            guard isActive, session.undoAllowed else { return }
            session.undo()
        }
        .onChangeCompat(of: model.fitRequested) { _ in
            guard isActive else { return }
            camera.reset()
        }
        .onChangeCompat(of: model.nearbyRequested) { _ in
            guard isActive, session.mode == .passAndPlay else { return }
            isShowingNearby = true
        }
        .onChangeCompat(of: model.shareChallengeRequested) { _ in
            guard isActive, session.seedCode != nil else { return }
            isShowingChallenge = true
        }
        .onChangeCompat(of: model.saveImageRequested) { _ in
            guard isActive, session.isOver else { return }
            exportDocument = ShareCard.pngData(game: session.game, subtitle: cardSubtitle)
                .map(PNGDocument.init)
            isExporting = exportDocument != nil
        }
        // Keep the menu's availability for the active tab in sync.
        .onChangeCompat(of: menuAvailability) { _ in publishAvailability() }
        .onAppear { publishAvailability() }
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

}
