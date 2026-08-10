#if os(macOS)
import AppKit
import SwiftUI

/// Invisible AppKit view that takes first responder and forwards the keyboard
/// vocabulary — arrows, Return, Esc, Space, Tab/⇧Tab, plain letters. Used where
/// SwiftUI's own key handling is unreliable: hidden `.keyboardShortcut` buttons
/// buried in an overlay/sheet/Form don't receive keys, but this does. One
/// catcher per window — two would fight over first responder.
struct KeyCatcher: NSViewRepresentable {
    enum Key: Equatable {
        case up, down, left, right, enter, escape, space, tab, backTab
        case delete, home, end, pageUp, pageDown
        case character(Character)
    }
    let onKey: (Key) -> Void
    /// When true, never steal first responder from an active text field (a
    /// surface mixing list nav with an editable field, e.g. the code field).
    var yieldsToTextFields = false

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKey = onKey
        view.yieldsToTextFields = yieldsToTextFields
        return view
    }

    func updateNSView(_ view: KeyCatcherView, context: Context) {
        view.onKey = onKey
        view.yieldsToTextFields = yieldsToTextFields
        view.claimFocus()
    }

    final class KeyCatcherView: NSView {
        var onKey: ((Key) -> Void)?
        var yieldsToTextFields = false
        private var fieldMonitor: Any?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let fieldMonitor {
                NSEvent.removeMonitor(fieldMonitor)
                self.fieldMonitor = nil
            }
            guard window != nil else { return }
            claimFocus()
            if yieldsToTextFields { installFieldMonitor() }
        }

        deinit {
            if let fieldMonitor { NSEvent.removeMonitor(fieldMonitor) }
        }

        /// While a field editor types, Tab/Enter/Esc end the edit and are
        /// forwarded to the app (so it can move focus off the field); everything
        /// else types. A local monitor, since the catcher isn't first responder
        /// while the field editor is.
        private func installFieldMonitor() {
            guard fieldMonitor == nil else { return }
            let handler = { [weak self] (event: NSEvent) in self?.interceptField(event) ?? event }
            fieldMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
        }

        private func interceptField(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window,
                window.firstResponder is NSTextView
            else { return event }
            // Tab / Enter / Esc all LEAVE the field (hand first responder back to
            // the catcher) and forward the key, so the app returns to key-nav.
            // Consumed here so Esc can't bubble up and dismiss the sheet.
            let leaveKey: Key
            switch event.keyCode {
            case 48: leaveKey = event.modifierFlags.contains(.shift) ? .backTab : .tab
            case 36, 76: leaveKey = .enter
            case 53: leaveKey = .escape
            default: return event  // types into the field
            }
            window.makeFirstResponder(self)
            onKey?(leaveKey)
            // The field editor's teardown can steal first responder back right
            // after this — re-claim once it settles, so key-nav resumes without
            // needing a Tab press.
            claimFocus()
            return nil
        }

        /// Re-take first responder, deferred so it wins after the board/panel.
        func claimFocus() {
            guard let window else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window === window else { return }
                if self.yieldsToTextFields, window.firstResponder is NSTextView { return }
                window.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            if let key = Self.key(for: event) {
                onKey?(key)
            } else {
                super.keyDown(with: event)
            }
        }

        /// Fixed keyCode → Key (Return/keypad both map to .enter; Delete +
        /// Forward-Delete both to .delete).
        private static let byCode: [UInt16: Key] = [
            126: .up, 125: .down, 123: .left, 124: .right,
            36: .enter, 76: .enter, 49: .space, 53: .escape,
            51: .delete, 117: .delete, 115: .home, 119: .end,
            116: .pageUp, 121: .pageDown,
        ]

        private static func key(for event: NSEvent) -> Key? {
            if let key = byCode[event.keyCode] { return key }
            if event.keyCode == 48 {  // Tab / ⇧Tab
                return event.modifierFlags.contains(.shift) ? .backTab : .tab
            }
            guard
                event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    .subtracting(.shift).isEmpty,
                let ch = event.charactersIgnoringModifiers?.lowercased().first,
                ch.isLetter
            else { return nil }
            return .character(ch)
        }
    }
}
#endif
