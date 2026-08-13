import LatticeCore
import SwiftUI

/// The in-app rules reference: mostly pictures, a couple of sentences each.
///
/// Deliberately a *reference*, not a scripted tutorial — Morpion is one rule
/// plus two corollaries, so forced-move hand-holding would be more machinery
/// than content, and it would gate the free exploration that is the game. The
/// segment rule in particular is unlearnable as prose, which is why every
/// section leads with a `BoardDiagram` drawn in the board's own vocabulary.
struct HowToPlayView: View {
    /// Opens the keyboard cheatsheet; nil hides that row (touch-only hosts).
    var onKeyboard: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                goal
                theMove
                segmentRule
                noFreeLines
                deadGaps
                variants
                if let onKeyboard {
                    Divider()
                    Button(action: onKeyboard) {
                        Label {
                            Text("Keyboard shortcuts", bundle: .module)
                        } icon: {
                            Image(systemName: "keyboard")
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
            }
            .padding(20)
            // maxWidth keeps the prose readable on a wide window; the
            // frame must FILL a narrow one, or the wider diagrams push the
            // whole column out of view and clip the leading edge.
            .frame(maxWidth: 520, alignment: .topLeading)
        }
    }

    // MARK: Sections

    private var goal: some View {
        section(
            Text("The goal", bundle: .module),
            Text(
                """
                Every move places one new dot and draws a line through five \
                dots in a row. Keep going as long as you can — your score is \
                the number of lines you draw.
                """, bundle: .module)
        ) {
            BoardDiagram(
                dots: cross,
                marks: [.init(BoardDiagram.line(Point(-1, 2), .horizontal), .fresh)],
                highlight: [Point(-1, 2)],
                bounds: Bounds(minX: -3, maxX: 3, minY: -3, maxY: 3))
        }
    }

    private var theMove: some View {
        section(
            Text("Placing a dot, drawing a line", bundle: .module),
            Text(
                """
                Tap an empty point to place a dot, and the lines it makes \
                possible appear. Tap the one you want to draw it. The line can \
                run in any of the four directions, and your new dot can sit \
                anywhere along it — not just at the end.
                """, bundle: .module)
        ) {
            pair(
                captioned(Text("Place", bundle: .module)) {
                    BoardDiagram(
                        dots: fiveRun,
                        marks: [
                            .init(BoardDiagram.line(Point(-2, 0), .horizontal), .possible)
                        ],
                        highlight: [Point(2, 0)],
                        bounds: Bounds(minX: -3, maxX: 3, minY: -1, maxY: 1))
                },
                captioned(Text("Draw", bundle: .module)) {
                    BoardDiagram(
                        dots: fiveRun,
                        marks: [.init(BoardDiagram.line(Point(-2, 0), .horizontal), .fresh)],
                        bounds: Bounds(minX: -3, maxX: 3, minY: -1, maxY: 1))
                }
            )
        }
    }

    private var segmentRule: some View {
        section(
            Text("Lines may touch, but never overlap", bundle: .module),
            Text(
                """
                Two lines along the same direction may share an end dot, but \
                they can never share a stretch between two dots. This is the \
                rule the whole game turns on: every line you draw uses up four \
                of those stretches for good.
                """, bundle: .module)
        ) {
            pair(
                captioned(Text("Allowed", bundle: .module)) {
                    BoardDiagram(
                        dots: BoardDiagram.row(0, from: -4, count: 9),
                        marks: [
                            .init(BoardDiagram.line(Point(-4, 0), .horizontal), .played),
                            .init(BoardDiagram.line(Point(0, 0), .horizontal), .fresh),
                        ],
                        bounds: Bounds(minX: -5, maxX: 5, minY: -1, maxY: 1))
                },
                captioned(Text("Not allowed", bundle: .module)) {
                    BoardDiagram(
                        dots: BoardDiagram.row(0, from: -4, count: 8),
                        marks: [
                            .init(BoardDiagram.line(Point(-4, 0), .horizontal), .played),
                            .init(BoardDiagram.line(Point(-1, 0), .horizontal), .forbidden),
                        ],
                        bounds: Bounds(minX: -5, maxX: 5, minY: -1, maxY: 1))
                }
            )
        }
    }

    private var noFreeLines: some View {
        section(
            Text("Every line needs a new dot", bundle: .module),
            Text(
                """
                Five dots already in a row are not a line — a move has to add a \
                dot, and the line has to run through that dot. So if one \
                placement opens up two lines, you draw one and lose the other.
                """, bundle: .module)
        ) {
            BoardDiagram(
                dots: fiveRun.union([Point(3, 0)]),
                marks: [.init(BoardDiagram.line(Point(-2, 0), .horizontal), .forbidden)],
                bounds: Bounds(minX: -3, maxX: 4, minY: -1, maxY: 1))
        }
    }

    private var deadGaps: some View {
        section(
            Text("Gaps you close off", bundle: .module),
            Text(
                """
                When two of your lines end up a few dots apart along the same \
                direction, nothing can ever span the space between them. The \
                board marks those dead gaps faintly in red, live and in \
                replays — a quiet note that some room went to waste.
                """, bundle: .module)
        ) {
            BoardDiagram(
                dots: BoardDiagram.row(0, from: -6, count: 5)
                    .union(BoardDiagram.row(0, from: 1, count: 5)),
                marks: [
                    .init(BoardDiagram.line(Point(-6, 0), .horizontal), .played),
                    .init(BoardDiagram.line(Point(1, 0), .horizontal), .played),
                    // The dead span itself, as the board draws it.
                    .init(BoardDiagram.line(Point(-2, 0), .horizontal, 4), .forbidden),
                ],
                bounds: Bounds(minX: -6, maxX: 5, minY: -1, maxY: 1),
                cell: 13)
        }
    }

    private var variants: some View {
        section(
            Text("Variants", bundle: .module),
            Text(
                """
                **5T** is the classic game: lines may share an end dot. **5D** \
                is stricter — lines along the same direction may not touch at \
                all. **4T** and **4D** use lines of four from a smaller start, \
                and are short enough to solve. **5T+** loosens up: the dot and \
                the line come apart, so five dots already in a row do count.
                """, bundle: .module)
        ) {
            pair(
                captioned(Text("5T", bundle: .module)) {
                    BoardDiagram(
                        dots: BoardDiagram.row(0, from: -4, count: 9),
                        marks: [
                            .init(BoardDiagram.line(Point(-4, 0), .horizontal), .played),
                            .init(BoardDiagram.line(Point(0, 0), .horizontal), .fresh),
                        ],
                        bounds: Bounds(minX: -5, maxX: 5, minY: -1, maxY: 1))
                },
                captioned(Text("5D", bundle: .module)) {
                    BoardDiagram(
                        dots: BoardDiagram.row(0, from: -4, count: 9),
                        marks: [
                            .init(BoardDiagram.line(Point(-4, 0), .horizontal), .played),
                            .init(BoardDiagram.line(Point(0, 0), .horizontal), .forbidden),
                        ],
                        bounds: Bounds(minX: -5, maxX: 5, minY: -1, maxY: 1))
                }
            )
        }
    }

    // MARK: Building blocks

    /// The standard cross start, trimmed to the diagram window.
    private var cross: Set<Point> {
        StartingPattern.standardCross.filter {
            abs($0.x) <= 3 && abs($0.y) <= 3
        }
    }

    private var fiveRun: Set<Point> { BoardDiagram.row(0, from: -2, count: 5) }

    private func section(
        _ title: Text, _ body: Text, @ViewBuilder diagram: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            title.font(.headline)
            diagram()
            body.font(.callout).foregroundStyle(.secondary)
        }
    }

    /// Two labelled diagrams side by side, stacking when the width won't take
    /// them — the pairs are the widest thing in here.
    private func pair(_ a: some View, _ b: some View) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                a; b
            }
            VStack(alignment: .leading, spacing: 12) {
                a; b
            }
        }
    }

    private func captioned(_ label: Text, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 4) {
            content()
            label.font(.caption2).foregroundStyle(.secondary)
        }
    }
}
