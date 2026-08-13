import LatticeCore
import XCTest

@testable import LatticeKit

/// Regenerates the committed demo fixture. Not a test — a generator, skipped
/// unless asked: `LATTICE_GEN_DEMO=1 swift test --filter GenerateDemoFixture`.
/// Playing the games takes ~2 minutes, which is why the result is committed
/// rather than computed at launch.
@MainActor
final class GenerateDemoFixture: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["LATTICE_GEN_DEMO"] == "1",
            "generator — opt in with LATTICE_GEN_DEMO=1")
    }

    func testWriteFixture() throws {
        let moves = DemoSeed.playFixtureGames()
        let json = try JSONEncoder().encode(moves)
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let out = root.appendingPathComponent(
            "Packages/LatticeCore/Sources/LatticeKit/Resources/demo-games.json")
        try json.write(to: out)
        print("wrote \(out.path): \(moves.count) games, \(moves.map(\.count).reduce(0, +)) moves")
    }
}
