import Foundation
import XCTest

@testable import LatticeCore

final class SyncTests: XCTestCase {
    private func bests(_ pairs: [String: Int]) -> BestScores {
        var b = BestScores()
        for (k, v) in pairs { b.register(v, forKey: k) }
        return b
    }

    private func log(_ days: [String: Int]) -> DailyLog {
        var l = DailyLog()
        for (k, s) in days {
            l.record(.init(score: s, finishedAt: Date(timeIntervalSince1970: 0)), for: k)
        }
        return l
    }

    // MARK: Merge algebra

    func testBestsMergeTakesMax() {
        let a = bests(["5T": 40, "5D": 12])
        let b = bests(["5T": 55, "4T": 30])
        let m = a.merged(with: b)
        XCTAssertEqual(m.best(forKey: "5T"), 55)
        XCTAssertEqual(m.best(forKey: "5D"), 12)
        XCTAssertEqual(m.best(forKey: "4T"), 30)
    }

    func testDailyLogMergeUnionsAndKeepsHigherScore() {
        let a = log(["2026-08-01": 10, "2026-08-02": 20])
        let b = log(["2026-08-02": 25, "2026-08-03": 5])
        let m = a.merged(with: b)
        XCTAssertEqual(Set(m.results.keys), ["2026-08-01", "2026-08-02", "2026-08-03"])
        XCTAssertEqual(m.results["2026-08-02"]?.score, 25)  // higher wins
    }

    func testMergeIsCommutative() {
        let a = SyncedState(bests: bests(["5T": 40]), dailyLog: log(["2026-08-01": 10]))
        let b = SyncedState(bests: bests(["5T": 55, "4T": 9]), dailyLog: log(["2026-08-02": 20]))
        XCTAssertEqual(a.merged(with: b), b.merged(with: a))
    }

    func testMergeIsIdempotent() {
        let a = SyncedState(bests: bests(["5T": 40]), dailyLog: log(["2026-08-01": 10]))
        XCTAssertEqual(a.merged(with: a), a)
        let b = SyncedState(bests: bests(["5T": 55]), dailyLog: log(["2026-08-02": 20]))
        let once = a.merged(with: b)
        XCTAssertEqual(once.merged(with: b), once)
    }

    func testBlobRoundTripAndTolerantDecode() throws {
        let state = SyncedState(bests: bests(["5T": 42]), dailyLog: log(["2026-08-01": 7]))
        let encoded = try XCTUnwrap(state.encoded())
        XCTAssertEqual(SyncedState.decoded(from: encoded), state)
        XCTAssertNil(SyncedState.decoded(from: Data("garbage".utf8)))
        // A future-version blob is refused, not merged.
        var future = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        future["version"] = SyncedState.currentVersion + 1
        let futureData = try JSONSerialization.data(withJSONObject: future)
        XCTAssertNil(SyncedState.decoded(from: futureData))
    }

    // MARK: Coordinator

    private final class MemoryLocal: SyncCoordinator.LocalState {
        var state: SyncedState
        init(_ s: SyncedState) { state = s }
        func load() -> SyncedState { state }
        func save(_ s: SyncedState) { state = s }
    }

    func testEnablingPullsCloudDownAndPushesUnionUp() {
        let local = MemoryLocal(
            SyncedState(bests: bests(["5T": 40]), dailyLog: log(["2026-08-01": 10])))
        let cloudState = SyncedState(bests: bests(["5T": 55]), dailyLog: log(["2026-08-02": 20]))
        let cloud = FakeCloudStore(stored: cloudState.encoded())

        let coord = SyncCoordinator(local: local, cloud: cloud, enabled: false)
        coord.setEnabled(true)

        // Local now holds the union.
        XCTAssertEqual(local.state.bests.best(forKey: "5T"), 55)
        XCTAssertEqual(Set(local.state.dailyLog.results.keys), ["2026-08-01", "2026-08-02"])
        // Cloud now holds the union too.
        XCTAssertEqual(SyncedState.decoded(from: cloud.read()!), local.state)
    }

    func testExternalChangeSelfHeals() {
        let local = MemoryLocal(SyncedState(bests: bests(["5T": 40])))
        let cloud = FakeCloudStore(stored: SyncedState(bests: bests(["5T": 40])).encoded())
        let coord = SyncCoordinator(local: local, cloud: cloud, enabled: true)

        var changes = 0
        coord.onStateChanged = { _ in changes += 1 }
        // Another device pushes a higher best.
        cloud.inject(SyncedState(bests: bests(["5T": 70])).encoded()!)

        XCTAssertEqual(local.state.bests.best(forKey: "5T"), 70)
        XCTAssertEqual(changes, 1)
    }

    func testDisabledIsInert() {
        let local = MemoryLocal(SyncedState(bests: bests(["5T": 40])))
        let cloud = FakeCloudStore(stored: SyncedState(bests: bests(["5T": 99])).encoded())
        let coord = SyncCoordinator(local: local, cloud: cloud, enabled: false)
        coord.localDidChange()
        XCTAssertEqual(local.state.bests.best(forKey: "5T"), 40, "no pull while disabled")
    }

    func testUnavailableCloudIsInert() {
        let local = MemoryLocal(SyncedState(bests: bests(["5T": 40])))
        let cloud = FakeCloudStore(
            isAvailable: false, stored: SyncedState(bests: bests(["5T": 99])).encoded())
        let coord = SyncCoordinator(local: local, cloud: cloud, enabled: true)
        coord.localDidChange()
        XCTAssertEqual(local.state.bests.best(forKey: "5T"), 40, "no sync without iCloud")
    }

    func testConvergenceNoWriteLoop() {
        // Two devices over one shared cloud slot converge, and a reconcile
        // once converged does not rewrite the cloud.
        let cloud = FakeCloudStore()
        let d1 = MemoryLocal(SyncedState(bests: bests(["5T": 40])))
        let d2 = MemoryLocal(SyncedState(bests: bests(["5T": 55])))
        let c1 = SyncCoordinator(local: d1, cloud: cloud, enabled: true)
        let c2 = SyncCoordinator(local: d2, cloud: cloud, enabled: true)
        c1.localDidChange()  // pushes 40
        c2.localDidChange()  // pulls 40, pushes 55
        c1.localDidChange()  // pulls 55
        XCTAssertEqual(d1.state.bests.best(forKey: "5T"), 55)
        XCTAssertEqual(d2.state.bests.best(forKey: "5T"), 55)
        let before = cloud.read()
        c1.localDidChange()  // already converged
        XCTAssertEqual(cloud.read(), before, "no redundant write once converged")
    }
}
