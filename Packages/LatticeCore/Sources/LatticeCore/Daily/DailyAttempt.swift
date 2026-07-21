import Foundation

/// The daily game in progress (or finished, kept for display), bound to its
/// date — an attempt from another day never restores.
public struct DailyAttempt: Codable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let dateKey: String
    public let snapshot: GameSnapshot

    public init(dateKey: String, snapshot: GameSnapshot) {
        version = Self.currentVersion
        self.dateKey = dateKey
        self.snapshot = snapshot
    }
}
