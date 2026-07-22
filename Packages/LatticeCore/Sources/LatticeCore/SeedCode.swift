/// Human-friendly seed codes — the shareable challenge IS the seed, no
/// server. Crockford base32: no padding, case-insensitive, I/L read as 1 and
/// O as 0 so codes survive being read aloud or retyped.
public enum SeedCode {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    public static func encode(_ seed: UInt64) -> String {
        guard seed != 0 else { return "0" }
        var value = seed
        var digits: [Character] = []
        while value > 0 {
            digits.append(alphabet[Int(value % 32)])
            value /= 32
        }
        return String(digits.reversed())
    }

    public static func decode(_ code: String) -> UInt64? {
        let cleaned: [Character] = code.uppercased().compactMap { character in
            switch character {
            case "I", "L": return "1"
            case "O": return "0"
            case "-", " ": return nil
            default: return character
            }
        }
        guard !cleaned.isEmpty, cleaned.count <= 13 else { return nil }
        var value: UInt64 = 0
        for character in cleaned {
            guard let digit = alphabet.firstIndex(of: character) else { return nil }
            let shifted = value.multipliedReportingOverflow(by: 32)
            guard !shifted.overflow else { return nil }
            let added = shifted.partialValue.addingReportingOverflow(UInt64(digit))
            guard !added.overflow else { return nil }
            value = added.partialValue
        }
        return value
    }

    /// A fresh challenge seed: 30 bits, so codes stay six characters.
    public static func randomSeed() -> UInt64 {
        UInt64.random(in: 1..<(1 << 30))
    }
}
