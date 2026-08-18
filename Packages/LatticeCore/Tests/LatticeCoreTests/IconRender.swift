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

/// Emits the app icon as SVG for the website (favicon + home-page mark), so the
/// site's icon is the SAME geometry as the app's rather than a hand-drawn
/// lookalike that drifts apart from it. Gated on LATTICE_ICON_SVG.
extension IconRender {
    /// Mirrors IconView: a 15x15 lattice with a half-cell outer margin, so 16
    /// cells across a 32-unit viewBox.
    private static var cell: Double { 32.0 / Double(IconArt.gridMax + 2) }

    private static func position(_ p: LatticeCore.Point) -> (Double, Double) {
        (cell * (Double(p.x) + 1), cell * (Double(p.y) + 1))
    }

    private static func lineMarkup() -> String {
        IconArt.fieldLines().reduce(into: "") { out, line in
            guard let a = line.points.first, let b = line.points.last else { return }
            let (x1, y1) = position(a)
            let (x2, y2) = position(b)
            out += String(
                format: "    <line x1=\"%.3f\" y1=\"%.3f\" x2=\"%.3f\" y2=\"%.3f\"/>\n",
                x1, y1, x2, y2)
        }
    }

    private static func dotMarkup(radius: Double) -> String {
        let glyph = IconArt.glyphPoints
        var out = ""
        for x in 0...IconArt.gridMax {
            for y in 0...IconArt.gridMax {
                let p = LatticeCore.Point(x, y)
                guard !glyph.contains(p) else { continue }
                let (cx, cy) = position(p)
                out += String(
                    format: "    <circle cx=\"%.3f\" cy=\"%.3f\" r=\"%.3f\"/>\n",
                    cx, cy, radius)
            }
        }
        return out
    }

    /// `bold` mirrors IconView's `isTiny` branch: at 16-32px the fine strokes
    /// and small dots turn to mush, so the favicon uses the heavier weights.
    private static func svg(bold: Bool) -> String {
        let stroke = cell * (bold ? 0.18 : 0.10)
        let opacity = bold ? "0.85" : "0.55"
        return """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" role="img" \
            aria-label="Lattice Five">
              <!-- Generated from IconArt (see IconRender) — the same geometry as the app
                   icon: a dot-and-line field whose negative space forms a "5".
                   Do not hand-edit; regenerate instead. -->
              <rect width="32" height="32" rx="7" fill="#faf8f4"/>
              <g stroke="#1c1b19" stroke-opacity="\(opacity)" \
            stroke-width="\(String(format: "%.3f", stroke))" stroke-linecap="round">
            \(lineMarkup())  </g>
              <g fill="#1c1b19">
            \(dotMarkup(radius: cell * (bold ? 0.28 : 0.20)))  </g>
            </svg>

            """
    }

    func testRenderIconSVG() throws {
        guard let out = ProcessInfo.processInfo.environment["LATTICE_ICON_SVG"] else {
            throw XCTSkip("Set LATTICE_ICON_SVG to a file path to emit the SVG")
        }
        try Self.svg(bold: false).write(
            to: URL(fileURLWithPath: out), atomically: true, encoding: .utf8)
        print("wrote \(out)")
        if let small = ProcessInfo.processInfo.environment["LATTICE_ICON_SVG_SMALL"] {
            try Self.svg(bold: true).write(
                to: URL(fileURLWithPath: small), atomically: true, encoding: .utf8)
            print("wrote \(small) (bold variant for tiny sizes)")
        }
    }
}
