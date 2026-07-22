import Foundation

/// Challenge links: `https://lattice.misaki.fi/c/<code>`. Universal Links
/// open the app directly; without it, the site's fallback page shows the
/// code for manual entry. The host is PERMANENT once links have been shared
/// (additional hosts may be added later; this one must keep working).
public enum ChallengeLink {
    public static let host = "lattice.misaki.fi"

    public static func url(for seed: UInt64) -> URL {
        URL(string: "https://\(host)/c/\(SeedCode.encode(seed))")!
    }

    /// The seed of a challenge link, or nil for any other URL.
    public static func seed(from url: URL) -> UInt64? {
        guard url.host() == host else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "c" else { return nil }
        return SeedCode.decode(parts[1])
    }
}
