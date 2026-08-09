import SwiftUI

/// An invisible button carrying a keyboard shortcut — the app's iOS-16-safe way
/// to bind a key, since onKeyPress needs iOS 17. Place as a `.background`.
struct HiddenShortcut: View {
    let key: KeyEquivalent
    var modifiers: EventModifiers = []
    let action: () -> Void

    var body: some View {
        Button(action: action) { Color.clear.frame(width: 1, height: 1) }
            .keyboardShortcut(key, modifiers: modifiers)
            .opacity(0)
            .accessibilityHidden(true)
    }
}
