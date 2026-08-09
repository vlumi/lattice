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

        /// While a field editor types, Tab still navigates and Esc ends the
        /// edit (rather than falling through to the sheet's cancel); everything
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
            switch event.keyCode {
            case 48:  // Tab / ⇧Tab
                window.makeFirstResponder(self)
                onKey?(event.modifierFlags.contains(.shift) ? .backTab : .tab)
                return nil
            case 53:  // Esc
                window.makeFirstResponder(self)
                return nil
            default:
                return event
            }
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
