import SwiftUI

/// Pan/zoom over the auto-fitted board. Zoom 1 = fit-to-content; pan is
/// clamped so the content can't be lost off-screen (see AGENTS.md,
/// "Board & camera").
public final class BoardCamera: ObservableObject {
    @Published public private(set) var zoom: CGFloat = 1
    @Published public private(set) var pan: CGSize = .zero

    public static let maxZoom: CGFloat = 6

    public init() {}

    public var isIdentity: Bool { zoom == 1 && pan == .zero }

    public func reset() {
        zoom = 1
        pan = .zero
    }

    public func apply(zoomDelta: CGFloat, panDelta: CGSize, in size: CGSize) {
        zoom = Self.clampZoom(zoom * zoomDelta)
        pan = Self.clampPan(
            CGSize(width: pan.width + panDelta.width, height: pan.height + panDelta.height),
            zoom: zoom, in: size)
    }

    static func clampZoom(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, 1), maxZoom)
    }

    // At zoom 1 the content fits — no panning; beyond that, the content may
    // shift at most half its overflow, keeping it covering the view.
    static func clampPan(_ pan: CGSize, zoom: CGFloat, in size: CGSize) -> CGSize {
        let maxX = size.width * (zoom - 1) / 2
        let maxY = size.height * (zoom - 1) / 2
        return CGSize(
            width: min(max(pan.width, -maxX), maxX),
            height: min(max(pan.height, -maxY), maxY))
    }
}
