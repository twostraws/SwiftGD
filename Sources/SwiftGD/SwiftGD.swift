#if os(Linux)
	import Glibc
	import Cgdlinux
#else
	import Darwin
	import Cgdmac
#endif

import Foundation


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

        // Creates a gdImage pointer if given data represents an image in either PNG or JPEG raster format
        let createImage: (UnsafeMutablePointer<UInt8>) -> gdImagePtr? = { pointer in
            let size = Int32(data.count)
            let rawPointer = UnsafeMutableRawPointer(pointer)
            return gdImageCreateFromPngPtr(size, rawPointer) // Returns if valid PNG image data
                ?? gdImageCreateFromJpegPtr(size, rawPointer) // Returns if valid JPEG image data
                ?? gdImageCreateFromWebpPtr(size, rawPointer) // Returns if valid WEBP image data
                ?? nil
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
			case "jpg":
				fallthrough
			case "jpeg":
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
		let internalColor = gdImageColorAllocateAlpha(internalImage, Int32(color.redComponent * 255.0), Int32(color.greenComponent * 255.0), Int32(color.blueComponent * 255.0), 127 - Int32(color.alphaComponent * 127.0))
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageFill(internalImage, Int32(from.x), Int32(from.y), internalColor)
	}

	public func drawLine(from: Point, to: Point, color: Color) {
		let internalColor = gdImageColorAllocateAlpha(internalImage, Int32(color.redComponent * 255.0), Int32(color.greenComponent * 255.0), Int32(color.blueComponent * 255.0), 127 - Int32(color.alphaComponent * 127.0))
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageLine(internalImage, Int32(from.x), Int32(from.y), Int32(to.x), Int32(to.y), internalColor)
	}

	public func set(pixel: Point, to color: Color) {
		let internalColor = gdImageColorAllocateAlpha(internalImage, Int32(color.redComponent * 255.0), Int32(color.greenComponent * 255.0), Int32(color.blueComponent * 255.0), 127 - Int32(color.alphaComponent * 127.0))
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
		let internalColor = gdImageColorAllocateAlpha(internalImage, Int32(color.redComponent * 255.0), Int32(color.greenComponent * 255.0), Int32(color.blueComponent * 255.0), 127 - Int32(color.alphaComponent * 127.0))
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageEllipse(internalImage, Int32(center.x), Int32(center.y), Int32(size.width), Int32(size.height), internalColor)
	}

	public func fillEllipse(center: Point, size: Size, color: Color) {
		let internalColor = gdImageColorAllocateAlpha(internalImage, Int32(color.redComponent * 255.0), Int32(color.greenComponent * 255.0), Int32(color.blueComponent * 255.0), 127 - Int32(color.alphaComponent * 127.0))
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageFilledEllipse(internalImage, Int32(center.x), Int32(center.y), Int32(size.width), Int32(size.height), internalColor)
	}

	public func strokeRectangle(topLeft: Point, bottomRight: Point, color: Color) {
		let internalColor = gdImageColorAllocateAlpha(internalImage, Int32(color.redComponent * 255.0), Int32(color.greenComponent * 255.0), Int32(color.blueComponent * 255.0), 127 - Int32(color.alphaComponent * 127.0))
		defer { gdImageColorDeallocate(internalImage, internalColor) }

		gdImageRectangle(internalImage, Int32(topLeft.x), Int32(topLeft.y), Int32(bottomRight.x), Int32(bottomRight.y), internalColor)
	}

	public func fillRectangle(topLeft: Point, bottomRight: Point, color: Color) {
		let internalColor = gdImageColorAllocateAlpha(internalImage, Int32(color.redComponent * 255.0), Int32(color.greenComponent * 255.0), Int32(color.blueComponent * 255.0), 127 - Int32(color.alphaComponent * 127.0))
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
		gdImageColor(internalImage, Int32(color.redComponent * 255), Int32(color.greenComponent * 255), Int32(color.blueComponent * 255), 127 - Int32(color.alphaComponent * 127.0))
	}

	public func desaturate() {
		gdImageGrayScale(internalImage)
	}

	deinit {
		// always destroy our internal image resource
		gdImageDestroy(internalImage)
	}
}


public struct Point {
	public var x: Int
	public var y: Int

	public init(x: Int, y: Int) {
		self.x = x
		self.y = y
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
}

public func <(lhs: Size, rhs: Size) -> Bool {
	return lhs.width < rhs.width && lhs.height < rhs.height
}

public func ==(lhs: Size, rhs: Size) -> Bool {
	return lhs.width == rhs.width && lhs.height == rhs.height
}

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
