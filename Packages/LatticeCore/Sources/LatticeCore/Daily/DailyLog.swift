import Foundation

/// Completed dailies, keyed by date key. Only live play records a result —
/// there is no backfill, so the streak is honest.
public struct DailyLog: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public struct Result: Codable, Equatable, Sendable {
        public let score: Int
        public let finishedAt: Date

        public init(score: Int, finishedAt: Date) {
            self.score = score
            self.finishedAt = finishedAt
        }
    }

    public var version: Int
    public var results: [String: Result]

    public init() {
        version = Self.currentVersion
        results = [:]
    }

    public mutating func record(_ result: Result, for dateKey: String) {
        results[dateKey] = result
    }

    /// Consecutive completed days ending today — or ending yesterday when
    /// today isn't played yet (an unplayed today doesn't break the streak,
    /// it just doesn't extend it).
    public func streak(today todayKey: String, calendar: Calendar = .current) -> Int {
        guard var date = Self.date(of: todayKey, calendar: calendar) else { return 0 }
        if results[todayKey] == nil {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else {
                return 0
            }
            date = previous
        }
        var count = 0
        var cursor = date
        while results[DailyChallenge.dateKey(for: cursor, calendar: calendar)] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return count
    }

    static func date(of dateKey: String, calendar: Calendar = .current) -> Date? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        (components.year, components.month, components.day) = (parts[0], parts[1], parts[2])
        return calendar.date(from: components)
    }
}
