/// A rule variant: how long a line is, and how collinear lines may overlap.
public struct Rules: Hashable, Codable, Sendable {
    public enum Overlap: String, Hashable, Codable, Sendable {
        /// Collinear lines may share an endpoint dot but no unit segment (T).
        case touching = "T"
        /// Collinear lines may not share any dot (D).
        case disjoint = "D"
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
    /// The solved 4-games (optimal scores 62 and 35) — short, with a
    /// completion goal rather than an open chase.
    public static let fourT = Rules(lineLength: 4, overlap: .touching)
    public static let fourD = Rules(lineLength: 4, overlap: .disjoint)

    /// The variants the UI offers, in display order.
    public static let selectable: [Rules] = [.fiveT, .fiveD, .fourT, .fourD]

    /// Stable key for persistence maps ("5T", "5D", later "4T"…).
    public var storageKey: String { "\(lineLength)\(overlap.rawValue)" }

    /// The scoring pool for a rules + start combination: games on the
    /// standard pattern key as e.g. "5T"; any other start keys as "5T#"
    /// (the literature's name for any-36-dot-start games) — a generous
    /// generated start must not pollute the classic bests.
    public func variantKey(forStart start: Set<Point>) -> String {
        start == StartingPattern.standard(for: self) ? storageKey : storageKey + "#"
    }
}
