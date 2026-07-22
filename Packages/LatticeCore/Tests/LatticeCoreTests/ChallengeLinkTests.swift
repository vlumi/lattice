import Foundation
import XCTest

@testable import LatticeCore

final class ChallengeLinkTests: XCTestCase {
    func testRoundTrip() {
        for seed: UInt64 in [1, 12345, 1 << 29] {
            let url = ChallengeLink.url(for: seed)
            XCTAssertEqual(url.host(), "lattice.misaki.fi")
            XCTAssertEqual(ChallengeLink.seed(from: url), seed)
        }
    }

    func testLinkShape() {
        XCTAssertEqual(
            ChallengeLink.url(for: 12345).absoluteString,
            "https://lattice.misaki.fi/c/C1S")
    }

    func testRejectsForeignAndMalformedURLs() {
        let bad = [
            "https://example.com/c/C1S",
            "https://lattice.misaki.fi/s/C1S",
            "https://lattice.misaki.fi/c/",
            "https://lattice.misaki.fi/c/C1S/extra",
            "https://lattice.misaki.fi/",
        ]
        for string in bad {
            XCTAssertNil(ChallengeLink.seed(from: URL(string: string)!), string)
        }
    }

    func testAcceptsTrailingSlashAndLowercase() {
        XCTAssertEqual(
            ChallengeLink.seed(from: URL(string: "https://lattice.misaki.fi/c/c1s/")!),
            12345)
    }
}
