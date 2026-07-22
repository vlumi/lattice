import Foundation

/// A finished game — the full replay plus its outcome. One record per game
/// id; rewriting the same id is idempotent.
public struct GameRecord: Codable, Hashable, Sendable, Identifiable {
    public static let currentVersion = 1

    public let version: Int
    public let id: UUID
    public let rules: Rules
    public let start: Set<Point>
    public let moves: [Move]
    public let score: Int
    public let finishedAt: Date
    /// The challenge seed the start was generated from, if any (optional —
    /// absent in older records, decodes as nil).
    public let seed: UInt64?

    public init(game: Game, id: UUID, finishedAt: Date, seed: UInt64? = nil) {
        version = Self.currentVersion
        self.id = id
        rules = game.rules
        start = game.start
        moves = game.moves
        score = game.score
        self.finishedAt = finishedAt
        self.seed = seed
    }

    /// The scoring pool this game belongs to ("5T", "5T#", …).
    public var variantKey: String { rules.variantKey(forStart: start) }
}
