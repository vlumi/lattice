import SwiftUI

/// One vocabulary for board keyboard play on BOTH platforms: SwiftUI's hidden
/// `.keyboardShortcut` buttons drive it on macOS, and the iPad's `pressesBegan`
/// on iOS — two thin maps onto the same commands, so they can't drift apart.
/// Copy-adapted from Donpa's `BoardKeyCommand` (plumbing kept in sync).
enum BoardKeyCommand: Equatable {
    /// Roam the cursor. Left/right becomes candidate-cycling once a dot is
    /// tentative — see `BoardKeyboard.horizontal`.
    case move(dx: Int, dy: Int)
    /// Place the tentative dot, or commit the highlighted candidate line.
    case activate
    /// Step to the next candidate line.
    case cycleCandidate
    case undo
    case cancel

    /// WASD by TYPED character, so it follows the user's keyboard layout rather
    /// than physical key positions.
    static func wasd(_ characters: String?) -> BoardKeyCommand? {
        switch characters?.lowercased() {
        case "w": return .move(dx: 0, dy: 1)  // model y grows upward
        case "s": return .move(dx: 0, dy: -1)
        case "a": return .move(dx: -1, dy: 0)
        case "d": return .move(dx: 1, dy: 0)
        default: return nil
        }
    }
}
