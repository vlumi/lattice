/// The four line axes. Axes are undirected; `step` fixes a canonical
/// positive direction so segment keys and line walks are unambiguous.
public enum Axis: CaseIterable, Sendable {
    case horizontal
    case vertical
    case diagonalRising
    case diagonalFalling

    public var step: (dx: Int, dy: Int) {
        switch self {
        case .horizontal: return (1, 0)
        case .vertical: return (0, 1)
        case .diagonalRising: return (1, 1)
        case .diagonalFalling: return (1, -1)
        }
    }
}
