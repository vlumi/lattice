/// The eight symmetries of the board's dihedral group. The standard cross is
/// centered on (-0.5, -0.5) — between dots — so the maps use the `-1 - x`
/// form rather than plain negation (see AGENTS.md, "Board & camera").
public enum Symmetry: CaseIterable, Sendable {
    case identity
    case rotate90
    case rotate180
    case rotate270
    case mirrorX
    case mirrorY
    case mirrorDiagonal
    case mirrorAntidiagonal

    public func apply(_ p: Point) -> Point {
        switch self {
        case .identity: return p
        case .rotate90: return Point(-1 - p.y, p.x)
        case .rotate180: return Point(-1 - p.x, -1 - p.y)
        case .rotate270: return Point(p.y, -1 - p.x)
        case .mirrorX: return Point(-1 - p.x, p.y)
        case .mirrorY: return Point(p.x, -1 - p.y)
        case .mirrorDiagonal: return Point(p.y, p.x)
        case .mirrorAntidiagonal: return Point(-1 - p.y, -1 - p.x)
        }
    }

    public func apply(_ dots: Set<Point>) -> Set<Point> {
        Set(dots.map(apply))
    }
}
