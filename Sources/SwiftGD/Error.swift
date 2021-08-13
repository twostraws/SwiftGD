/// Represents errors that can be thrown within the SwiftGD module.
///
/// - invalidFormat: Image raster format mismatch on import/export
/// - invalidImage: Contains the reason this error was thrown.
/// - invalidColor: Contains the reason this error was thrown.
/// - invalidMaxColors: Asserts sane values for creating indexed Images
public enum Error: Swift.Error {
    case invalidFormat
    case invalidImage(reason: String) // The reason this error was thrown
    case invalidColor(reason: String) // The reason this error was thrown.
    case invalidMaxColors(reason: String)
}
