import Foundation

/// The duel wire format — small Codable messages exchanged over the live Nearby
/// session. The transport (`NearbyMatch`) encodes/decodes these and drives the
/// pure `DuelMatch` from them.
///
/// Host-advertises model: a host advertises a configured game; a guest connects
/// and `requestJoin`s; the host accepts and, on Start, broadcasts `start` with
/// the full roster. Then `move`/`score`/`eliminated` carry the match. Messages
/// don't embed a sender — the transport knows it from the receiving peer.
public enum DuelMessage: Codable, Equatable, Sendable {
    /// Sent on connect (both directions) to exchange display names.
    case hello(name: String)
    /// Guest → host: please add me to the game you're advertising.
    case requestJoin
    /// Host → all guests: the match is starting. `roster` is the agreed player
    /// order as (tag, name) pairs, including the host; `seed` + `variantKey`
    /// build the identical board on every device.
    case start(seed: UInt64, mode: DuelMode, variantKey: String, roster: [RosterEntry])
    /// A committed move (lock-step: also marks the mover done this round).
    case move(Move)
    /// A new score (race — drives the opponents' live HUD).
    case score(Int)
    /// I'm out — clock expired, dead-ended, or resigned.
    case eliminated

    /// One roster slot: the peer's stable tag and display name.
    public struct RosterEntry: Codable, Equatable, Sendable {
        public let tag: String
        public let name: String
        public init(tag: String, name: String) {
            self.tag = tag
            self.name = name
        }
    }
}
