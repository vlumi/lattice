/// Personal bests, keyed by rule variant.
public struct BestScores: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var byVariant: [String: Int]

    public init() {
        version = Self.currentVersion
        byVariant = [:]
    }

    public func best(forKey key: String) -> Int? {
        byVariant[key]
    }

    /// Registers a final score; returns true if it's a new best.
    @discardableResult
    public mutating func register(_ score: Int, forKey key: String) -> Bool {
        guard score > (byVariant[key] ?? 0) else { return false }
        byVariant[key] = score
        return true
    }
}
