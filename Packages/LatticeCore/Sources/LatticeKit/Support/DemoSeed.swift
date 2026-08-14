import Foundation
import LatticeCore

/// The fixture data behind `-demo-seed`. Every value is derived, not random, so
/// the History chart, the bests and the daily streak look identical on an iPhone,
/// an iPad and a Mac — which is the whole point: switch screens, capture, move to
/// the next device, get the same picture.
///
/// Games are really *played* (greedy legal moves against the engine) rather than
/// fabricated, so replays scrub, the openness curve is real, and the personal-best
/// ghost has something to draw.
@MainActor
public enum DemoSeed {
    /// Scores chosen to read as a real player's progress: a good classic game
    /// well short of the 178 record, a couple of variants, a seeded challenge.
    /// The dates spread over five weeks so the History chart has a shape.
    private struct Fixture {
        let variant: Rules
        /// Days before now the game "finished", so History charts a spread.
        let days: Int
        /// Play stops here (or when the board dead-ends).
        let target: Int
    }

    private static let games: [Fixture] = [
        Fixture(variant: .fiveT, days: 34, target: 42),
        Fixture(variant: .fiveT, days: 27, target: 55),
        Fixture(variant: .fiveD, days: 22, target: 31),
        Fixture(variant: .fiveT, days: 18, target: 61),
        Fixture(variant: .fourT, days: 13, target: 28),
        Fixture(variant: .fiveTPlus, days: 9, target: 74),
        Fixture(variant: .fiveT, days: 5, target: 68),
        Fixture(variant: .fiveT, days: 1, target: 79),
    ]

    /// Which fixture the in-progress Free board comes from, and how far in to cut
    /// it: far enough that the board reads as played (a real tangle of lines),
    /// short enough that plenty of playable points remain — a board that looks
    /// dead sells nothing.
    private static let bestFixtureIndex = 7
    private static let inProgressMoves = 34

    /// The committed fixture: one move list per game, in `games` order. Playing
    /// these takes ~2 minutes (see `playFixtureGames`), so the result ships as
    /// `Scripts/asc/demo-games.json` and a demo launch just replays it.
    private static func fixtureMoves() -> [[Move]]? {
        guard let url = Bundle.module.url(forResource: "demo-games", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode([[Move]].self, from: data)
    }

    /// Replays the fixture games from scratch — the generator's entry point, not
    /// used at launch. See Tests/GenerateDemoFixture.
    public static func playFixtureGames() -> [[Move]] {
        games.map { play(rules: $0.variant, upTo: $0.target).moves }
    }

    /// The demo's "today". Fixed, not `Date()`: History plots real dates and the
    /// recent-games list prints them, so a wall-clock demo would put the iPhone
    /// and iPad shots on different days and shift the chart between captures.
    /// The daily streak is seeded relative to this, so it reads the same forever.
    ///
    /// Only the seeded *history* uses it — the live daily board still follows the
    /// real date (it has to; that's what the daily is).
    static let today = Date(timeIntervalSince1970: 1_781_308_800)  // 2026-06-13

    public static func apply(store: LatticeStore, defaults: UserDefaults) {
        // Sound off, haptics on: the shipped defaults, so a capture shows the
        // app as a new player finds it.
        defaults.set(false, forKey: Feedback.soundDefaultsKey)
        defaults.set(true, forKey: Feedback.hapticsDefaultsKey)

        var bests = BestScores()
        var log = DailyLog()
        let now = today

        let committed = fixtureMoves()
        for (index, spec) in games.enumerated() {
            let finished = now.addingTimeInterval(-Double(spec.days) * 86_400)
            var game = Game(rules: spec.variant)
            if let moves = committed?[safe: index] {
                for move in moves where game.play(move) {}
            } else {
                // No committed fixture (or a stale one) — play it live. Slow, but
                // the demo still works rather than showing an empty app.
                game = play(rules: spec.variant, upTo: spec.target)
            }
            store.saveRecord(GameRecord(game: game, id: UUID(), finishedAt: finished))
            _ = bests.register(game.score, forKey: game.rules.variantKey(forStart: game.start))
        }

        // A streak of five ending YESTERDAY, deliberately leaving today unplayed:
        // the Daily tab then shows the day's fresh board — its initial state,
        // which is what a newcomer sees — while the header still reads a live
        // streak, because an unplayed today doesn't break one. Relative to the
        // REAL today, since the daily board itself follows the real date.
        let realToday = Date()
        for back in 1...5 {
            let day = Calendar.current.date(byAdding: .day, value: -back, to: realToday)!
            let key = DailyChallenge.dateKey(for: day)
            log.record(
                DailyLog.Result(score: 41 + back * 2, finishedAt: day), for: key)
        }

        // Free: a board partway through, not a fresh cross. The listing's lead
        // shot is the mid-game board, and it has to look like the game actually
        // looks — lines drawn, dots placed, the frontier of playable points still
        // open — rather than the empty start every screenshot of this genre uses.
        // Reuses the strongest fixture game, cut off partway.
        if let moves = committed?[safe: bestFixtureIndex] {
            var inProgress = Game(rules: games[bestFixtureIndex].variant)
            for move in moves.prefix(inProgressMoves) where inProgress.play(move) {}
            store.saveCurrent(GameSnapshot(game: inProgress, id: UUID()))
        }

        store.saveBests(bests)
        store.saveDailyLog(log)
    }

    /// Play a real game, stopping at `upTo` moves (or when stuck) so the score is
    /// the one the fixture advertises.
    ///
    /// One-ply lookahead, capped: prefer the move leaving the most options open,
    /// but only weigh a bounded sample of candidates. Picking at random dead-ends
    /// in the high 20s — too feeble for a store screenshot — while weighing every
    /// candidate every move costs ~30s across the fixtures. Sampling gets scores
    /// in the 50s–70s in a few seconds. Deterministic: the sample is a fixed
    /// prefix, and ties break by index.
    private static func play(rules: Rules, upTo limit: Int) -> Game {
        var game = Game(rules: rules)
        while game.score < limit {
            let moves = game.legalMoves()
            guard !moves.isEmpty else { break }
            var best = moves[0]
            var bestOpenness = -1
            for move in moves.prefix(24) {
                var probe = game
                guard probe.play(move) else { continue }
                let openness = probe.legalMoves().count
                if openness > bestOpenness {
                    bestOpenness = openness
                    best = move
                }
            }
            guard game.play(best) else { break }
        }
        return game
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
