import Foundation

/// The in-progress game, serialized. Restoring replays the moves through the
/// engine, so a snapshot that violates the rules (corruption, drifted rule
/// code) fails to load instead of producing an illegal position.
public struct GameSnapshot: Codable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let id: UUID
    public let rules: Rules
    public let start: Set<Point>
    public let moves: [Move]

    public init(game: Game, id: UUID) {
        version = Self.currentVersion
        self.id = id
        rules = game.rules
        start = game.start
        moves = game.moves
    }
}

extension Game {
    /// Rebuilds the game by replaying the snapshot; nil on version or rule
    /// mismatch — tolerant loading, never a corrupt position.
    public init?(snapshot: GameSnapshot) {
        guard snapshot.version <= GameSnapshot.currentVersion else { return nil }
        var game = Game(rules: snapshot.rules, start: snapshot.start)
        for move in snapshot.moves {
            guard game.play(move) else { return nil }
        }
        self = game
    }
}
