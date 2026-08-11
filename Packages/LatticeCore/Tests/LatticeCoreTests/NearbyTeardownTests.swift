import LatticeCore
import XCTest

@testable import LatticeKit

/// NearbyMatch owns a session, browser, advertiser and a repeating timer, and
/// installs itself as the MultipeerConnectivity delegate. Those delegate slots
/// are `unowned(unsafe)`, so the object must actually deallocate (no cycle) and
/// its teardown must be safe to run more than once.
///
/// Note: whether `deinit` cleared the delegate pointers is NOT assertable —
/// reading an `unowned(unsafe)` slot after dealloc is undefined, not nil.
@MainActor
final class NearbyTeardownTests: XCTestCase {
    func testMatchDeallocatesAfterStop() {
        weak var weakMatch: NearbyMatch?
        autoreleasepool {
            let match = NearbyMatch(name: "Tester", bests: BestScores())
            weakMatch = match
            match.start()
            match.stop()
        }
        XCTAssertNil(weakMatch, "a retain cycle would leave the radio and timer alive")
    }

    /// Being the delegate of objects it owns must not keep it alive.
    func testMatchDeallocatesWithoutExplicitStop() {
        weak var weakMatch: NearbyMatch?
        autoreleasepool {
            weakMatch = NearbyMatch(name: "Tester", bests: BestScores())
        }
        XCTAssertNil(weakMatch)
    }

    func testStopIsIdempotent() {
        let match = NearbyMatch(name: "Tester", bests: BestScores())
        match.start()
        match.stop()
        match.stop()  // onDisappear and deinit may both run it
        XCTAssertNil(match.clockTimer)
    }
}
