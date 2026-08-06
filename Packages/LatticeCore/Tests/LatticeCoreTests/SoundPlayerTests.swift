import XCTest

@testable import LatticeKit

/// The one headless-testable seam of the audio/haptics slice: every sound
/// effect must map to a bundled clip that loads. Actual playback + haptics need
/// a device and live in LatticeKit (coverage-ignored). Checked through the
/// player so it resolves LatticeKit's own resource bundle, not the test's.
@MainActor
final class SoundPlayerTests: XCTestCase {
    func testEveryEffectHasALoadableClip() {
        let player = SoundPlayer()
        for effect in SoundPlayer.Effect.allCases {
            XCTAssertTrue(player.loaded(effect), "missing sound resource: \(effect.rawValue).caf")
        }
    }

    func testMutedPlayIsANoOp() {
        // Off by default; playing while muted (and while enabled) must not trap.
        let player = SoundPlayer()
        for effect in SoundPlayer.Effect.allCases { player.play(effect) }
        player.isEnabled = true
        for effect in SoundPlayer.Effect.allCases { player.play(effect) }
    }

    func testSoundOffHapticsOnByDefault() {
        // Fresh defaults (no keys): sound opts in (off), haptics on.
        let fresh = Feedback(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        XCTAssertFalse(fresh.soundEnabled)
        XCTAssertTrue(fresh.hapticsEnabled)
    }

    func testDefaultsAreHonoured() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        defaults.set(true, forKey: Feedback.soundDefaultsKey)
        defaults.set(false, forKey: Feedback.hapticsDefaultsKey)
        let feedback = Feedback(defaults: defaults)
        XCTAssertTrue(feedback.soundEnabled)
        XCTAssertFalse(feedback.hapticsEnabled)
    }
}
