/// A structure that represents a two-dimensional size.
public struct Size {
    /// The width value of the size.
    public var width: Int

    /// The height value of the size.
    public var height: Int

    /// Creates a size with specified dimensions.
    ///
    /// - Parameters:
    ///   - width: The width value of the size
    ///   - height: The height value of the size
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

extension Size {
    /// Size whose width and height are both zero.
    public static let zero = Size(width: 0, height: 0)

    /// Creates a size with specified dimensions.
    ///
    /// - Parameters:
    ///   - width: The width value of the size
    ///   - height: The height value of the size
    public init(width: Int32, height: Int32) {
        self.init(width: Int(width), height: Int(height))
    }
}

extension Size: Comparable {
    /// Returns a Boolean value indicating whether the value of the first
    /// argument is less than that of the second argument.
    ///
    /// This function is the only requirement of the `Comparable` protocol. The
    /// remainder of the relational operator functions are implemented by the
    /// standard library for any type that conforms to `Comparable`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func < (lhs: Size, rhs: Size) -> Bool {
        return lhs.width < rhs.width && lhs.height < rhs.height
    }

    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func == (lhs: Size, rhs: Size) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}
