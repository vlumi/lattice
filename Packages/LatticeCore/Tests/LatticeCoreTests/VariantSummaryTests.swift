import LatticeCore
import SwiftUI
import XCTest

@testable import LatticeKit

/// Every selectable variant needs a summary — "5T" tells a newcomer nothing.
/// A missing one would silently render an empty line and shift the modal.
final class VariantSummaryTests: XCTestCase {
    func testEverySelectableVariantHasASummary() {
        for rules in Rules.selectable {
            let key = rules.storageKey
            let summary = NewGameModal.variantSummary(for: key)
            XCTAssertNotEqual(
                summary, Text(verbatim: ""),
                "\(key) has no description — the modal would show a blank line")
        }
    }

    /// The keys the modal switches on must match what Rules actually produces,
    /// so adding a variant can't silently fall through to the empty default.
    func testSummaryKeysMatchRulesKeys() {
        XCTAssertEqual(
            Set(Rules.selectable.map(\.storageKey)),
            Set(["5T", "5T+", "5D", "4T", "4D"]),
            "the summaries switch on these exact keys")
    }
}
