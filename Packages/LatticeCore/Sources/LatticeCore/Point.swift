/// A dot position on the unbounded integer lattice.
public struct Point: Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    /// The point `count` steps along `axis` in its canonical direction
    /// (negative counts step the other way).
    public func offset(along axis: Axis, by count: Int) -> Point {
        Point(x + axis.step.dx * count, y + axis.step.dy * count)
    }
}
