#if os(iOS)
import SwiftUI
import UIKit

/// Hardware-keyboard board play on iPad (or a paired keyboard on iPhone).
///
/// SwiftUI's hidden `.keyboardShortcut` buttons — what drives the Mac — never
/// fire here: iOS won't route shortcuts to a zero-opacity, accessibility-hidden
/// button. So take first responder and read `pressesBegan` directly, mapping
/// onto the same `BoardKeyCommand`s. Copy-adapted from Donpa's
/// `BoardView+iOS.KeyForwardingSKView`, which does this over SpriteKit.
///
/// Board play only, deliberately: chrome actions (New Game, Restart, Undo) are
/// on-screen buttons on iOS, not menu commands.
struct BoardKeyCatcher: UIViewRepresentable {
    /// Whether the board owns the hardware keyboard — false while an overlay is
    /// up, so its keys don't reach the board behind it.
    let enabled: Bool
    let perform: (BoardKeyCommand) -> Void

    func makeUIView(context: Context) -> KeyForwardingView {
        let view = KeyForwardingView()
        view.enabled = enabled
        view.perform = perform
        return view
    }

    func updateUIView(_ view: KeyForwardingView, context: Context) {
        view.enabled = enabled
        view.perform = perform
        // Deferred off the SwiftUI update pass: mutating the responder chain
        // synchronously here re-enters the view graph mid-update (an
        // AttributeGraph cycle). The guards re-check, so a stale hop no-ops.
        DispatchQueue.main.async { [weak view] in
            guard let view, view.window != nil else { return }
            if enabled, !view.isFirstResponder {
                view.becomeFirstResponder()
            } else if !enabled, view.isFirstResponder {
                view.resignFirstResponder()
            }
        }
    }

    final class KeyForwardingView: UIView {
        var enabled = true
        var perform: ((BoardKeyCommand) -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard enabled else { return super.pressesBegan(presses, with: event) }
            var handled = false
            for press in presses {
                guard let key = press.key, let command = Self.command(for: key) else { continue }
                perform?(command)
                handled = true
            }
            if !handled { super.pressesBegan(presses, with: event) }
        }

        private static func command(for key: UIKey) -> BoardKeyCommand? {
            switch key.keyCode {
            case .keyboardUpArrow: return .move(dx: 0, dy: 1)  // model y grows upward
            case .keyboardDownArrow: return .move(dx: 0, dy: -1)
            case .keyboardLeftArrow: return .move(dx: -1, dy: 0)
            case .keyboardRightArrow: return .move(dx: 1, dy: 0)
            case .keyboardReturnOrEnter, .keypadEnter, .keyboardSpacebar: return .activate
            case .keyboardTab: return .cycleCandidate
            case .keyboardDeleteOrBackspace: return .undo
            case .keyboardEscape: return .cancel
            default: return BoardKeyCommand.wasd(key.charactersIgnoringModifiers)
            }
        }
    }
}
#endif
