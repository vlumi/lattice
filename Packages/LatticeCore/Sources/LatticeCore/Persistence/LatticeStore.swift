import Foundation

/// File-based persistence: the current game, finished-game records, and
/// bests, as plain JSON in Application Support (games are a few KB — no
/// packing needed). Writes are atomic; loads are tolerant — missing,
/// unreadable, or future-version files yield nil/empty, never a crash.
public struct LatticeStore {
    private let directory: URL
    private let recordsDirectory: URL
    private let fileManager: FileManager

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

    public init(directory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory
        recordsDirectory = directory.appendingPathComponent("records", isDirectory: true)
        try? fileManager.createDirectory(at: recordsDirectory, withIntermediateDirectories: true)
    }

    /// Cached: resolving hits the filesystem, and callers construct stores
    /// frequently.
    private static let appSupportDirectory: URL = {
        let fileManager = FileManager.default
        return
            (try? fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)) ?? fileManager.temporaryDirectory
    }()

    public static func appSupport(fileManager: FileManager = .default) -> LatticeStore {
        LatticeStore(directory: appSupportDirectory, fileManager: fileManager)
    }

    /// A fresh store in a unique temp directory — test isolation.
    public static func ephemeral(fileManager: FileManager = .default) -> LatticeStore {
        let dir = fileManager.temporaryDirectory
            .appendingPathComponent("lattice-ephemeral-\(UUID().uuidString)", isDirectory: true)
        return LatticeStore(directory: dir, fileManager: fileManager)
    }

    // MARK: Current game

    var currentURL: URL { directory.appendingPathComponent("current.json") }

    public func saveCurrent(_ snapshot: GameSnapshot) {
        write(snapshot, to: currentURL)
    }

    public func loadCurrent() -> GameSnapshot? {
        load(GameSnapshot.self, from: currentURL, maxVersion: GameSnapshot.currentVersion)
    }

    public func clearCurrent() {
        try? fileManager.removeItem(at: currentURL)
    }

    // MARK: Finished-game records

    private func recordURL(for id: UUID) -> URL {
        recordsDirectory.appendingPathComponent("record-\(id.uuidString).json")
    }

    public func saveRecord(_ record: GameRecord) {
        write(record, to: recordURL(for: record.id))
    }

    /// All stored records, newest first. Unreadable files are skipped.
    public func loadRecords() -> [GameRecord] {
        let urls =
            (try? fileManager.contentsOfDirectory(
                at: recordsDirectory, includingPropertiesForKeys: nil)) ?? []
        return
            urls
            .filter { $0.lastPathComponent.hasPrefix("record-") }
            .compactMap { load(GameRecord.self, from: $0, maxVersion: GameRecord.currentVersion) }
            .sorted { $0.finishedAt > $1.finishedAt }
    }

    // MARK: Bests

    private var bestsURL: URL { directory.appendingPathComponent("bests.json") }

    public func saveBests(_ bests: BestScores) {
        write(bests, to: bestsURL)
    }

    public func loadBests() -> BestScores {
        load(BestScores.self, from: bestsURL, maxVersion: BestScores.currentVersion)
            ?? BestScores()
    }

    // MARK: Plumbing

    private struct VersionProbe: Decodable {
        let version: Int
    }

    private func write(_ value: some Encodable, to url: URL) {
        guard let data = try? Self.encoder.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL, maxVersion: Int) -> T? {
        guard let data = try? Data(contentsOf: url),
            let probe = try? Self.decoder.decode(VersionProbe.self, from: data),
            probe.version <= maxVersion
        else { return nil }
        return try? Self.decoder.decode(type, from: data)
    }
}
