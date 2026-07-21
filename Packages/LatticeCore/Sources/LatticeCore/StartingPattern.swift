/// Starting dot patterns. The standard Morpion Solitaire start is the hollow
/// Greek-cross outline: 12 edges of 4 dots sharing corners, 36 dots total,
/// spanning [-5, 4] on both axes (see AGENTS.md, "Board & camera").
public enum StartingPattern {
    public static let standardCross: Set<Point> = makeStandardCross()

    private static func makeStandardCross() -> Set<Point> {
        // The plus polygon's 12 corners, walked clockwise from the top-left
        // corner of the upper arm; dots collect along each 3-unit edge.
        let corners: [Point] = [
            Point(-2, 4), Point(1, 4), Point(1, 1), Point(4, 1),
            Point(4, -2), Point(1, -2), Point(1, -5), Point(-2, -5),
            Point(-2, -2), Point(-5, -2), Point(-5, 1), Point(-2, 1),
        ]
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
