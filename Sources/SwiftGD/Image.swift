#if os(Linux)
import Glibc
#else
import Darwin
#endif

import Foundation
import gd

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

    public var transparent: Bool = false {
        didSet {
            gdImageSaveAlpha(internalImage, transparent ? 1 : 0)
            gdImageAlphaBlending(internalImage, transparent ? 0 : 1)
        }
    }

    public init?(width: Int, height: Int) {
        internalImage = gdImageCreateTrueColor(Int32(width), Int32(height))
    }

    private init(gdImage: gdImagePtr) {
        self.internalImage = gdImage
    }
    
    public func cloned() -> Image? {
        guard let output = gdImageClone(internalImage) else { return nil }
        return Image(gdImage: output)
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
    
    public func cropped(to rect: Rectangle) -> Image? {
        var rect = gdRect(x: Int32(rect.point.x), y: Int32(rect.point.y), width: Int32(rect.size.width), height: Int32(rect.size.height))

        guard let output = gdImageCrop(internalImage, &rect) else { return nil }
        return Image(gdImage: output)
    }

    public func rotated(_ angle: Angle) -> Image? {
        guard let output = gdImageRotateInterpolated(internalImage, Float(angle.degrees), 0) else { return nil }
        return Image(gdImage: output)
    }

    public func flipped(_ mode: FlipMode) -> Image? {
        guard let output = gdImageClone(internalImage) else { return nil }
        switch mode {
        case .horizontal:
            gdImageFlipHorizontal(output)
        case .vertical:
            gdImageFlipVertical(output)
        case .both:
            gdImageFlipBoth(output)
        }
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

    /// Renders an UTF-8 string onto the image.
    ///
    /// The text will be rendered from the specified basepoint:
    ///
    ///     let basepoint = Point(x: 20, y: 200)
    ///     image.renderText(
    ///         "SwiftGD",
    ///         from: basepoint,
    ///         fontList: ["SFCompact"],
    ///         color: .red,
    ///         size: 100,
    ///         angle: .degrees(90)
    ///     )
    ///
    /// - Parameters:
    ///   - text: The string to render.
    ///   - from: The basepoint (roughly the lower left corner) of the first
    ///     letter.
    ///   - fontList: A list of font filenames to look for. The first match
    ///     will be used.
    ///   - color: The font color.
    ///   - size: The height of the font in typographical points (pt).
    ///   - angle: The angle to rotate the rendered text from the basepoint
    ///     perspective. Positive angles rotate clockwise.
    /// - Returns: The rendered text bounding box. You can use this output to
    ///   render the text off-image first, and then render it again, on the
    ///   image, with the bounding box information (e.g., to center-align the
    ///   text).
    @discardableResult
    public func renderText(
        _ text: String, from: Point, fontList: [String], color: Color, size: Double, angle: Angle = .zero
    ) -> (upperLeft: Point, upperRight: Point, lowerRight: Point, lowerLeft: Point) {
        /// Notes on `gdImageStringFT`:
        /// - it returns an Tuple of empty `Point`s if there is nothing to render or no valid fonts
        /// - `gdImageStringFT` accepts a semicolon delimited list of fonts.
        /// - `gdImageStringFT` expects pointers to `text` and `fontList` values
        guard !text.isEmpty,
              !fontList.isEmpty,
              var textCChar = text.cString(using: .utf8),
              var joinedFonts = fontList.joined(separator: ";").cString(using: .utf8) else {
                  return (upperLeft: .zero, upperRight: .zero, lowerRight: .zero, lowerLeft: .zero)
        }
        let red = Int32(color.redComponent * 255.0)
        let green = Int32(color.greenComponent * 255.0)
        let blue = Int32(color.blueComponent * 255.0)
        let alpha = 127 - Int32(color.alphaComponent * 127.0)
        let internalColor = gdImageColorAllocateAlpha(internalImage, red, green, blue, alpha)
        defer { gdImageColorDeallocate(internalImage, internalColor) }

        // `gdImageStringFT` returns the text bounding box, specified as four
        // points in the following order:
        // lower left, lower right, upper right, and upper left corner.
        var boundingBox: [Int32] = .init(repeating: .zero, count: 8)
        gdImageStringFT(internalImage, &boundingBox, internalColor, &joinedFonts, size, -angle.radians, Int32(from.x), Int32(from.y), &textCChar)

        let lowerLeft = Point(x: boundingBox[0], y: boundingBox[1])
        let lowerRight = Point(x: boundingBox[2], y: boundingBox[3])
        let upperRight = Point(x: boundingBox[4], y: boundingBox[5])
        let upperLeft = Point(x: boundingBox[6], y: boundingBox[7])
        return (upperLeft, upperRight, lowerRight, lowerLeft)
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

    public func drawImage(_ image:Image, at topLeft: Point = .zero) {
        let width = Int32(self.size.width - topLeft.x)
        let height = Int32(self.size.height - topLeft.y)
        let dst_x = Int32(topLeft.x)
        let dst_y = Int32(topLeft.y)

        gdImageCopy(internalImage, image.internalImage, dst_x, dst_y, 0, 0, width, height)
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

    /// Reduces `Image` to an indexed palette of colors from larger color spaces.
    /// Index `Image`s only make sense with 2 or more colors, and will `throw` nonsense values
    /// - Parameter numberOfColors: maximum number of colors
    /// - Parameter shouldDither: true will apply GD’s internal dithering algorithm
    public func reduceColors(max numberOfColors: Int, shouldDither: Bool = true) throws {
        guard numberOfColors > 1 else {
            throw Error.invalidMaxColors(reason: "Indexed images must have at least 2 colors")
        }
        let shouldDither: Int32 = shouldDither ? 1 : 0
        gdImageTrueColorToPalette(internalImage, shouldDither, Int32(numberOfColors))
    }

    deinit {
        // always destroy our internal image resource
        gdImageDestroy(internalImage)
    }
}

// MARK: Import & Export

extension Image {
    public convenience init?(url: URL) {
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

        guard let image = loadedImage else { return nil }
        self.init(gdImage: image)
    }

    @discardableResult
    public func write(to url: URL, quality: Int = 100, allowOverwrite: Bool = false) -> Bool {
        let fileType = url.pathExtension.lowercased()
        guard fileType == "png" || fileType == "jpeg" || fileType == "jpg" else { return false }

        let fm = FileManager()

        if !allowOverwrite {
            // refuse to overwrite existing files
            guard fm.fileExists(atPath: url.path) == false else { return false }
        }

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

    /// Initializes a new `Image` instance from given image data in specified raster format.
    /// If `DefaultImportableRasterFormat` is omitted, all supported raster formats will be evaluated.
    ///
    /// - Parameters:
    ///   - data: The image data
    ///   - rasterFormat: The raster format of image data (e.g. png, webp, ...). Defaults to `.any`
    /// - Throws: `Error` if `data` in `rasterFormat` could not be converted
    public convenience init(data: Data, as format: ImportableFormat = .any) throws {
        try self.init(gdImage: format.imagePtr(of: data))
    }

    /// Exports the image as `Data` object in specified raster format.
    ///
    /// - Parameter format: The raster format of the returning image data (e.g. as jpg, png, ...). Defaults to `.png`
    /// - Returns: The image data
    /// - Throws: `Error` if the export of `self` in specified raster format failed.
    public func export(as format: ExportableFormat = .png) throws -> Data {
        return try format.data(of: internalImage)
    }
}
