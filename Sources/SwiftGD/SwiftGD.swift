#if os(Linux)
	import Glibc
	import Cgdlinux
#else
	import Darwin
	import Cgdmac
#endif

import Foundation

/// Represents errors that can be thrown within the SwiftGD module.
///
/// - invalidColor: Contains the reason this error was thrown.
public enum Error: Swift.Error {
    case invalidColor(reason: String) /// The reason this error was thrown.
}

// In case you were wondering: it's a class rather than a struct because we need
// deinit to free the internal GD pointer, and that's only available to classes.
public class Image {
	public enum FlipMode {
		case horizontal, vertical, both
	}

	private var internalImage: gdImagePtr

	public var size: Size {
		return Size(width: internalImage.pointee.sx, height: internalImage.pointee.sy)
	}

	public init?(width: Int, height: Int) {
		internalImage = gdImageCreateTrueColor(Int32(width), Int32(height))
	}

	public init?(url: URL) {
		let inputFile = fopen(url.path, "rb")
		defer { fclose(inputFile) }

		guard inputFile != nil else { return nil }

		let loadedImage: gdImagePtr?

		if url.lastPathComponent.lowercased().hasSuffix("jpg") || url.lastPathComponent.lowercased().hasSuffix("jpeg") {
			loadedImage = gdImageCreateFromJpeg(inputFile)
		} else if url.lastPathComponent.lowercased().hasSuffix("png") {
			loadedImage = gdImageCreateFromPng(inputFile)
		} else {
			return nil
		}

		if let image = loadedImage {
			internalImage = image
		} else {
			return nil
		}
	}

    public convenience init?(data: Data) {

        // Bytes must not exceed int32 as limit by `gdImageCreate..()`
        guard data.count < Int32.max else { return nil }

        // Creates a gdImage pointer if given data represents an image in of the supported raster formats
        let createImage: (UnsafeMutablePointer<UInt8>) -> gdImagePtr? = { pointer in
            let size = Int32(data.count)
            let rawPointer = UnsafeMutableRawPointer(pointer)

            if let image = gdImageCreateFromPngPtr(size, rawPointer) {
                return image
            } else if let image = gdImageCreateFromJpegPtr(size, rawPointer) {
                return image
            } else if let image = gdImageCreateFromWebpPtr(size, rawPointer) {
                return image
            } else if let image = gdImageCreateFromGifPtr(size, rawPointer) {
                return image
            } else if let image = gdImageCreateFromWBMPPtr(size, rawPointer) {
                return image
            } else if let image = gdImageCreateFromTiffPtr(size, rawPointer) {
                return image
            } else if let image = gdImageCreateFromTgaPtr(size, rawPointer) {
                return image
            } else if let image = gdImageCreateFromBmpPtr(size, rawPointer) {
                return image
            } else {
                return nil
            }
        }

        var imageData = data
        guard let gdImage = imageData.withUnsafeMutableBytes(createImage) else { return nil }
        self.init(gdImage: gdImage)
    }

	private init(gdImage: gdImagePtr) {
		self.internalImage = gdImage
	}

	@discardableResult
	public func write(to url: URL, quality: Int = 100) -> Bool {
		let fileType = url.pathExtension.lowercased()
		guard fileType == "png" || fileType == "jpeg" || fileType == "jpg" else { return false }

		let fm = FileManager()

		// refuse to overwrite existing files
		guard fm.fileExists(atPath: url.path) == false else { return false }

		// open our output file, then defer it to close
		let outputFile = fopen(url.path, "wb")
		defer { fclose(outputFile) }

		// write the correct output format based on the path extension
        switch fileType {
        case "png":
            gdImageSaveAlpha(internalImage, 1)
            gdImagePng(internalImage, outputFile)
        case "jpg", "jpeg":
            gdImageJpeg(internalImage, outputFile, Int32(quality))
        default:
            return false
		}

		// return true or false based on whether the output file now exists
		return fm.fileExists(atPath: url.path)
	}

	public func resizedTo(width: Int, height: Int, applySmoothing: Bool = true) -> Image? {
		applyInterpolation(enabled: applySmoothing, currentSize: size, newSize: Size(width: width, height: height))

		guard let output = gdImageScale(internalImage, UInt32(width), UInt32(height)) else { return nil }
		return Image(gdImage: output)
	}

	public func resizedTo(width: Int, applySmoothing: Bool = true) -> Image? {
		let currentSize = size
		let heightAdjustment = Double(width) / Double(currentSize.width)
		let newSize = Size(width: Int32(width), height: Int32(Double(currentSize.height) * Double(heightAdjustment)))

		applyInterpolation(enabled: applySmoothing, currentSize: currentSize, newSize: newSize)

		guard let output = gdImageScale(internalImage, UInt32(newSize.width), UInt32(newSize.height)) else { return nil }
		return Image(gdImage: output)
	}

	public func resizedTo(height: Int, applySmoothing: Bool = true) -> Image? {
		let currentSize = size
		let widthAdjustment = Double(height) / Double(currentSize.height)
		let newSize = Size(width: Int32(Double(currentSize.width) * Double(widthAdjustment)), height: Int32(height))

		applyInterpolation(enabled: applySmoothing, currentSize: currentSize, newSize: newSize)

		guard let output = gdImageScale(internalImage, UInt32(newSize.width), UInt32(height)) else { return nil }
		return Image(gdImage: output)
	}

	public func applyInterpolation(enabled: Bool, currentSize: Size, newSize: Size) {
		guard enabled else {
			gdImageSetInterpolationMethod(internalImage, GD_NEAREST_NEIGHBOUR)
			return
		}

		if currentSize > newSize {
			gdImageSetInterpolationMethod(internalImage, GD_SINC)
		} else if currentSize < newSize {
			gdImageSetInterpolationMethod(internalImage, GD_MITCHELL)
		} else {
			gdImageSetInterpolationMethod(internalImage, GD_NEAREST_NEIGHBOUR)
		}
	}

	public func fill(from: Point, color: Color) {
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
		let internalColor = gdImageColorAllocateAlpha(internalImage, red, green, blue, alpha)
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageFill(internalImage, Int32(from.x), Int32(from.y), internalColor)
	}

	public func drawLine(from: Point, to: Point, color: Color) {
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
        let internalColor = gdImageColorAllocateAlpha(internalImage, red, green, blue, alpha)
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageLine(internalImage, Int32(from.x), Int32(from.y), Int32(to.x), Int32(to.y), internalColor)
	}

	public func set(pixel: Point, to color: Color) {
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
        let internalColor = gdImageColorAllocateAlpha(internalImage, red, green, blue, alpha)
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageSetPixel(internalImage, Int32(pixel.x), Int32(pixel.y), internalColor)
	}

	public func get(pixel: Point) -> Color {
		let color = gdImageGetTrueColorPixel(internalImage, Int32(pixel.x), Int32(pixel.y))
        let a = Double((color >> 24) & 0xFF)
        let r = Double((color >> 16) & 0xFF)
        let g = Double((color >> 8) & 0xFF)
        let b = Double(color & 0xFF)

        return Color(red: r / 255, green: g / 255, blue: b / 255, alpha: 1 - (a / 127))
	}

	public func strokeEllipse(center: Point, size: Size, color: Color) {
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
        let internalColor = gdImageColorAllocateAlpha(internalImage, red, green, blue, alpha)
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageEllipse(internalImage, Int32(center.x), Int32(center.y), Int32(size.width), Int32(size.height), internalColor)
	}

	public func fillEllipse(center: Point, size: Size, color: Color) {
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
        let internalColor = gdImageColorAllocateAlpha(internalImage, red, green, blue, alpha)
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageFilledEllipse(internalImage, Int32(center.x), Int32(center.y), Int32(size.width), Int32(size.height), internalColor)
	}

	public func strokeRectangle(topLeft: Point, bottomRight: Point, color: Color) {
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
        let internalColor = gdImageColorAllocateAlpha(internalImage, red, green, blue, alpha)
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageRectangle(internalImage, Int32(topLeft.x), Int32(topLeft.y), Int32(bottomRight.x), Int32(bottomRight.y), internalColor)
	}

	public func fillRectangle(topLeft: Point, bottomRight: Point, color: Color) {
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
        let internalColor = gdImageColorAllocateAlpha(internalImage, red, green, blue, alpha)
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageFilledRectangle(internalImage, Int32(topLeft.x), Int32(topLeft.y), Int32(bottomRight.x), Int32(bottomRight.y), internalColor)
	}

	public func flip(_ mode: FlipMode) {
		switch mode {
		case .horizontal:
			gdImageFlipHorizontal(internalImage)
		case .vertical:
			gdImageFlipVertical(internalImage)
		case .both:
			gdImageFlipBoth(internalImage)
		}
	}

	public func pixelate(blockSize: Int) {
		gdImagePixelate(internalImage, Int32(blockSize), GD_PIXELATE_AVERAGE.rawValue)
	}

	public func blur(radius: Int) {
		if let result = gdImageCopyGaussianBlurred(internalImage, Int32(radius), -1) {
			gdImageDestroy(internalImage)
			internalImage = result
		}
	}

	public func colorize(using color: Color) {
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
		gdImageColor(internalImage, red, green, blue, alpha)
	}

	public func desaturate() {
		gdImageGrayScale(internalImage)
	}

	deinit {
		// always destroy our internal image resource
		gdImageDestroy(internalImage)
	}
}

public struct Point: Equatable {
	public var x: Int
	public var y: Int

	public init(x: Int, y: Int) {
		self.x = x
		self.y = y
	}

    public static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

public struct Size: Comparable {

	public var width: Int
	public var height: Int

	public init(width: Int, height: Int) {
		self.width = width
		self.height = height
	}

	public init(width: Int32, height: Int32) {
		self.width = Int(width)
		self.height = Int(height)
	}

    public static func < (lhs: Size, rhs: Size) -> Bool {
        return lhs.width < rhs.width && lhs.height < rhs.height
    }

    public static func == (lhs: Size, rhs: Size) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}

// MARK: - Color

public class Color {

	public var redComponent: Double
	public var greenComponent: Double
	public var blueComponent: Double
	public var alphaComponent: Double

	public init(red: Double, green: Double, blue: Double, alpha: Double) {
		redComponent = red
		greenComponent = green
		blueComponent = blue
		alphaComponent = alpha
	}

	public static let red = Color(red: 1, green: 0, blue: 0, alpha: 1)
	public static let green = Color(red: 0, green: 1, blue: 0, alpha: 1)
	public static let blue = Color(red: 0, green: 0, blue: 1, alpha: 1)
	public static let black = Color(red: 0, green: 0, blue: 0, alpha: 1)
	public static let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
}

// MARK: Hexadecimal

extension Color {

    /// The maximum representable integer for each color component.
    private static let maxHex: Int = 0xff

    /// Initializes a new `Color` instance from a given hexadecimal color string.
    ///
    /// Given string will be stripped from a single leading "#", if applicable.
    /// Resulting string must meet any of the following criteria:
    ///
    /// - Is a string with 8-characters and therefore a fully fledged hexadecimal
    ///   color representation **including** an alpha component. Given value will remain
    ///   untouched before conversion. Example: `ffeebbaa`
    /// - Is a string with 6-characters and therefore a fully fledged hexadecimal color
    ///   representation **excluding** an alpha component. Given RGB color components will
    ///   remain untouched and an alpha component of `0xff` (opaque) will be extended before
    ///   conversion. Example: `ffeebb` -> `ffeebbff`
    /// - Is a string with 4-characters and therefore a shortened hexadecimal color
    ///   representation **including** an alpha component. Each single character will be
    ///   doubled before conversion. Example: `feba` -> `ffeebbaa`
    /// - Is a string with 3-characters and therefore a shortened hexadecimal color
    ///   representation **excluding** an alpha component. Given RGB color charaacter will
    ///   be doubled and an alpha of component of `0xff` (opaque) will be extended before
    ///   conversion. Example: `feb` -> `ffeebbff`
    ///
    /// - Parameters:
    ///   - string: The hexadecimal color string.
    ///   - leadingAlpha: Indicate whether given string should be treated as ARGB (`true`) or RGBA (`false`)
    /// - Throws: `.invalidColor` if given string does not match any of the above mentioned critera or is not a hex valid color.
    public convenience init(hex string: String, leadingAlpha: Bool = false) throws {
        let string = try Color.sanitize(hex: string, leadingAlpha: leadingAlpha)
        guard let code = Int(string, radix: 16) else {
            throw Error.invalidColor(reason: "0x\(string) is not a valid hex color code")
        }
        self.init(hex: code, leadingAlpha: leadingAlpha)
    }

    /// Initializes a new `Color` instance from a given hexadecimal color values.
    ///
    /// - Parameters:
    ///   - color: The hexadecimal color value, incl. red, green, blue and alpha
    ///   - leadingAlpha: Indicate whether given code should be treated as ARGB (`true`) or RGBA (`false`)
    public convenience init(hex color: Int, leadingAlpha: Bool = false) {
        let max = Double(Color.maxHex)
        let first = Double((color >> 24) & Color.maxHex) / max
        let second = Double((color >> 16) & Color.maxHex) / max
        let third = Double((color >>  8) & Color.maxHex) / max
        let fourth = Double((color >>  0) & Color.maxHex) / max
        if leadingAlpha {
            self.init(red: second, green: third, blue: fourth, alpha: first) // ARGB
        } else {
            self.init(red: first, green: second, blue: third, alpha: fourth) // RGBA
        }
    }

    // MARK: Private helper

    /// Sanitizes given hexadecimal color string (strips # and forms proper length).
    ///
    /// - Parameters:
    ///   - string: The hexadecimal color string to sanitize
    ///   - leadingAlpha: Indicate whether given and returning string should be treated as ARGB (`true`) or RGBA (`false`)
    /// - Returns: The sanitized hexadecimal color string
    /// - Throws: `.invalidColor` if given string is not of proper length
    private static func sanitize(hex string: String, leadingAlpha: Bool) throws -> String {

        // Drop leading "#" if applicable
        var string = string.hasPrefix("#") ? String(string.dropFirst(1)) : string

        // Evaluate if short code w/wo alpha (e.g. `feb` or `feb4`). Double up the characters if so.
        if string.count == 3 || string.count == 4 {
            string = string.map({ "\($0)\($0)" }).joined()
        }

        // Evaluate if this is a fully fledged code with or without alpha (e.g. `ffaabb` or `ffaabb44`), otherwise throw error
        switch string.count {
        case 6: // Hex color code without alpha (e.g. ffeeaa)
            let alpha = String(Color.maxHex, radix: 16) // 0xff (opaque)
            return leadingAlpha ? alpha + string : string + alpha
        case 8: // Fully fledged hex color including alpha (e.g. eebbaa44)
            return string
        default:
            throw Error.invalidColor(reason: "0x\(string) has invalid hex color string length")
        }
    }
}
