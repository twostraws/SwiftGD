#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Foundation
import gd

// MARK: - Importable & Exportable Formatter

/// Defines a formatter to be used on import (from data/file to gdImage) conversions
private protocol ImportableFormatter {
    /// Creates a `gdImagePtr` from given image data.
    ///
    /// - Parameter data: The image data of which an image should be instantiated.
    /// - Returns: The `gdImagePtr` of the instantiated image.
    /// - Throws: `Error` if import failed.
    func imagePtr(of data: Data) throws -> gdImagePtr
}

/// Defines a formatter to be used on export (from gdImage to data/file) conversions
private protocol ExportableFormatter {
    /// Creates a data representation of given `gdImagePtr`.
    ///
    /// - Parameter imagePtr: The `gdImagePtr` of which a data representation should be instantiated.
    /// - Returns: The (raw) `Data` of the image
    /// - Throws: `Error` if export failed.
    func data(of imagePtr: gdImagePtr) throws -> Data
}

/// Defines a formatter that can be used on both, import & export, conversions
private typealias Formatter = ImportableFormatter & ExportableFormatter

// MARK: - Generic LibGd Formatter

/// Defines a formatter to be used on one libgd built-in format import conversions
private protocol LibGdImportableFormatter: ImportableFormatter {
    /// Function pointer to one of libgd's build in image create functions
    var importFunction: (_ size: Int32, _ data: UnsafeMutableRawPointer) -> gdImagePtr? { get }
}

/// Defines a formatter to be used on one of libgd built-in format with **none**-parametrizable export conversions
private protocol LibGdExportableFormatter: ExportableFormatter {
    /// Function pointer to one of libgd's build in image export functions
    var exportFunction: (_ im: gdImagePtr, _ size: UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? { get }
}

/// Defines a formatter to be used on one of libgd built-in format with **parametrizable** export conversions
private protocol LibGdParametrizableExportFormatter: ExportableFormatter {
    /// The parameters to apply on exports
    var exportParameters: Int32 { get }

    /// Function pointer to one of libgd's build in image export functions
    var exportFunction: (_ im: gdImagePtr, _ size: UnsafeMutablePointer<Int32>, _ parameters: Int32) -> UnsafeMutableRawPointer? { get }
}

/// Defines a formatter to be used on both, import & export, of one of libgd format with **none**-parametrizable export conversions
private typealias LibGdFormatter = LibGdImportableFormatter & LibGdExportableFormatter

/// Defines a formatter to be used on both, import & export, of one of libgd built-in format with **parametrizable** export conversions
private typealias LibGdParametrizableFormatter = LibGdImportableFormatter & LibGdParametrizableExportFormatter

// MARK: - Common Functions

extension LibGdImportableFormatter {
    /// Creates a `gdImagePtr` from given image data.
    ///
    /// - Parameter data: The image data of which an image should be instantiated.
    /// - Returns: The `gdImagePtr` of the instantiated image.
    /// - Throws: `Error` if import failed.
    fileprivate func imagePtr(of data: Data) throws -> gdImagePtr {
        let (pointer, size) = try data.memory()
        guard let imagePtr = importFunction(size, pointer) else {
            throw Error.invalidFormat
        }
        return imagePtr
    }
}

extension LibGdExportableFormatter {
    /// Creates a data representation of given `gdImagePtr`.
    ///
    /// - Parameter imagePtr: The `gdImagePtr` of which a data representation should be instantiated.
    /// - Returns: The (raw) `Data` of the image
    /// - Throws: `Error` if export failed.
    fileprivate func data(of imagePtr: gdImagePtr) throws -> Data {
        var size: Int32 = 0
        guard let bytesPtr = exportFunction(imagePtr, &size) else {
            throw Error.invalidFormat
        }
        return Data(bytes: bytesPtr, count: Int(size))
    }
}

extension LibGdParametrizableExportFormatter {
    /// Creates a data representation of given `gdImagePtr`.
    ///
    /// - Parameter imagePtr: The `gdImagePtr` of which a data representation should be instantiated.
    /// - Returns: The (raw) `Data` of the image
    /// - Throws: `Error` if export failed.
    fileprivate func data(of imagePtr: gdImagePtr) throws -> Data {
        var size: Int32 = 0
        guard let bytesPtr = exportFunction(imagePtr, &size, exportParameters) else {
            throw Error.invalidFormat
        }
        return Data(bytesNoCopy: bytesPtr,
                    count: Int(size),
                    deallocator: .custom({ ptr, _ in gdFree(ptr) }))
    }
}

// MARK: - Concrete LibGd Formatter

/// Defines a formatter to be used on BMP import & export conversions
private struct BMPFormatter: LibGdParametrizableFormatter {
    /// The parameters to apply on exports
    fileprivate var exportParameters: Int32

    /// Initializes a new instance of `Self` using given RLE compression option on exports
    ///
    /// - Parameter compression:
    ///     Indicates whether to apply RLE compression on export or not. Defaults to `false`.
    ///     See [Reference](https://libgd.github.io/manuals/2.2.5/files/gd_bmp-c.html)
    init(compression: Bool = false) {
        exportParameters = compression ? 1 : 0
    }

    /// Function pointer to libgd's built-in bmp image create function
    fileprivate let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromBmpPtr

    /// Function pointer to libgd's built-in bmp image export function
    fileprivate let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>, Int32) -> UnsafeMutableRawPointer? = gdImageBmpPtr
}

/// Defines a formatter to be used on GIF import & export conversions
private struct GIFFormatter: LibGdFormatter {
    /// Function pointer to libgd's built-in gif image create function
    fileprivate let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromGifPtr

    /// Function pointer to libgd's built-in gif image export function
    fileprivate let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? = gdImageGifPtr
}

/// Defines a formatter to be used on JPEG import & export conversions
private struct JPGFormatter: LibGdParametrizableFormatter {
    /// The parameters to apply on exports
    fileprivate let exportParameters: Int32

    /// Initializes a new instance of `Self` using given quality on exports
    /// For practical purposes, the quality should be a value in the range `0...95`. For values less than or equal `0` or
    /// lower, the IJG JPEG quality value (which should yield a good general quality / size tradeoff for most situations) is used.
    ///
    /// - Parameter quality:
    ///     Compression quality to apply on exports. Defaults to -1.
    ///     See [Reference](https://libgd.github.io/manuals/2.2.5/files/gd_jpeg-c.html)
    init(quality: Int32 = -1) {
        exportParameters = quality
    }

    /// Function pointer to libgd's built-in jpeg image create function
    fileprivate let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromJpegPtr

    /// Function pointer to libgd's built-in jpeg image export function
    fileprivate let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>, Int32) -> UnsafeMutableRawPointer? = gdImageJpegPtr
}

/// Defines a formatter to be used on PNG import & export conversions
private struct PNGFormatter: LibGdFormatter {
    /// Function pointer to libgd's built-in png image create function
    fileprivate let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromPngPtr

    /// Function pointer to libgd's built-in png image export function
    fileprivate let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? = gdImagePngPtr
}

/// Defines a formatter to be used on TIFF import & export conversions
private struct TIFFFormatter: LibGdFormatter {
    /// Function pointer to libgd's built-in tiff image create function
    fileprivate let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromTiffPtr

    /// Function pointer to libgd's built-in tiff image export function
    fileprivate let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? = gdImageTiffPtr
}

/// Defines a formatter to be used on TGA import & export conversions
private struct TGAFormatter: LibGdImportableFormatter {
    /// Function pointer to libgd's built-in tga image create function
    fileprivate let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromTgaPtr
}

/// Defines a formatter to be used on WBMP import & export conversions
private struct WBMPFormatter: LibGdParametrizableFormatter {
    /// The parameters to apply on exports
    fileprivate let exportParameters: Int32

    /// Initializes a new instance of `Self` using index as foreground color on exports
    ///
    /// - Parameter index:
    ///     The index of the foreground color used on exports. Any other value will be considered as background and will not be written.
    ///     See [Reference](https://libgd.github.io/manuals/2.2.5/files/gd_wbmp-c.html)
    init(index: Int32) {
        exportParameters = index
    }

    /// Function pointer to libgd's built-in wbmp image create function
    fileprivate let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromWBMPPtr

    /// Function pointer to libgd's built-in wbmp image export function
    fileprivate let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>, Int32) -> UnsafeMutableRawPointer? = gdImageWBMPPtr
}

/// Defines a formatter to be used on WEBP import & export conversions
private struct WEBPFormatter: LibGdFormatter {
    /// Function pointer to libgd's built-in webp image create function
    fileprivate let importFunction: (Int32, UnsafeMutableRawPointer) -> gdImagePtr? = gdImageCreateFromWebpPtr

    /// Function pointer to libgd's built-in webp image export function
    fileprivate let exportFunction: (gdImagePtr, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer? = gdImageWebpPtr
}

// MARK: - Convenience LibGd Format

/// Enum definition of built-in importable image raster formats
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
public enum ImportableFormat: ImportableFormatter {
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
        case .bmp: return try BMPFormatter().imagePtr(of: data)
        case .gif: return try GIFFormatter().imagePtr(of: data)
        case .jpg: return try JPGFormatter().imagePtr(of: data)
        case .png: return try PNGFormatter().imagePtr(of: data)
        case .tiff: return try TIFFFormatter().imagePtr(of: data)
        case .tga: return try TGAFormatter().imagePtr(of: data)
        case .wbmp: return try WBMPFormatter(index: -1).imagePtr(of: data)
        case .webp: return try WEBPFormatter().imagePtr(of: data)
        case .any:
            return try ([
                .jpg, .png, .gif, .webp, .tiff, .bmp, .wbmp
                ] as [ImportableFormat]).imagePtr(of: data)
        }
    }
}

/// Enum definition of built-in exportable image raster formats
///
/// - bmp: https://en.wikipedia.org/wiki/BMP_file_format
/// - gif: https://en.wikipedia.org/wiki/gif
/// - jpg: https://en.wikipedia.org/wiki/jpeg
/// - png: https://en.wikipedia.org/wiki/Portable_Network_Graphics
/// - tiff: https://en.wikipedia.org/wiki/tiff
/// - wbmp: https://en.wikipedia.org/wiki/wbmp
/// - webp: https://en.wikipedia.org/wiki/webp
/// - any: Evaluates all of the above mentioned formats on export
public enum ExportableFormat: ExportableFormatter {
    case bmp(compression: Bool)
    case gif
    case jpg(quality: Int32)
    case png
    case tiff
    case wbmp(index: Int32)
    case webp

    /// Creates a data representation of given `gdImagePtr`.
    ///
    /// - Parameter imagePtr: The `gdImagePtr` of which a data representation should be instantiated.
    /// - Returns: The (raw) `Data` of the image
    /// - Throws: `Error` if export failed.
    public func data(of imagePtr: gdImagePtr) throws -> Data {
        switch self {

        // Parametrizable image raster format
        case let .bmp(compression): return try BMPFormatter(compression: compression).data(of: imagePtr)
        case let .jpg(quality): return try JPGFormatter(quality: quality).data(of: imagePtr)
        case let .wbmp(index): return try WBMPFormatter(index: index).data(of: imagePtr)

        // None parametrizable image raster format
        case .gif: return try GIFFormatter().data(of: imagePtr)
        case .png: return try PNGFormatter().data(of: imagePtr)
        case .tiff: return try TIFFFormatter().data(of: imagePtr)
        case .webp: return try WEBPFormatter().data(of: imagePtr)
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
        
        return (pointer: try withUnsafeBytes {
            guard let baseAddress = $0.baseAddress else {
                throw Error.invalidImage(reason: "Given image data doesn't have a valid base address in memory.")
            }

            return UnsafeMutableRawPointer(mutating: baseAddress)
        }, size: Int32(count))
    }
}

extension Collection where Element: ImportableFormatter {
    /// Creates a `gdImagePtr` from given image data.
    ///
    /// - Parameter data: The image data of which an image should be instantiated.
    /// - Returns: The `gdImagePtr` of the instantiated image.
    /// - Throws: `Error` if import failed.
    fileprivate func imagePtr(of data: Data) throws -> gdImagePtr {
        for importable in self {
            if let imagePtr = try? importable.imagePtr(of: data) {
                return imagePtr
            }
        }
        throw Error.invalidImage(reason: "No matching raster formatter for given image found")
    }
}
