import Foundation

/// The everything-that-syncs blob: bests + the daily log, the only data that
/// crosses devices (replays and in-progress games stay local — see AGENTS.md
/// "iCloud sync model"). A single shared blob, not per-device: both fields
/// merge commutatively and idempotently, so `merged` converges regardless of
/// order or duplication, and no DeviceID is needed.
public struct SyncedState: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var bests: BestScores
    public var dailyLog: DailyLog

    public init(bests: BestScores = BestScores(), dailyLog: DailyLog = DailyLog()) {
        version = Self.currentVersion
        self.bests = bests
        self.dailyLog = dailyLog
    }

    public func merged(with other: SyncedState) -> SyncedState {
        var result = self
        result.bests = bests.merged(with: other.bests)
        result.dailyLog = dailyLog.merged(with: other.dailyLog)
        return result
    }

    // ISO-8601 dates so the blob is stable across encoders.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public func encoded() -> Data? {
        try? Self.encoder.encode(self)
    }

    /// Tolerant decode: nil on garbage or a future version (never crash, never
    /// merge a blob we don't understand).
    public static func decoded(from data: Data) -> SyncedState? {
        guard let state = try? decoder.decode(SyncedState.self, from: data),
            state.version <= currentVersion
        else { return nil }
        return state
    }
}
