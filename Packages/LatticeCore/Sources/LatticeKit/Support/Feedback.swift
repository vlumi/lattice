import LatticeCore
import SwiftUI

/// Board feedback — bundles the sound + haptic players and the enable flags,
/// created once at the app root and read via the SwiftUI environment so views
/// don't thread two players through their initializers. The scrub-highlight
/// detent, the commit tap, and the game-over cue all route through here.
@MainActor
final class Feedback: ObservableObject {
    static let soundDefaultsKey = "lattice.sound"
    static let hapticsDefaultsKey = "lattice.haptics"

    private let sound = SoundPlayer()
    private let haptics = HapticPlayer()

    /// Sound off by default (opt-in); haptics on by default. Missing keys mean
    /// a fresh install, so seed from the defaults rather than Bool's `false`.
    init(defaults: UserDefaults = .standard) {
        sound.isEnabled = defaults.object(forKey: Self.soundDefaultsKey) as? Bool ?? false
        haptics.isEnabled = defaults.object(forKey: Self.hapticsDefaultsKey) as? Bool ?? true
    }

    var soundEnabled: Bool { sound.isEnabled }
    var hapticsEnabled: Bool { haptics.isEnabled }

    func setSound(_ on: Bool) { sound.isEnabled = on }
    func setHaptics(_ on: Bool) { haptics.isEnabled = on }

    /// The scrub highlight moved to a different candidate line.
    func selectChanged() {
        haptics.select()
        sound.play(.select)
    }

    /// A line was committed.
    func committed() {
        haptics.place()
        sound.play(.place)
    }

    /// The keyboard cursor moved onto a point of this kind — the board read by
    /// feel while roaming. Deliberately ambient, not spoken: it fires on every
    /// arrow press and has to keep up with a held-down key.
    func cursorMoved(_ state: CursorState) {
        haptics.cursor(state)
        switch state {
        case .placeable: sound.play(.cursorOpen)
        case .dot: sound.play(.cursorDot)
        case .empty: sound.play(.cursorEmpty)
        }
    }

    /// The game ended — no moves left.
    func gameOver() {
        haptics.gameOver()
        sound.play(.gameOver)
    }
}
