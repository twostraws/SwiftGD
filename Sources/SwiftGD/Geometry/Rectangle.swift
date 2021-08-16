/// A structure that represents a rectangle.
public struct Rectangle {
    /// The origin of the rectangle.
    public var point: Point

    /// The size of the rectangle.
    public var size: Size

    /// Creates a rectangle at specified point and given size.
    ///
    /// - Parameters:
    ///   - point: The origin of the rectangle
    ///   - height: The size of the rectangle
    public init(point: Point, size: Size) {
        self.point = point
        self.size = size
    }
}

extension Rectangle {
    /// Rectangle at the origin whose width and height are both zero.
    public static let zero = Rectangle(point: .zero, size: .zero)

    /// Creates a rectangle at specified point and given size.
    ///
    /// - Parameters:
    ///   - x: The x-coordinate of the point
    ///   - y: The y-coordinate of the point
    ///   - width: The width value of the size
    ///   - height: The height value of the size
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.init(point: Point(x: x, y: y), size: Size(width: width, height: height))
    }

    /// Creates a rectangle at specified point and given size.
    ///
    /// - Parameters:
    ///   - x: The x-coordinate of the point
    ///   - y: The y-coordinate of the point
    ///   - width: The width value of the size
    ///   - height: The height value of the size
    public init(x: Int32, y: Int32, width: Int32, height: Int32) {
        self.init(x: Int(x), y: Int(y), width: Int(width), height: Int(height))
    }
}

extension Rectangle: Equatable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func == (lhs: Rectangle, rhs: Rectangle) -> Bool {
        return lhs.point == rhs.point && lhs.size == rhs.size
    }
}
