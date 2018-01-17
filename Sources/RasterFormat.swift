#if os(Linux)
    import Glibc
    import Cgdlinux
#else
    import Darwin
    import Cgdmac
#endif

import Foundation

// MARK: - Importable & Exportable RasterFormatter

/// Defines a formatter to be used on import (from data/file to gdImage) conversions
public protocol ImportableRasterFormatter {

    /// Creates a `gdImagePtr` from given image data.
    ///
    /// - Parameter data: The image data of which an image should be instantiated.
    /// - Returns: The `gdImagePtr` of the instantiated image.
    /// - Throws: `Error` if import failed.
    func imagePtr(of data: Data) throws -> gdImagePtr
}

/// Defines a formatter to be used on export (from gdImage to data/file) conversions
public protocol ExportableRasterFormatter {

    /// Creates a data representation of given `gdImagePtr`.
    ///
    /// - Parameter imagePtr: The `gdImagePtr` of which a data representation should be instantiated.
    /// - Returns: The (raw) `Data` of the image
    /// - Throws: `Error` if export failed.
    func data(of imagePtr: gdImagePtr) throws -> Data
}

/// Defines a formatter that can be used on both, import & export, conversions
public typealias RasterFormatter = ImportableRasterFormatter & ExportableRasterFormatter

// MARK: - Generic LibGd RasterFormatter

/// Defines the quality of compressable image export operations
public typealias Quality = Int32

/// Defines a formatter to be used on one libgd built-in raster format import conversions
public protocol LibGdImportableRasterFormatter: ImportableRasterFormatter {

    /// Function pointer to one of libgd's build in image create functions
    var importFunction: (_ size: Int32, _ data: UnsafeMutableRawPointer) -> gdImagePtr? { get }
}

/// Defines a formatter to be used on one of libgd built-in raster format with **none**-compressable export conversions
public protocol LibGdExportableRasterFormatter: ExportableRasterFormatter {

    /// Function pointer to one of libgd's build in image export functions
    var exportFunction: (_ im: gdImagePtr, _ size: UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? { get }
}

/// Defines a formatter to be used on one of libgd built-in raster format with **compressable** export conversions
public protocol LibGdCompressableExportRasterFormatter: ExportableRasterFormatter {

    /// The image quality to apply on export operations
    var quality: Quality { get }

    /// Function pointer to one of libgd's build in image export functions
    var exportFunction: (_ im: gdImagePtr, _ size: UnsafeMutablePointer<Int32>, _ quality: Int32) -> UnsafeMutableRawPointer? { get }
}

/// Defines a formatter to be used on both, import & export, of one of libgd raster format with **none**-compressable export conversions
public typealias LibGdRasterFormatter = LibGdImportableRasterFormatter & LibGdExportableRasterFormatter

/// Defines a formatter to be used on both, import & export, of one of libgd built-in raster format with **compressable** export conversions
public typealias LibGdCompressableRasterFormatter = LibGdImportableRasterFormatter & LibGdCompressableExportRasterFormatter

// MARK: - Common Functions

extension Quality {

    /// libgd uses -1 as "default quality indicator"
    /// Reference: https://libgd.github.io/manuals/2.2.4/files/gd_jpeg-c.html
    public static let `default`: Quality = -1
}

extension LibGdImportableRasterFormatter {

    /// Creates a `gdImagePtr` from given image data.
    ///
    /// - Parameter data: The image data of which an image should be instantiated.
    /// - Returns: The `gdImagePtr` of the instantiated image.
    /// - Throws: `Error` if import failed.
    public func imagePtr(of data: Data) throws -> gdImagePtr {
        let (pointer, size) = try data.memory()
        guard let imagePtr = importFunction(size, pointer) else {
            throw Error.invalidRasterFormat
        }
        return imagePtr
    }
}

extension LibGdExportableRasterFormatter {

    /// Creates a data representation of given `gdImagePtr`.
    ///
    /// - Parameter imagePtr: The `gdImagePtr` of which a data representation should be instantiated.
    /// - Returns: The (raw) `Data` of the image
    /// - Throws: `Error` if export failed.
    public func data(of imagePtr: gdImagePtr) throws -> Data {
        var size: Int32 = 0
        guard let bytesPtr = exportFunction(imagePtr, &size) else {
            throw Error.invalidRasterFormat
        }
        return Data(bytes: bytesPtr, count: Int(size))
    }
}

extension LibGdCompressableExportRasterFormatter {

    /// Creates a data representation of given `gdImagePtr`.
    ///
    /// - Parameter imagePtr: The `gdImagePtr` of which a data representation should be instantiated.
    /// - Returns: The (raw) `Data` of the image
    /// - Throws: `Error` if export failed.
    public func data(of imagePtr: gdImagePtr) throws -> Data {
        var size: Int32 = 0
        let quality = min(max(self.quality, -1), 100)
        guard let bytesPtr = exportFunction(imagePtr, &size, quality) else {
            throw Error.invalidRasterFormat
        }
        return Data(bytes: bytesPtr, count: Int(size))
    }
}

// MARK: - Concrete LibGd RasterFormatter

/// Defines a formatter to be used on BMP import & export conversions
public struct BMPRasterFormatter: LibGdCompressableRasterFormatter {

    /// The image quality to apply on export operations
    public var quality: Quality = .default

    /// Function pointer to libgd's built-in bmp image create function
    public let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromBmpPtr

    /// Function pointer to libgd's built-in bmp image export function
    public let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>, Int32) -> UnsafeMutableRawPointer? = gdImageBmpPtr
}

/// Defines a formatter to be used on GIF import & export conversions
public struct GIFRasterFormatter: LibGdRasterFormatter {

    /// Function pointer to libgd's built-in gif image create function
    public let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromGifPtr

    /// Function pointer to libgd's built-in gif image export function
    public let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? = gdImageGifPtr
}

/// Defines a formatter to be used on JPEG import & export conversions
public struct JPGRasterFormatter: LibGdCompressableRasterFormatter {

    /// The image quality to apply on export operations
    public var quality: Quality = .default

    /// Function pointer to libgd's built-in jpeg image create function
    public let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromJpegPtr

    /// Function pointer to libgd's built-in jpeg image export function
    public let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>, Int32) -> UnsafeMutableRawPointer? = gdImageJpegPtr
}

/// Defines a formatter to be used on PNG import & export conversions
public struct PNGRasterFormatter: LibGdRasterFormatter {

    /// Function pointer to libgd's built-in png image create function
    public let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromPngPtr

    /// Function pointer to libgd's built-in png image export function
    public let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? = gdImagePngPtr
}

/// Defines a formatter to be used on TIFF import & export conversions
public struct TIFFRasterFormatter: LibGdRasterFormatter {

    /// Function pointer to libgd's built-in tiff image create function
    public let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromTiffPtr

    /// Function pointer to libgd's built-in tiff image export function
    public let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? = gdImageTiffPtr
}

/// Defines a formatter to be used on TGA import & export conversions
public struct TGARasterFormatter: LibGdImportableRasterFormatter {

    /// Function pointer to libgd's built-in tga image create function
    public let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromTgaPtr
}

/// Defines a formatter to be used on WBMP import & export conversions
public struct WBMPRasterFormatter: LibGdCompressableRasterFormatter {

    /// The image quality to apply on export operations
    public var quality: Quality = .default

    /// Function pointer to libgd's built-in wbmp image create function
    public let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromWBMPPtr

    /// Function pointer to libgd's built-in wbmp image export function
    public let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>, Int32) -> UnsafeMutableRawPointer? = gdImageWBMPPtr
}

/// Defines a formatter to be used on WEBP import & export conversions
public struct WEBPRasterFormatter: LibGdRasterFormatter {

    /// Function pointer to libgd's built-in webp image create function
    public let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromWebpPtr

    /// Function pointer to libgd's built-in webp image export function
    public let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? = gdImageWebpPtr
}

// MARK: - Convenience Raster Format

/// Enum definition of built-in importable raster formatters
///
/// - bmp: https://en.wikipedia.org/wiki/BMP_file_format
/// - gif: https://en.wikipedia.org/wiki/gif
/// - jpg: https://en.wikipedia.org/wiki/jpeg
/// - png: https://en.wikipedia.org/wiki/Portable_Network_Graphics
/// - tiff: https://en.wikipedia.org/wiki/tiff
/// - tga: https://en.wikipedia.org/wiki/Truevision_TGA
/// - wbmp: https://en.wikipedia.org/wiki/wbmp
/// - webp: https://en.wikipedia.org/wiki/webp
/// - any: Evaluates all of the above mentioned formats on import
public enum ImportableRasterFormat: ImportableRasterFormatter {
    case bmp
    case gif
    case jpg
    case png
    case tiff
    case tga
    case wbmp
    case webp
    case any // Wildcard, will evaluate all of the above defined cases

    /// Creates a `gdImagePtr` from given image data.
    ///
    /// - Parameter data: The image data of which an image should be instantiated.
    /// - Returns: The `gdImagePtr` of the instantiated image.
    /// - Throws: `Error` if import failed.
    public func imagePtr(of data: Data) throws -> gdImagePtr {
        switch self {
        case .bmp: return try BMPRasterFormatter().imagePtr(of: data)
        case .gif: return try GIFRasterFormatter().imagePtr(of: data)
        case .jpg: return try JPGRasterFormatter().imagePtr(of: data)
        case .png: return try PNGRasterFormatter().imagePtr(of: data)
        case .tiff: return try TIFFRasterFormatter().imagePtr(of: data)
        case .tga: return try TGARasterFormatter().imagePtr(of: data)
        case .wbmp: return try WBMPRasterFormatter().imagePtr(of: data)
        case .webp: return try WEBPRasterFormatter().imagePtr(of: data)
        case .any:
            return try ([
                .jpg, .png, .gif, .webp, .tiff, .bmp, .wbmp
            ] as [ImportableRasterFormat]).imagePtr(of: data)
        }
    }
}

/// Enum definition of built-in exportable raster formatters
///
/// - bmp: https://en.wikipedia.org/wiki/BMP_file_format
/// - gif: https://en.wikipedia.org/wiki/gif
/// - jpg: https://en.wikipedia.org/wiki/jpeg
/// - png: https://en.wikipedia.org/wiki/Portable_Network_Graphics
/// - tiff: https://en.wikipedia.org/wiki/tiff
/// - wbmp: https://en.wikipedia.org/wiki/wbmp
/// - webp: https://en.wikipedia.org/wiki/webp
/// - any: Evaluates all of the above mentioned formats on export
public enum ExportableRasterFormat: ExportableRasterFormatter {
    case bmp(quality: Quality)
    case gif
    case jpg(quality: Quality)
    case png
    case tiff
    case wbmp(quality: Quality)
    case webp

    /// Creates a data representation of given `gdImagePtr`.
    ///
    /// - Parameter imagePtr: The `gdImagePtr` of which a data representation should be instantiated.
    /// - Returns: The (raw) `Data` of the image
    /// - Throws: `Error` if export failed.
    public func data(of imagePtr: gdImagePtr) throws -> Data {
        switch self {

        // Compressable image raster format
        case let .bmp(quality): return try BMPRasterFormatter(quality: quality).data(of: imagePtr)
        case let .jpg(quality): return try JPGRasterFormatter(quality: quality).data(of: imagePtr)
        case let .wbmp(quality): return try WBMPRasterFormatter(quality: quality).data(of: imagePtr)

        // None compressable image raster format
        case .gif: return try GIFRasterFormatter().data(of: imagePtr)
        case .png: return try PNGRasterFormatter().data(of: imagePtr)
        case .tiff: return try TIFFRasterFormatter().data(of: imagePtr)
        case .webp: return try WEBPRasterFormatter().data(of: imagePtr)
        }
    }
}

// MARK: Private helper

extension Data {

    /// Returns a reference of the raw pointer to the data array and the array size
    fileprivate func memory() throws -> (pointer: UnsafeMutableRawPointer, size: Int32) {
        // Bytes must not exceed int32 as limit by `gdImageCreate..Ptr()`
        guard count < Int32.max else {
            throw Error.invalidImage(reason: "Given image data exceeds maximum allowed bytes (must be int32 convertible)")
        }
        return (pointer: withUnsafeBytes({ UnsafeMutableRawPointer(mutating: $0) }), size: Int32(count))
    }
}

extension Collection where Element: ImportableRasterFormatter {

    /// Creates a `gdImagePtr` from given image data.
    ///
    /// - Parameter data: The image data of which an image should be instantiated.
    /// - Returns: The `gdImagePtr` of the instantiated image.
    /// - Throws: `Error` if import failed.
    public func imagePtr(of data: Data) throws -> gdImagePtr {
        for rasterFormat in self {
            if let imagePtr = try? rasterFormat.imagePtr(of: data) {
                return imagePtr
            }
        }
        throw Error.invalidImage(reason: "No matching raster formatter for given image found")
    }
}
