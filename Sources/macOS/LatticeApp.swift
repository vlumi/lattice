import LatticeKit
import SwiftUI

@main
struct LatticeApp: App {
    var body: some Scene {
        WindowGroup {
            BoardView()
                .padding()
                .frame(minWidth: 480, minHeight: 480)
        }
    }
}
