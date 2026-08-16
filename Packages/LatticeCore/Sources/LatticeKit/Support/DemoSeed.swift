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
        /// A seeded start, as the dailies and code challenges use — nil for the
        /// variant's standard pattern.
        var seed: UInt64?
        /// Recorded as a daily, so History shows the "Daily" row label.
        ///
        /// The board isn't that date's real daily board. Demo data is staged
        /// throughout — the streak scores are invented too — and using real
        /// boards meant generating and solving one per launch (several seconds,
        /// since the day's board changes daily and so can't be committed like
        /// the fixtures below).
        var isDaily = false

        /// Rotates the lookahead's candidate window, so fixtures sharing a board
        /// play different games rather than prefixes of one another. See `play`.
        var variation = 0

        /// The board to play: a seeded start when `seed` is set, else the
        /// variant's own standard pattern (the 4-in-a-row variants start from a
        /// smaller cross, so this can't just default to the standard one).
        var start: Set<Point> {
            seed.map { StartGenerator.pattern(seed: $0) }
                ?? StartingPattern.standard(for: variant)
        }
    }

    /// Each standard-cross game gets its own `variation`, or they'd all be
    /// prefixes of the longest one (the lookahead is deterministic per board).
    private static let games: [Fixture] = [
        Fixture(variant: .fiveT, days: 34, target: 42, variation: 1),
        Fixture(variant: .fiveT, days: 27, target: 55, variation: 2),
        Fixture(variant: .fiveD, days: 22, target: 31),
        Fixture(variant: .fiveT, days: 18, target: 61, variation: 3),
        Fixture(variant: .fourT, days: 13, target: 28),
        Fixture(variant: .fiveTPlus, days: 9, target: 74),
        // The two dailies: 5T on a seeded start, like the real thing, so they
        // score in the 5T# pool the chart and filter expect.
        Fixture(variant: .fiveT, days: 6, target: 52, seed: 20_260_806, isDaily: true),
        Fixture(variant: .fiveT, days: 5, target: 68, variation: 4),
        Fixture(variant: .fiveT, days: 2, target: 47, seed: 20_260_810, isDaily: true),
        Fixture(variant: .fiveT, days: 1, target: 79, variation: 5),
    ]

    /// Which fixture the in-progress Free board comes from, and how far in to cut
    /// it: far enough that the board reads as played (a real tangle of lines),
    /// short enough that plenty of playable points remain — a board that looks
    /// dead sells nothing.
    ///
    /// Not the best 5T game: that one is the personal-best ghost, and a live
    /// board cut from it would trace the ghost exactly — two lines on top of
    /// each other, which shows nothing. Its `variation` also has to differ
    /// (see `play`), or a different index alone still yields the same game.
    private static let inProgressFixtureIndex = 1
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
        games.map {
            play(rules: $0.variant, start: $0.start, upTo: $0.target, variation: $0.variation)
                .moves
        }
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
            var game = Game(rules: spec.variant, start: spec.start)
            if let moves = committed?[safe: index] {
                for move in moves where game.play(move) {}
            } else {
                // No committed fixture (or a stale one) — play it live. Slow, but
                // the demo still works rather than showing an empty app.
                game = play(
                    rules: spec.variant, start: spec.start, upTo: spec.target,
                    variation: spec.variation)
            }
            store.saveRecord(
                GameRecord(
                    game: game, id: UUID(), finishedAt: finished, seed: spec.seed,
                    dailyDateKey: spec.isDaily ? DailyChallenge.dateKey(for: finished) : nil))
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
        // Reuses a fixture game, cut off partway.
        let inProgressSpec = games[inProgressFixtureIndex]
        if let moves = committed?[safe: inProgressFixtureIndex] {
            var inProgress = Game(rules: inProgressSpec.variant, start: inProgressSpec.start)
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
    ///
    /// `variation` rotates where the sample window starts, so two fixtures on the
    /// SAME board play genuinely different games. Without it the search is fully
    /// determined by the start, and every standard-cross fixture was a strict
    /// prefix of the longest one — which made the personal-best ghost trace the
    /// live curve exactly, comparing a game against itself.
    private static func play(
        rules: Rules, start: Set<Point>, upTo limit: Int, variation: Int = 0
    ) -> Game {
        var game = Game(rules: rules, start: start)
        while game.score < limit {
            let moves = game.legalMoves()
            guard !moves.isEmpty else { break }
            let offset = variation % moves.count
            let window = Array(moves[offset...] + moves[..<offset]).prefix(24)
            var best = window[0]
            var bestOpenness = -1
            for move in window {
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
