/// One move: place `dot`, draw `line`. The line must contain the dot — the
/// engine rejects anything else, which is what makes "free lines" (lines
/// through five pre-existing dots) impossible by construction.
public struct Move: Hashable, Codable, Sendable {
    public let dot: Point
    public let line: Line

    public init(dot: Point, line: Line) {
        self.dot = dot
        self.line = line
    }
}
