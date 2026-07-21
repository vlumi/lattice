/// One unit segment of a drawn line, canonically keyed: `origin` is the
/// endpoint from which the segment runs one `axis.step` in the positive
/// direction, so both drawing directions collapse to the same key.
public struct Segment: Hashable, Sendable {
    public let origin: Point
    public let axis: Axis

    public init(origin: Point, axis: Axis) {
        self.origin = origin
        self.axis = axis
    }

    /// The canonical segment between two adjacent lattice points, or nil if
    /// they aren't exactly one step apart on some axis.
    public static func between(_ a: Point, _ b: Point) -> Segment? {
        for axis in Axis.allCases {
            if a.offset(along: axis, by: 1) == b { return Segment(origin: a, axis: axis) }
            if b.offset(along: axis, by: 1) == a { return Segment(origin: b, axis: axis) }
        }
        return nil
    }

    public var endpoint: Point { origin.offset(along: axis, by: 1) }
}
