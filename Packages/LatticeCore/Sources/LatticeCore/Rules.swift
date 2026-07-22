/// A rule variant: how long a line is, how collinear lines may overlap, and
/// whether the line is linked to the placed dot.
public struct Rules: Hashable, Codable, Sendable {
    public enum Overlap: String, Hashable, Codable, Sendable {
        /// Collinear lines may share an endpoint dot but no unit segment (T).
        case touching = "T"
        /// Collinear lines may not share any dot (D).
        case disjoint = "D"
    }

    public let lineLength: Int
    public let overlap: Overlap
    /// The defining split of the "+" family (5T+/MS2, the common schoolyard
    /// form): when false, the dot goes anywhere and the line may be drawn
    /// through ANY five dots — "free lines" through pre-existing dots are
    /// legal. When true (classic), the line must contain the placed dot.
    public let linked: Bool

    public init(lineLength: Int, overlap: Overlap, linked: Bool = true) {
        self.lineLength = lineLength
        self.overlap = overlap
        self.linked = linked
    }

    // Older saves predate `linked`; absent means classic.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineLength = try container.decode(Int.self, forKey: .lineLength)
        overlap = try container.decode(Overlap.self, forKey: .overlap)
        linked = try container.decodeIfPresent(Bool.self, forKey: .linked) ?? true
    }

    /// The classic game and this app's default.
    public static let fiveT = Rules(lineLength: 5, overlap: .touching)
    public static let fiveD = Rules(lineLength: 5, overlap: .disjoint)
    /// The relaxed schoolyard variant (a.k.a. MS2): dot and line decoupled.
    /// Its record — 216, set by hand in 1974 — has never been beaten.
    public static let fiveTPlus = Rules(lineLength: 5, overlap: .touching, linked: false)
    /// The solved 4-games (optimal scores 62 and 35) — short, with a
    /// completion goal rather than an open chase.
    public static let fourT = Rules(lineLength: 4, overlap: .touching)
    public static let fourD = Rules(lineLength: 4, overlap: .disjoint)

    /// The variants the UI offers, in display order.
    public static let selectable: [Rules] = [.fiveT, .fiveTPlus, .fiveD, .fourT, .fourD]

    /// Stable key for persistence maps ("5T", "5T+", "5D", "4T"…).
    public var storageKey: String {
        "\(lineLength)\(overlap.rawValue)\(linked ? "" : "+")"
    }

    /// The scoring pool for a rules + start combination: games on the
    /// standard pattern key as e.g. "5T"; any other start keys as "5T#"
    /// (the literature's name for any-36-dot-start games) — a generous
    /// generated start must not pollute the classic bests.
    public func variantKey(forStart start: Set<Point>) -> String {
        start == StartingPattern.standard(for: self) ? storageKey : storageKey + "#"
    }
}
