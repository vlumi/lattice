/// Starting dot patterns. The standard Morpion Solitaire start is the hollow
/// Greek-cross outline: 12 edges of 4 dots sharing corners, 36 dots total,
/// spanning [-5, 4] on both axes (see AGENTS.md, "Board & camera").
public enum StartingPattern {
    public static let standardCross: Set<Point> = makeStandardCross()

    /// The smaller cross the 4T/4D games start from: 12 edges of 3 dots,
    /// 24 dots, spanning [-3, 3]² — odd extent, so its center is the (empty)
    /// origin dot, unlike the standard cross's between-dots center.
    public static let smallCross: Set<Point> = makeSmallCross()

    /// The standard start for a variant: the small cross for 4-length
    /// games, the classic cross otherwise.
    public static func standard(for rules: Rules) -> Set<Point> {
        rules.lineLength == 4 ? smallCross : standardCross
    }

    private static func makeStandardCross() -> Set<Point> {
        // The plus polygon's 12 corners, walked clockwise from the top-left
        // corner of the upper arm; dots collect along each 3-unit edge.
        let corners: [Point] = [
            Point(-2, 4), Point(1, 4), Point(1, 1), Point(4, 1),
            Point(4, -2), Point(1, -2), Point(1, -5), Point(-2, -5),
            Point(-2, -2), Point(-5, -2), Point(-5, 1), Point(-2, 1),
        ]
        return outline(corners)
    }

    private static func makeSmallCross() -> Set<Point> {
        let corners: [Point] = [
            Point(-1, 3), Point(1, 3), Point(1, 1), Point(3, 1),
            Point(3, -1), Point(1, -1), Point(1, -3), Point(-1, -3),
            Point(-1, -1), Point(-3, -1), Point(-3, 1), Point(-1, 1),
        ]
        return outline(corners)
    }

    private static func outline(_ corners: [Point]) -> Set<Point> {
        var dots = Set<Point>()
        for (index, corner) in corners.enumerated() {
            let next = corners[(index + 1) % corners.count]
            let dx = (next.x - corner.x).signum()
            let dy = (next.y - corner.y).signum()
            var p = corner
            while p != next {
                dots.insert(p)
                p = Point(p.x + dx, p.y + dy)
            }
        }
        return dots
    }
}
