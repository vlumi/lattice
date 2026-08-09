import LatticeKit
import SwiftUI

@main
struct LatticeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        .commands {
            LatticeCommands(model: model)
        }
    }
}
