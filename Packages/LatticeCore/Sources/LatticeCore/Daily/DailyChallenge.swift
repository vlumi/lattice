import Foundation

/// The day's shared game. The LOCAL date string keys everything, so the same
/// calendar date is the same challenge everywhere (timezones only shift when
/// it flips; a date-changer only cheats themselves).
///
/// Until variant rotation / generated starts arrive, every day is the
/// classic 5T cross — the daily is one attempt per day at the classic
/// position. The date key is the seed input for future variety, so adding it
/// changes no stored data.
public enum DailyChallenge {
    /// Day one, PERMANENT. The calendar clamps to [epoch, today].
    public static let epochKey = "2026-07-21"

    /// "yyyy-MM-dd" in the user's calendar — the identity of a day.
    public static func dateKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public struct Board: Equatable, Sendable {
        public let dateKey: String
        public let rules: Rules
        public let start: Set<Point>
    }

    /// The challenge for a date key, or nil before the epoch.
    public static func board(for dateKey: String) -> Board? {
        guard dateKey >= epochKey else { return nil }
        return Board(dateKey: dateKey, rules: .fiveT, start: StartingPattern.standardCross)
    }
}
