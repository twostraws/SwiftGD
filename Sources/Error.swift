import Foundation

/// Represents errors that can be thrown within the SwiftGD module.
///
/// - invalidImage: Contains the reason this error was thrown.
/// - invalidColor: Contains the reason this error was thrown.
public enum Error: Swift.Error {
    case invalidRasterFormat
    case invalidImage(reason: String) // The reason this error was thrown
    case invalidColor(reason: String) // The reason this error was thrown.
}
