/// A drawn line: `length` consecutive dots from `origin` along `axis` in its
/// canonical positive direction, so each physical line has exactly one
/// representation.
public struct Line: Hashable, Sendable {
    public let origin: Point
    public let axis: Axis
    public let length: Int

    public init(origin: Point, axis: Axis, length: Int) {
        self.origin = origin
        self.axis = axis
        self.length = length
    }

    public var points: [Point] {
        (0..<length).map { origin.offset(along: axis, by: $0) }
    }

    public var segments: [Segment] {
        (0..<max(0, length - 1)).map {
            Segment(origin: origin.offset(along: axis, by: $0), axis: axis)
        }
    }
}
