/// FNV-1a: a stable string hash for seed derivation. Swift's `hashValue` is
/// salted per process — anything persisted or shared derives from this
/// instead.
public enum StableHash {
    public static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
