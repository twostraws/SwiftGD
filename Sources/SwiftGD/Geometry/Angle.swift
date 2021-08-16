/// A structure that represents a geometric angle.
public struct Angle {
    /// The angle value in radians.
    public var radians: Double

    /// The angle value in degrees.
    public var degrees: Double {
        get { radians * (180.0 / .pi) }
        set { radians = newValue * (.pi / 180.0) }
    }

    /// Creates an angle with the specified radians.
    ///
    /// - Parameter radians: The radians of the angle.
    public init(radians: Double) {
        self.radians = radians
    }

    /// Creates an angle with the specified degrees.
    ///
    /// - Parameter degrees: The degrees of the angle.
    public init(degrees: Double) {
        self.init(radians: degrees * (.pi / 180.0))
    }
}

extension Angle {
    /// A zero angle.
    public static let zero = Angle(degrees: 0)

    /// An angle.
    ///
    /// - Parameter radians: The radians of the angle.
    /// - Returns: A new `Angle` instance with the specified radians.
    public static func radians(_ radians: Double) -> Angle {
        return Angle(radians: radians)
    }

    /// An angle.
    ///
    /// - Parameter degrees: The degrees of the angle.
    /// - Returns: A new `Angle` instance with the specified degrees.
    public static func degrees(_ degrees: Double) -> Angle {
        return Angle(degrees: degrees)
    }
}
