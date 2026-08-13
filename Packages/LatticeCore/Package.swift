// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LatticeCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        // Pure game logic — no UI dependencies. Headlessly testable.
        .library(name: "LatticeCore", targets: ["LatticeCore"]),
        // SwiftUI rendering + glue. Depends on LatticeCore.
        .library(name: "LatticeKit", targets: ["LatticeKit"]),
    ],
    targets: [
        .target(name: "LatticeCore"),
        .target(
            name: "LatticeKit",
            dependencies: ["LatticeCore"],
            resources: [
                .process("Resources/Localizable.xcstrings"),
                // Precomputed demo games for the screenshot harness — playing
                // them live costs ~2 minutes (see DemoSeed).
                .process("Resources/demo-games.json"),
                .process("Resources/Sounds"),
            ]
        ),
        .testTarget(
            name: "LatticeCoreTests",
            dependencies: ["LatticeCore", "LatticeKit"]
        ),
    ]
)
