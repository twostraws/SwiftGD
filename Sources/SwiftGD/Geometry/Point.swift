/// A structure that contains a point in a two-dimensional coordinate system.
public struct Point {
    /// The x-coordinate of the point.
    public var x: Int

    /// The y-coordinate of the point.
    public var y: Int

    /// Creates a point with specified coordinates.
    ///
    /// - Parameters:
    ///   - x: The x-coordinate of the point
    ///   - y: The y-coordinate of the point
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

extension Point {
    /// The point at the origin (0,0).
    public static let zero = Point(x: 0, y: 0)

    /// Creates a point with specified coordinates.
    ///
    /// - Parameters:
    ///   - x: The x-coordinate of the point
    ///   - y: The y-coordinate of the point
    public init(x: Int32, y: Int32) {
        self.init(x: Int(x), y: Int(y))
    }
}

extension Point: Equatable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}
