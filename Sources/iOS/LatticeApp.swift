import LatticeKit
import SwiftUI

@main
struct LatticeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        // No `.commands` here. They're menu-bar items, and iPadOS 26 builds a
        // real menu bar from them: our "Undo Move" on ⌘Z collides with the
        // standard Undo the builder already installs, and UIKit raises
        // ("Replacement elements contain duplicates") — a launch crash that
        // shipped in build 8. Everything in there is reachable on iOS by touch:
        // the tab bar, the board's own controls, the Settings tab and its rows.
    }
}
