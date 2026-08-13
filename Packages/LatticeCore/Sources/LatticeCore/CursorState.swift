/// What the keyboard cursor is sitting on. Drives the roaming feedback cues
/// (sound pitch, haptic intensity) so the board can be swept by feel.
public enum CursorState: Sendable {
    /// A legal move exists here — the point the player is hunting for.
    case placeable
    /// An existing dot.
    case dot
    /// Bare lattice: no dot, no legal move.
    case empty
}
