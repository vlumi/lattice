import Foundation

/// The duel wire format — small Codable messages exchanged over the live
/// Nearby session. The transport (a later slice) encodes/decodes these; the
/// pure `DuelProtocol` produces and consumes them, so the whole conversation
/// is testable without a network.
public enum DuelMessage: Codable, Equatable, Sendable {
    /// Opening handshake: my display name, my per-variant bests (for the
    /// tier gate), and my clock reading (to measure skew once).
    case hello(name: String, bests: BestScores, clock: TimeInterval)
    /// The host proposes the agreed match parameters.
    case setup(seed: UInt64, variantKey: String, tier: Int)
    /// Accept the proposed setup — both accepted ⇒ the duel starts.
    case accept
    /// A committed move, with the mover's clock reading at commit (skew-
    /// adjusted by the receiver) so the opponent's countdown starts correctly.
    case move(Move, clock: TimeInterval)
    /// I reached the target tier — a win claim the opponent can verify by
    /// replaying my moves.
    case reachedTier
    /// My clock expired / I quit — I lose.
    case resign
}
