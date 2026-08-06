import AVFoundation
import Foundation

/// The game's sound effects — short procedural clips (see
/// `Scripts/make-sounds.swift`), preloaded once and kept warm so a tap-to-sound
/// has no load latency. Copy-adapted from Donpa's `SoundPlayer` (plumbing kept
/// in sync with the sibling app).
@MainActor
final class SoundPlayer {
    enum Effect: String, CaseIterable {
        /// A scrub-highlight change (cycling between candidate lines).
        case select
        /// A line committed.
        case place
        /// No moves left — the game ended.
        case gameOver = "gameover"
    }

    /// Off by default — the app opts into sound (set from the Settings toggle).
    var isEnabled = false

    /// One reusable player per effect: AVAudioPlayer restarts from the top on
    /// `play()` even mid-clip, so rapid retriggers just replay. A clip that
    /// failed to load stays absent and plays as a silent no-op.
    private var players: [Effect: AVAudioPlayer] = [:]

    init() {
        configureSession()
        for effect in Effect.allCases {
            guard
                let url = Bundle.module.url(forResource: effect.rawValue, withExtension: "caf"),
                let player = try? AVAudioPlayer(contentsOf: url)
            else { continue }
            player.prepareToPlay()
            players[effect] = player
        }
    }

    func play(_ effect: Effect) {
        guard isEnabled, let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    /// Whether a clip loaded for this effect — the resource contract, checked in
    /// tests (a missing/renamed asset would otherwise just no-op silently).
    func loaded(_ effect: Effect) -> Bool { players[effect] != nil }

    /// `.ambient` = obeys the Ring/Silent switch and never stops other audio;
    /// `.mixWithOthers` lets a podcast or music keep playing underneath. macOS
    /// has no session concept, so this is iOS-only.
    private func configureSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}
