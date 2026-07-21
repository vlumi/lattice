import LatticeKit
import SwiftUI

@main
struct LatticeApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .frame(minWidth: 480, minHeight: 520)
        }
    }
}
