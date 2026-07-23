import Foundation

/// The two Nearby duel modes. Both race the same seeded board, but the win
/// condition — and whether a clock is involved — differs.
///
/// - `lockStep`: no target. When any player commits a move, everyone who
///   hasn't yet gets a reactive countdown; letting it expire (or dead-ending
///   while others can still play) eliminates you. Last player standing wins.
///   "Speed is a weapon."
/// - `race`: fully parallel, no clock. First to the target line count (`tier`)
///   wins; the others keep playing for placement until each reaches the tier
///   or dead-ends. Live scores are shown for pressure.
public enum DuelMode: Codable, Equatable, Sendable {
    case lockStep
    case race(tier: Int)

    /// The reactive turn clock for lock-step, in seconds.
    public static let turnClock: TimeInterval = 10
}
