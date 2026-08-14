import LatticeCore
import XCTest

/// Two collinear lines that ABUT — no empty dot between them — seal the single
/// segment in between: a line through it would have to overlap one of the two.
/// That is the tightest dead gap there is, and it was the one case the detector
/// missed (its step range started at 2, i.e. "at least one empty dot").
final class ForeclosureAbuttingTests: XCTestCase {
    /// The reported case: two vertical lines on one column, `[-5…-1]` and
    /// `[0…4]`, reachable in two moves from the standard cross.
    func testAbuttingLinesReportADeadGap() throws {
        var game = Game(rules: .fiveT)
        let first = try XCTUnwrap(
            game.legalMoves().first {
                $0.line.axis == .vertical && $0.line.origin == Point(-2, -5)
            })
        XCTAssertTrue(game.play(first))
        let second = try XCTUnwrap(
            game.legalMoves().first {
                $0.line.axis == .vertical && $0.line.origin == Point(-2, 0)
            })
        XCTAssertTrue(game.play(second))

        // Nothing can ever be drawn along that column again…
        XCTAssertTrue(
            game.legalMoves().allSatisfy {
                !($0.line.axis == .vertical && $0.line.origin.x == -2)
            }, "the column is sealed")
        // …so the analysis must say so.
        XCTAssertEqual(
            Foreclosure.losses(in: game).count, 1,
            "an abutting pair leaves a dead segment and must be reported")
    }

    /// Every claimed dead span must really be dead: no legal move may draw a
    /// line along it at the moment the claim is made.
    func testNoClaimedSpanStillHasALineThroughIt() {
        for variant in [Rules.fiveT, .fiveD, .fiveTPlus] {
            var game = Game(rules: variant)
            var states: [Game] = [game]
            while let move = game.legalMoves().first, game.play(move) {
                states.append(game)
                if game.score > 70 { break }
            }
            for loss in Foreclosure.losses(in: game) {
                let after = states[min(loss.moveIndex + 1, states.count - 1)]
                let interior = Set(loss.span.points.dropFirst().dropLast())
                let contradicting = after.legalMoves().filter {
                    $0.line.axis == loss.span.axis
                        && !Set($0.line.points).isDisjoint(with: interior)
                }
                XCTAssertTrue(
                    contradicting.isEmpty,
                    "\(variant.storageKey): span \(loss.span.origin) called dead but "
                        + "\(contradicting.count) legal lines still cross it")
            }
        }
    }
}
