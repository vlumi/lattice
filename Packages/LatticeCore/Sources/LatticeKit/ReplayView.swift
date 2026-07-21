import LatticeCore
import SwiftUI

/// Steps through a recorded game. Seeking replays or undoes moves through
/// the live engine, so what you scrub is always a legal position.
final class ReplayModel: ObservableObject {
    /// Fast cascade — step manually to study individual moves.
    private static let autoplayInterval: TimeInterval = 0.15

    let record: GameRecord
    @Published private(set) var game: Game
    @Published private(set) var step: Int
    @Published private(set) var isPlaying = false

    private var timer: Timer?

    init(record: GameRecord) {
        self.record = record
        var replayed = Game(rules: record.rules, start: record.start)
        for move in record.moves where replayed.play(move) {}
        game = replayed
        step = replayed.moves.count
    }

    deinit {
        timer?.invalidate()
    }

    var totalSteps: Int { record.moves.count }

    /// Manual seeking pauses autoplay — the user took the controls.
    func seek(to target: Int) {
        pause()
        move(to: target)
    }

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func play() {
        guard totalSteps > 0 else { return }
        // Play at the end means "run the whole game again".
        if step == totalSteps { move(to: 0) }
        isPlaying = true
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.autoplayInterval, repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    private func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        move(to: step + 1)
        if step == totalSteps { pause() }
    }

    private func move(to target: Int) {
        let clamped = min(max(target, 0), totalSteps)
        while step < clamped, game.play(record.moves[step]) {
            step += 1
        }
        while step > clamped, game.undo() != nil {
            step -= 1
        }
    }
}

public struct ReplayView: View {
    @StateObject private var model: ReplayModel

    public init(record: GameRecord) {
        _model = StateObject(wrappedValue: ReplayModel(record: record))
    }

    public var body: some View {
        VStack(spacing: 12) {
            ReplayBoardView(game: model.game)
            controls
        }
        .padding()
        .navigationTitle(
            Text("Replay — \(model.record.score)", bundle: .module))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                model.togglePlay()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(model.totalSteps == 0)
            Button {
                model.seek(to: 0)
            } label: {
                Image(systemName: "backward.end")
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            Button {
                model.seek(to: model.step - 1)
            } label: {
                Image(systemName: "backward.frame")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(model.step == 0)
            Slider(
                value: Binding(
                    get: { Double(model.step) },
                    set: { model.seek(to: Int($0.rounded())) }),
                in: 0...Double(max(model.totalSteps, 1))
            )
            Button {
                model.seek(to: model.step + 1)
            } label: {
                Image(systemName: "forward.frame")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(model.step == model.totalSteps)
            Button {
                model.seek(to: model.totalSteps)
            } label: {
                Image(systemName: "forward.end")
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            Text("\(model.step)/\(model.totalSteps)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// Read-only board render for replays: dots, lines, last line in accent —
/// no pinpoints or input; auto-fits its content each step.
struct ReplayBoardView: View {
    let game: Game

    var body: some View {
        Canvas { context, size in
            let layout = Layout(fitting: Bounds(of: game.dots), in: size)
            let lastLine = game.moves.last?.line
            for move in game.moves {
                guard let first = move.line.points.first, let last = move.line.points.last
                else { continue }
                var path = Path()
                path.move(to: layout.position(of: first))
                path.addLine(to: layout.position(of: last))
                let isLast = move.line == lastLine
                context.stroke(
                    path,
                    with: isLast ? .style(.tint) : .style(.primary.opacity(0.75)),
                    style: StrokeStyle(lineWidth: layout.lineWidth, lineCap: .round))
            }
            for dot in game.dots {
                let center = layout.position(of: dot)
                let casing = layout.casingRadius
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: center.x - casing, y: center.y - casing,
                            width: casing * 2, height: casing * 2)),
                    with: .style(.background))
                let radius = layout.dotRadius
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: center.x - radius, y: center.y - radius,
                            width: radius * 2, height: radius * 2)),
                    with: .style(.primary))
            }
        }
    }
}
