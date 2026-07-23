/// The target line-counts a Nearby duel can race to. Higher rungs are offerable
/// only when BOTH players have reached them in single-player (their per-variant
/// `BestScores`), so they're provably achievable and fair (a strong+weak
/// pairing is capped at what the weaker has done). The FLOOR rung is always
/// offerable — anyone who knows the rules can reach it — so a brand-new player
/// can still duel. See AGENTS.md / the duel plan.
public enum DuelTier {
    /// The fixed ladder. 5 is dropped — too trivial to be a contest.
    public static let ladder = [10, 20, 30, 50, 80, 120]

    /// The entry rung, always offerable regardless of proven best.
    public static let floor = 10

    /// The duel-eligible variants: the standard selectable set (both apps share
    /// these inherently — no recorded best required, since the floor tier is
    /// universal). Emitted in canonical display order.
    public static var eligibleVariants: [String] {
        let standard = Set(Rules.selectable.map(\.storageKey))
        return VariantOrder.canonical.filter(standard.contains)
    }

    /// The tiers offerable for a variant: the floor (always), plus any higher
    /// ladder rung both players have reached (each `best >= rung`).
    public static func offerableTiers(
        variantKey: String, mine: BestScores, theirs: BestScores
    ) -> [Int] {
        let cap = min(mine.best(forKey: variantKey) ?? 0, theirs.best(forKey: variantKey) ?? 0)
        return ladder.filter { $0 == floor || $0 <= cap }
    }
}

/// The canonical variant display order, shared by the duel tier gate and the
/// History view so ordering is defined in one place.
public enum VariantOrder {
    public static let canonical = ["5T", "5T#", "5T+", "5D", "5D#", "4T", "4D"]
}
