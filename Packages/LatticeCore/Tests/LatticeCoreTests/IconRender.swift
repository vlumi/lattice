import XCTest

@testable import LatticeCore
@testable import LatticeKit

/// Asset generation, not a test of logic: renders the app icon PNGs when
/// LATTICE_ICON_OUT names a directory (`make icon` drives this). Skipped in
/// normal runs.
final class IconRender: XCTestCase {
    @MainActor
    func testRenderIconAssets() throws {
        guard let out = ProcessInfo.processInfo.environment["LATTICE_ICON_OUT"] else {
            throw XCTSkip("Set LATTICE_ICON_OUT to render icon assets")
        }
        let directory = URL(fileURLWithPath: out, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        for appearance in IconArt.Appearance.allCases {
            let data = try XCTUnwrap(IconArt.pngData(pixels: 1024, appearance: appearance))
            try data.write(to: directory.appendingPathComponent("icon-\(appearance).png"))
        }
        // macOS slots, downscaled from the same art.
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let data = try XCTUnwrap(IconArt.pngData(pixels: size, appearance: .light))
            try data.write(to: directory.appendingPathComponent("mac-\(size).png"))
        }
    }

    func testFieldIsDeterministicAndLegal() {
        let first = IconArt.fieldLines()
        XCTAssertEqual(first, IconArt.fieldLines())
        XCTAssertGreaterThan(first.count, 30, "the field should be dense")
        // No segment repeats — the field is a legal 5T-style drawing.
        var used = Set<Segment>()
        for line in first {
            for segment in line.segments {
                XCTAssertTrue(used.insert(segment).inserted)
            }
        }
    }

    @MainActor
    func testMarketingIconsHaveNoAlpha() throws {
        // App Store marketing icons are rejected (shown blank) if they carry
        // an alpha channel. Light/dark must be opaque; tinted is the alpha
        // punch-out and keeps it.
        for appearance in [IconArt.Appearance.light, .dark] {
            let data = try XCTUnwrap(IconArt.pngData(pixels: 64, appearance: appearance))
            XCTAssertEqual(pngColorType(data), 2, "\(appearance) must be opaque RGB (no alpha)")
        }
        let tinted = try XCTUnwrap(IconArt.pngData(pixels: 64, appearance: .tinted))
        XCTAssertEqual(pngColorType(tinted), 6, "tinted keeps its alpha punch-out")
    }

    /// The IHDR colour-type byte of a PNG (offset 25): 2 = RGB, 6 = RGBA.
    private func pngColorType(_ data: Data) -> Int { Int(data[25]) }
}
