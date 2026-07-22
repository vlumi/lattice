import Charts
import LatticeCore
import SwiftUI

/// One game screen (free or daily): score header, the board, end state.
public struct GameView: View {
    @ObservedObject private var session: GameSession
    @StateObject private var camera = BoardCamera()
    @State private var exportDocument: PNGDocument?
    @State private var isExporting = false
    @State private var isEnteringCode = false
    @State private var codeInput = ""

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            BoardView(session: session, camera: camera)
            if session.pbCurve != nil {
                ghost
            }
            if session.isOver {
                gameOver
            }
        }
        .padding()
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
        HStack {
            Text("Score: \(session.game.score)", bundle: .module)
                .font(.headline.monospacedDigit())
            if session.mode == .daily, session.dailyStreak > 0 {
                Text("Streak: \(session.dailyStreak)", bundle: .module)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let best = session.best {
                Text("Best: \(best)", bundle: .module)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let code = session.seedCode {
                Text("Code: \(code)", bundle: .module)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if !camera.isIdentity {
                Button {
                    camera.reset()
                } label: {
                    Text("Fit", bundle: .module)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            if session.tentative != nil {
                Button {
                    session.cancel()
                } label: {
                    Text("Cancel", bundle: .module)
                }
                .keyboardShortcut(.cancelAction)
            }
            Button {
                session.undo()
            } label: {
                Text("Undo", bundle: .module)
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!session.undoAllowed)
            if session.mode == .free {
                Button {
                    session.newGame()
                    camera.reset()
                } label: {
                    Text("New Game", bundle: .module)
                }
                .keyboardShortcut("n", modifiers: .command)
                // Switching variant starts a new game of it.
                Menu {
                    ForEach(Rules.selectable, id: \.self) { rules in
                        Button {
                            session.newGame(rules: rules)
                            camera.reset()
                        } label: {
                            if rules.storageKey == session.variantKey {
                                Label(rules.storageKey, systemImage: "checkmark")
                            } else {
                                Text(verbatim: rules.storageKey)
                            }
                        }
                    }
                    Divider()
                    Button {
                        session.newChallenge(seed: SeedCode.randomSeed())
                        camera.reset()
                    } label: {
                        Text("Random Start (5T#)", bundle: .module)
                    }
                    Button {
                        codeInput = ""
                        isEnteringCode = true
                    } label: {
                        Text("Enter Code…", bundle: .module)
                    }
                } label: {
                    Text(verbatim: session.variantKey)
                }
                .menuStyle(.button)
                .fixedSize()
                .alert(
                    Text("Enter Code", bundle: .module), isPresented: $isEnteringCode
                ) {
                    TextField(text: $codeInput) {
                        Text("Code", bundle: .module)
                    }
                    Button {
                        if let seed = SeedCode.decode(codeInput) {
                            session.newChallenge(seed: seed)
                            camera.reset()
                        }
                    } label: {
                        Text("Play", bundle: .module)
                    }
                    Button(role: .cancel) {
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
            }
        }
    }

    private var gameOver: some View {
        HStack(spacing: 12) {
            Group {
                if session.mode == .daily {
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
                        image: image))
            }
            Button {
                exportDocument = ShareCard.pngData(game: session.game, subtitle: cardSubtitle)
                    .map(PNGDocument.init)
                isExporting = exportDocument != nil
            } label: {
                Text("Save Image", bundle: .module)
            }
            .fileExporter(
                isPresented: $isExporting, document: exportDocument,
                contentType: .png, defaultFilename: exportFilename
            ) { _ in
                exportDocument = nil
            }
        }
    }

    private var cardSubtitle: String {
        session.dailyKey.map { key in
            String(localized: "Daily \(key) — score \(session.game.score)", bundle: .module)
        }
            ?? String(localized: "Score \(session.game.score)", bundle: .module)
    }

    private var exportFilename: String {
        session.dailyKey.map { "lattice-daily-\($0)-\(session.game.score)" }
            ?? "lattice-\(session.game.score)"
    }

    private var shareImage: Image? {
        ShareCard.render(game: session.game, subtitle: cardSubtitle)
    }
}

/// The app root: Free, Daily, and History as tabs — the game tabs keep
/// their sessions and cameras alive across switches, all over one store.
public struct RootView: View {
    private enum Tab {
        case free
        case daily
        case history
    }

    private static let store = LatticeStore.appSupport()

    @StateObject private var freeSession = GameSession(mode: .free, store: store)
    @StateObject private var dailySession = GameSession(mode: .daily, store: store)
    @State private var selection: Tab = .free
    @State private var historyPath = NavigationPath()

    public init() {}

    public var body: some View {
        // Arriving at the History tab (or re-tapping it, where the platform
        // reports that) always lands on the list, not a parked replay.
        let selectionResettingHistory = Binding(
            get: { selection },
            set: { (newValue: Tab) in
                if newValue == .history { historyPath = NavigationPath() }
                selection = newValue
            })
        TabView(selection: selectionResettingHistory) {
            GameView(session: freeSession)
                .tabItem { Text("Free", bundle: .module) }
                .tag(Tab.free)
            GameView(session: dailySession)
                .tabItem { Text("Daily", bundle: .module) }
                .tag(Tab.daily)
            HistoryView(store: Self.store, path: $historyPath)
                .tabItem { Text("History", bundle: .module) }
                .tag(Tab.history)
        }
    }
}
