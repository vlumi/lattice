/// A rule variant: how long a line is, and how collinear lines may overlap.
public struct Rules: Hashable, Sendable {
    public enum Overlap: Hashable, Sendable {
        /// Collinear lines may share an endpoint dot but no unit segment (T).
        case touching
        /// Collinear lines may not share any dot (D).
        case disjoint
    }

    public let lineLength: Int
    public let overlap: Overlap

    public init(lineLength: Int, overlap: Overlap) {
        self.lineLength = lineLength
        self.overlap = overlap
    }

    /// The classic game and this app's default.
    public static let fiveT = Rules(lineLength: 5, overlap: .touching)
    public static let fiveD = Rules(lineLength: 5, overlap: .disjoint)
}
