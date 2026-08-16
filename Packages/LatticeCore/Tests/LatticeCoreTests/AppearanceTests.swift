import SwiftUI
import XCTest

@testable import LatticeKit

final class AppearanceTests: XCTestCase {
    func testForcedSchemesMapDirectly() {
        XCTAssertNil(AppearancePreference.system.colorScheme, "system must not force a scheme")
        XCTAssertEqual(AppearancePreference.light.colorScheme, .light)
        XCTAssertEqual(AppearancePreference.dark.colorScheme, .dark)
    }

    /// Sheets must always be handed a CONCRETE scheme: `.preferredColorScheme(nil)`
    /// on a live sheet goes inert without releasing the previously-forced value,
    /// so `.system` would stick on whatever was chosen last.
    func testSystemResolvesToAConcreteScheme() {
        XCTAssertEqual(
            AppearancePreference.light.resolvedScheme(systemFallback: .dark), .light,
            "an explicit choice ignores the fallback")
        XCTAssertEqual(
            AppearancePreference.dark.resolvedScheme(systemFallback: .light), .dark)
        // .system resolves to the live OS appearance — whatever it is, it must be
        // one of the two, never nil.
        let resolved = AppearancePreference.system.resolvedScheme(systemFallback: .light)
        XCTAssertTrue([.light, .dark].contains(resolved))
    }

    func testRoundTripsThroughDefaultsAsAString() {
        for option in AppearancePreference.allCases {
            XCTAssertEqual(AppearancePreference(rawValue: option.rawValue), option)
        }
        XCTAssertNil(AppearancePreference(rawValue: "sepia"), "unknown values fall back")
    }
}
