/// The target line-counts a Nearby duel can race to. A tier is offerable only
/// when BOTH players have reached it in single-player (their per-variant
/// `BestScores`), so it's provably achievable on the chosen variant — and the
/// intersection doubles as fairness/matchmaking (a strong+weak pairing is
/// capped at what the weaker has done). See AGENTS.md / the duel plan.
public enum DuelTier {
    /// The fixed ladder. 5 is dropped — too trivial to be a contest.
    public static let ladder = [10, 20, 30, 50, 80, 120]

    /// Variants both players have a best in — the duel-eligible set.
    public static func eligibleVariants(mine: BestScores, theirs: BestScores) -> [String] {
        let shared = Set(mine.byVariant.keys).intersection(theirs.byVariant.keys)
        // Canonical display order (5T, 5T#, …); unknown keys trail, sorted.
        let ordered = VariantOrder.canonical.filter(shared.contains)
        return ordered + shared.subtracting(ordered).sorted()
    }

    /// The tiers offerable for a variant: ladder rungs both players have
    /// reached (each `best >= rung`).
    public static func offerableTiers(
        variantKey: String, mine: BestScores, theirs: BestScores
    ) -> [Int] {
        let cap = min(mine.best(forKey: variantKey) ?? 0, theirs.best(forKey: variantKey) ?? 0)
        return ladder.filter { $0 <= cap }
    }
}

/// The canonical variant display order, shared by the duel tier gate and the
/// History view so ordering is defined in one place.
public enum VariantOrder {
    public static let canonical = ["5T", "5T#", "5T+", "5D", "5D#", "4T", "4D"]
}
