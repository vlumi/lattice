import LatticeCore
import XCTest

/// Which gaps between two collinear lines are genuinely dead?
///
/// A line needs five CONSECUTIVE dots but may start inside a neighbour's span,
/// so long as it reuses no unit segment. So the answer is not "any small gap":
/// with three or more empty dots a legal five-window still fits, and calling
/// such a gap dead is a false alarm the player can see through.
final class GapReachTests: XCTestCase {
    /// Two horizontal lines with `gap` empty dots between them; can any
    /// five-window along that row avoid both their segment sets?
    private func gapIsCrossable(_ gap: Int) -> Bool {
        let leftStart = -5 - gap
        let left = Line(origin: Point(leftStart, 0), axis: .horizontal, length: 5)
        let right = Line(origin: Point(0, 0), axis: .horizontal, length: 5)
        let used = Set(left.segments).union(right.segments)
        for originX in (leftStart - 4)...4 {
            let candidate = Line(origin: Point(originX, 0), axis: .horizontal, length: 5)
            guard candidate.points.contains(where: { $0.x >= -gap && $0.x <= -1 }) else { continue }
            if Set(candidate.segments).isDisjoint(with: used) { return true }
        }
        return false
    }

    func testOnlyGapsOfTwoOrFewerAreDead() {
        XCTAssertFalse(gapIsCrossable(0), "abutting lines seal the segment between")
        XCTAssertFalse(gapIsCrossable(1))
        XCTAssertFalse(gapIsCrossable(2))
        XCTAssertTrue(gapIsCrossable(3), "three empty dots still admit a line")
        XCTAssertTrue(gapIsCrossable(4))
    }

    /// The detector must agree with that: report gaps of 0-2 empty dots and
    /// stay quiet about 3+.
    func testForeclosureMatchesWhatIsActuallyDead() {
        for gap in 0...4 {
            let leftStart = -5 - gap
            // Seed every dot but the two the moves place, so both lines are legal.
            var start: Set<Point> = []
            for x in leftStart...(leftStart + 3) { start.insert(Point(x, 0)) }
            for x in 0...3 { start.insert(Point(x, 0)) }
            var game = Game(rules: .fiveT, start: start)
            guard
                game.play(
                    Move(
                        dot: Point(leftStart + 4, 0),
                        line: Line(origin: Point(leftStart, 0), axis: .horizontal, length: 5))),
                game.play(
                    Move(
                        dot: Point(4, 0),
                        line: Line(origin: Point(0, 0), axis: .horizontal, length: 5)))
            else {
                continue  // that gap size isn't constructible this way
            }
            let reported = !Foreclosure.losses(in: game).isEmpty
            XCTAssertEqual(
                reported, !gapIsCrossable(gap),
                "gap of \(gap) empty dots: reported=\(reported) but "
                    + "crossable=\(gapIsCrossable(gap))")
        }
    }
}
