import XCTest

@testable import LatticeCore

final class PersistenceTests: XCTestCase {
    private var store: LatticeStore!

    override func setUp() {
        super.setUp()
        store = .ephemeral()
    }

    private func playedGame(moves: Int) -> Game {
        var game = Game()
        for _ in 0..<moves {
            guard let move = game.legalMoves().min(by: Self.moveOrder) else { break }
            game.play(move)
        }
        return game
    }

    private static func moveOrder(_ a: Move, _ b: Move) -> Bool {
        (a.dot.x, a.dot.y, a.line.origin.x, a.line.origin.y)
            < (b.dot.x, b.dot.y, b.line.origin.x, b.line.origin.y)
    }

    func testSnapshotRoundTrip() {
        let game = playedGame(moves: 8)
        let snapshot = GameSnapshot(game: game, id: UUID())
        let restored = Game(snapshot: snapshot)
        XCTAssertEqual(restored, game)
    }

    func testSnapshotRejectsIllegalMoves() throws {
        // Corrupt a valid snapshot: swap its moves for an illegal one.
        let snapshot = GameSnapshot(game: playedGame(moves: 1), id: UUID())
        let illegal = Move(
            dot: Point(0, 0), line: Line(origin: Point(0, 0), axis: .horizontal, length: 5))
        var json =
            try XCTUnwrap(
                JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot))
                    as? [String: Any])
        json["moves"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode([illegal]))
        let corrupted = try JSONDecoder().decode(
            GameSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(Game(snapshot: corrupted))
    }

    func testCurrentGameSaveLoadClear() {
        let game = playedGame(moves: 5)
        let id = UUID()
        store.saveCurrent(GameSnapshot(game: game, id: id))
        let loaded = store.loadCurrent()
        XCTAssertEqual(loaded?.id, id)
        XCTAssertEqual(loaded.flatMap(Game.init(snapshot:)), game)
        store.clearCurrent()
        XCTAssertNil(store.loadCurrent())
    }

    func testVersusGameSaveLoad() {
        // The pass-and-play slot is separate from the solitaire current slot.
        let game = playedGame(moves: 3)
        let id = UUID()
        store.saveVersus(GameSnapshot(game: game, id: id))
        let loaded = store.loadVersus()
        XCTAssertEqual(loaded?.id, id)
        XCTAssertEqual(loaded.flatMap(Game.init(snapshot:)), game)
        // The versus slot doesn't leak into the solitaire slot.
        XCTAssertNil(store.loadCurrent())
    }

    func testSyncedStateRoundTripsThroughBestsAndDailyFiles() {
        // loadSyncedState assembles from the same bests/daily files the app
        // uses; saveSyncedState splits back to them.
        var bests = BestScores()
        bests.register(42, forKey: "5T")
        var log = DailyLog()
        log.record(
            DailyLog.Result(score: 7, finishedAt: Date(timeIntervalSince1970: 1)),
            for: "2026-07-24")
        store.saveSyncedState(SyncedState(bests: bests, dailyLog: log))
        let loaded = store.loadSyncedState()
        XCTAssertEqual(loaded.bests.best(forKey: "5T"), 42)
        XCTAssertEqual(loaded.dailyLog.results["2026-07-24"]?.score, 7)
    }

    func testFutureVersionHiddenNotDeleted() throws {
        // A future build's save is hidden, not destroyed.
        let snapshot = GameSnapshot(game: playedGame(moves: 2), id: UUID())
        var json =
            try XCTUnwrap(
                JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot))
                    as? [String: Any])
        json["version"] = GameSnapshot.currentVersion + 1
        try JSONSerialization.data(withJSONObject: json).write(to: store.currentURL)
        XCTAssertNil(store.loadCurrent())
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.currentURL.path))
    }

    func testRecordVariantKeyDerivesFromRulesAndStart() {
        // variantKey reflects the record's rules + starting pattern (the "#"
        // suffix distinguishes a seeded start from the standard one).
        let record = GameRecord(
            game: playedGame(moves: 2), id: UUID(), finishedAt: Date(timeIntervalSince1970: 1))
        XCTAssertFalse(record.variantKey.isEmpty)
    }

    func testRecordsSortedNewestFirst() {
        let game = playedGame(moves: 3)
        let old = GameRecord(game: game, id: UUID(), finishedAt: Date(timeIntervalSince1970: 100))
        let new = GameRecord(game: game, id: UUID(), finishedAt: Date(timeIntervalSince1970: 200))
        store.saveRecord(old)
        store.saveRecord(new)
        let loaded = store.loadRecords()
        XCTAssertEqual(loaded.map(\.id), [new.id, old.id])
    }

    func testRecordRewriteIsIdempotent() {
        let game = playedGame(moves: 3)
        let id = UUID()
        let record = GameRecord(game: game, id: id, finishedAt: Date(timeIntervalSince1970: 100))
        store.saveRecord(record)
        store.saveRecord(record)
        XCTAssertEqual(store.loadRecords().count, 1)
    }

    func testBestScores() {
        var bests = store.loadBests()
        XCTAssertNil(bests.best(forKey: "5T"))
        XCTAssertTrue(bests.register(10, forKey: "5T"))
        XCTAssertFalse(bests.register(7, forKey: "5T"))
        XCTAssertTrue(bests.register(12, forKey: "5T"))
        XCTAssertTrue(bests.register(3, forKey: "5D"))
        // The seeded pool is separate from the classic one.
        XCTAssertTrue(bests.register(40, forKey: "5T#"))
        store.saveBests(bests)
        let loaded = store.loadBests()
        XCTAssertEqual(loaded.best(forKey: "5T"), 12)
        XCTAssertEqual(loaded.best(forKey: "5D"), 3)
        XCTAssertEqual(loaded.best(forKey: "5T#"), 40)
    }

    func testGarbageFilesYieldNil() throws {
        try Data("not json".utf8).write(to: store.currentURL)
        XCTAssertNil(store.loadCurrent())
        XCTAssertEqual(store.loadBests(), BestScores())
    }
}
