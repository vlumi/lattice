import LatticeCore
import XCTest

/// The export's whole point is that a game can be reconstructed from it — a bug
/// report has to carry the exact board that misbehaved.
final class DataExportTests: XCTestCase {
    private func playedGame(upTo limit: Int = 12) -> Game {
        var game = Game(rules: .fiveT)
        while game.score < limit, let move = game.legalMoves().first, game.play(move) {}
        return game
    }

    func testExportRoundTripsAndReplays() throws {
        let store = LatticeStore.ephemeral()
        let game = playedGame()
        let id = UUID()
        store.saveRecord(GameRecord(game: game, id: id, finishedAt: Date()))
        var bests = BestScores()
        _ = bests.register(game.score, forKey: "5T")
        store.saveBests(bests)

        let data = try XCTUnwrap(DataExport(store: store).encoded())
        let decoded = try JSONDecoder.iso8601.decode(DataExport.self, from: data)

        XCTAssertEqual(decoded.version, DataExport.currentVersion)
        XCTAssertEqual(decoded.records.count, 1)
        XCTAssertEqual(decoded.bests.best(forKey: "5T"), game.score)

        // The exported moves must replay into the same game.
        let record = try XCTUnwrap(decoded.records.first)
        var replayed = Game(rules: record.rules, start: record.start)
        for move in record.moves {
            XCTAssertTrue(replayed.play(move), "every exported move must be legal in order")
        }
        XCTAssertEqual(replayed.score, game.score, "replays to the same score")
        XCTAssertEqual(replayed.dots, game.dots, "and the same board")
    }

    /// An empty install exports cleanly rather than failing.
    func testExportOfEmptyStore() throws {
        let data = try XCTUnwrap(DataExport(store: .ephemeral()).encoded())
        let decoded = try JSONDecoder.iso8601.decode(DataExport.self, from: data)
        XCTAssertTrue(decoded.records.isEmpty)
        XCTAssertNil(decoded.currentGame)
    }

    func testFilenameIsDated() {
        let day = Date(timeIntervalSince1970: 1_781_308_800)
        XCTAssertEqual(DataExport.filename(now: day), "lattice-data-2026-06-13.json")
    }
}

extension JSONDecoder {
    fileprivate static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
