import AppKit

/// A FIXED window size for the App Store screenshot pass, so every capture
/// generation is pixel-identical (a hand-dragged window never is). 1440×900 is
/// a clean 16:10 above Apple's 1280×800 Mac minimum, and on a Retina display it
/// captures at 2880×1800 — both sizes App Store Connect accepts.
///
/// Demo mode only: a normal launch keeps whatever size the user left.
/// Copy-adapted from Donpa's `WindowSizer` (plumbing kept in sync).
enum WindowSizer {
    /// Retries briefly: at `onAppear` the window may not be visible yet (the
    /// Window scene restores its frame late), and giving up silently left a
    /// capture run at whatever size the window happened to have.
    static func fixToScreenshotSize(attempt: Int = 0) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible })
        else {
            if attempt < 20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    fixToScreenshotSize(attempt: attempt + 1)
                }
            }
            return
        }
        window.setContentSize(CGSize(width: 1440, height: 900))
        window.center()
    }
}
