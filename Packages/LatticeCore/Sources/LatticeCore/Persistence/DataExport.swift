import Foundation

/// Everything the app knows about you, as one JSON document: every finished
/// game with its full move list, the bests, the daily log, and any game in
/// progress. Settings are excluded — they're preferences, not your data.
///
/// This is data portability, not a debug feature: it's the honest counterpart to
/// Reset Progress, and it's what lets a player (or a tester reporting a bug)
/// hand over the exact game that misbehaved. Every move is included, so an
/// exported game can be replayed move for move.
public struct DataExport: Codable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let exportedAt: Date
    public let appVersion: String?
    public let records: [GameRecord]
    public let bests: BestScores
    public let dailyLog: DailyLog
    public let currentGame: GameSnapshot?
    public let versusGame: GameSnapshot?
    public let dailyAttempt: DailyAttempt?

    public init(store: LatticeStore, appVersion: String? = nil, now: Date = Date()) {
        version = Self.currentVersion
        exportedAt = now
        self.appVersion = appVersion
        records = store.loadRecords()
        bests = store.loadBests()
        dailyLog = store.loadDailyLog()
        currentGame = store.loadCurrent()
        versusGame = store.loadVersus()
        dailyAttempt = store.loadDailyAttempt()
    }

    /// Pretty-printed with sorted keys and ISO-8601 dates, so a dump is readable
    /// and two dumps diff cleanly.
    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }

    /// `lattice-data-2026-08-14.json` — dated, so several exports don't collide.
    public static func filename(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "lattice-data-\(formatter.string(from: now)).json"
    }
}
