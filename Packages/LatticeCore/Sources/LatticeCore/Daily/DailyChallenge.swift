import Foundation

/// The day's shared game. The LOCAL date string keys everything, so the same
/// calendar date is the same challenge everywhere (timezones only shift when
/// it flips; a date-changer only cheats themselves).
///
/// Rules stay classic 5T every day (streaks compare like with like); the
/// **starting pattern varies per date** — a seeded symmetric 36-dot start,
/// the 5T# form. The derivation is PERMANENT: changing it would change
/// every future day.
public enum DailyChallenge {
    /// Day one, PERMANENT. The calendar clamps to [epoch, today].
    public static let epochKey = "2026-07-21"

    /// Days before this played the classic cross; generated starts begin
    /// here. PERMANENT.
    static let generatedFromKey = "2026-07-22"

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
        guard dateKey >= generatedFromKey else {
            return Board(dateKey: dateKey, rules: .fiveT, start: StartingPattern.standardCross)
        }
        let seed = StableHash.fnv1a("lattice.daily." + dateKey)
        return Board(dateKey: dateKey, rules: .fiveT, start: StartGenerator.pattern(seed: seed))
    }
}
