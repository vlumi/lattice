/// Seeded symmetric starting patterns — the 5T#/5D# form: any 36-dot start,
/// same rules. Deterministic forever: the same seed is the same pattern on
/// every device and every build. DO NOT change the construction or the
/// validation thresholds once shipped — that would silently change every
/// future daily and every shared seed.
public enum StartGenerator {
    /// A playable, 8-fold-symmetric 36-dot pattern for the seed. Scans
    /// deterministically until validation passes; falls back to the
    /// standard cross (always playable) if nothing in the scan does.
    /// Attempt sub-seeds come from a per-seed stream — NOT `seed + attempt`,
    /// which would make consecutive seeds share a scan space and collide
    /// whenever an attempt fails.
    public static func pattern(seed: UInt64) -> Set<Point> {
        var seedStream = SplitMix64(seed: seed)
        for _ in 0..<256 {
            let attemptSeed = seedStream.next()
            var rng = SplitMix64(seed: attemptSeed)
            let candidate = build(&rng)
            if isPlayable(candidate, probeSeed: attemptSeed) {
                return candidate
            }
        }
        return StartingPattern.standardCross
    }

    // 36 dots as symmetry orbits about the standard centre (-0.5, -0.5):
    // a diagonal representative (x, x) orbits to 4 dots, a generic one
    // (x < y, both ≥ 0) to 8 — so 36 = 4·a + 8·b with a ∈ {1, 3}.
    private static func build(_ rng: inout SplitMix64) -> Set<Point> {
        let radius = 5
        let diagonalCount = Int(rng.next() % 2) * 2 + 1
        let genericCount = (36 - 4 * diagonalCount) / 8

        var diagonals = Set<Int>()
        while diagonals.count < diagonalCount {
            diagonals.insert(Int(rng.next() % UInt64(radius + 1)))
        }
        var generics = Set<Point>()
        while generics.count < genericCount {
            let x = Int(rng.next() % UInt64(radius))
            let y = x + 1 + Int(rng.next() % UInt64(radius - x))
            generics.insert(Point(x, y))
        }

        var dots = Set<Point>()
        for x in diagonals {
            insertOrbit(of: Point(x, x), into: &dots)
        }
        for rep in generics {
            insertOrbit(of: rep, into: &dots)
        }
        return dots
    }

    private static func insertOrbit(of p: Point, into dots: inout Set<Point>) {
        for symmetry in Symmetry.allCases {
            dots.insert(symmetry.apply(p))
        }
    }

    // Playable = the position opens with real choice and a seeded random
    // playout sustains a game — filters out sparse or fragmented patterns.
    private static func isPlayable(_ start: Set<Point>, probeSeed: UInt64) -> Bool {
        var game = Game(rules: .fiveT, start: start)
        guard game.legalMoves().count >= 12 else { return false }
        var rng = SplitMix64(seed: probeSeed ^ 0x5DEE_CE66)
        var played = 0
        while played < 40 {
            let moves = game.legalMoves().sorted(by: Move.deterministicOrder)
            guard !moves.isEmpty else { break }
            game.play(moves[Int(rng.next() % UInt64(moves.count))])
            played += 1
        }
        return played >= 24
    }
}

extension Move {
    /// A stable total order — Set iteration order isn't deterministic, so
    /// seeded consumers sort with this first.
    static func deterministicOrder(_ a: Move, _ b: Move) -> Bool {
        (a.dot.x, a.dot.y, a.line.origin.x, a.line.origin.y, a.line.axis.rawValue)
            < (b.dot.x, b.dot.y, b.line.origin.x, b.line.origin.y, b.line.axis.rawValue)
    }
}
