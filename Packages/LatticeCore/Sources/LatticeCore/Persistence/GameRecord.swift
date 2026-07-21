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

    public init(game: Game, id: UUID, finishedAt: Date) {
        version = Self.currentVersion
        self.id = id
        rules = game.rules
        start = game.start
        moves = game.moves
        score = game.score
        self.finishedAt = finishedAt
    }
}
