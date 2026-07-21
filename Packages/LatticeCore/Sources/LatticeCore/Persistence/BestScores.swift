/// Personal bests, keyed by rule variant.
public struct BestScores: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var byVariant: [String: Int]

    public init() {
        version = Self.currentVersion
        byVariant = [:]
    }

    public func best(for rules: Rules) -> Int? {
        byVariant[rules.storageKey]
    }

    /// Registers a final score; returns true if it's a new best.
    @discardableResult
    public mutating func register(_ score: Int, for rules: Rules) -> Bool {
        guard score > (byVariant[rules.storageKey] ?? 0) else { return false }
        byVariant[rules.storageKey] = score
        return true
    }
}
