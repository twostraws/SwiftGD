# SwiftGD

This is a simple Swift wrapper for libgd, allowing for basic graphic rendering on server-side Swift where Core Graphics is not available. Although this package was originally written to accompany my book [Server-Side Swift](https://www.hackingwithswift.com/store/server-side-swift), it's likely to be of general use to anyone wishing to perform image manipulation on their server.

SwiftGD wraps GD inside classes to make it easier to use, and provides the following functionality:

- Loading PNGs and JPEGs from disk.
- Writing images back to disk as PNG or JPEG.
- Creating new images at a specific width and height.
- Resizing to a specific width or height.
- Cropping at a location and size.
- Flood filling a color from a coordinate.
- Drawing lines
- Drawing images
- Reading and writing individual pixels.
- Stroking and filling ellipses and rectangles.
- Flipping images horizontally and vertically.
- Basic effects: pixelate, blur, colorize, and desaturate.

SwiftGD manages GD resources for you, so the underlying memory is released when your images are destroyed.


## Installation

Install the GD library on your computer. If you're using macOS, install [Homebrew](http://brew.sh/) then run the command `brew install gd`. If you're using Linux, run `apt-get libgd-dev` as root.

Modify your Package.swift file to include the following dependency:

    .package(url: "https://github.com/twostraws/SwiftGD.git", from: "2.0.0")

You should also include “SwiftGD” in your list of target dependencies.

SwiftGD itself has a single Swift dependency, which is [Cgd](https://github.com/twostraws/Cgd.git).


## Classes

SwiftGD provides four classes for basic image operations:

- `Image` is responsible for loading, saving, and manipulating image data.
- `Point` stores `x` and `y` coordinates as integers.
- `Size` stores `width` and `height` integers.
- `Rectangle` combines `Point` and `Size` into one value.
- `Color` provides red, green, blue, and alpha components stored in a `Double` from 0 to 1, as well as some built-in colors to get you started.

These are implemented as classes rather than structs because only classes have deinitializers. These are required so that GD's memory can be cleaned up when an image is destroyed.


## Reading and writing images

You can load an image from disk like this:

```swift
let location = URL(fileURLWithPath: "/path/to/image.png")
let image = Image(url: location)
```

That will return an optional `Image` object, which will be `nil` if the load failed for some reason. SwiftGD uses the file extension to load the correct file format, so it's important you name your files with "jpg", "jpeg", or "png".

You can also create new images from scratch by providing a width and height, like this:

```swift
let image = Image(width: 500, height: 500)
```

Again, that will return an optional `Image` if the memory was allocated correctly.

You can even create an image from `Data` instances:

```swift  
let data: Data = ... // e.g. from networking request
let image = try Image(data: data, as: .png)
```

This will throw an `Error` if `data` is not actual an image data representation or does not match given raster format (`.png` in this case). If you omit the raster format, all supported raster formats will be evaluated and an `Image` will be returned if any matches (caution, this may take significantly longer).

When you want to save an image back to disk, use the `write(to:)` method on `Image`, like this:

```swift
let url = URL(fileURLWithPath: "/path/to/save.jpg")
image.write(to: url)
```

Again, the format is determined by your choice of file extension. `write(to:)` will return false and refuse to continue if the file exists already; it will return true if the file was saved successfully.

You can also export images as `Data` representations with certain image raster format, like so:

```swift  
let image = Image(width: 500, height: 500)
image?.fill(from: .zero, color: .red)
let data = try image?.export(as: .png)
```

This will return the data representation of a red PNG image with 500x500px in size.

Images are also created when performing a resize or crop operation, which means your original image is untouched. You have three options for resizing:

- `resizedTo(width:height:)` lets you stretch an image to any dimensions.
- `resizedTo(width:)` resizes an image to a specific width, and calculates the correct height to maintain the original aspect ratio.
- `resizedTo(height:)` resizes an image to a specific height, and calculates the correct width to maintain the original aspect ratio.

All three have an optional extra parameter, `applySmoothing`. When set to true (the default) the resize is performed using bilinear filter. When false, the resize is performed using nearest neighbor, and the result is likely to look jagged.

To crop an image, call its `cropped(to:)` method, passing in the `Rectangle` that specifies the crop origin and size.



## Drawing shapes, colors and images

There are nine methods you can use to draw into your images:

- `fill(from:color:)` performs a flood fill from a `Point` on your image using the `Color` you specify.
- `drawLine(from:to:color:)` draws a line between the `to` and `from` parameters (both instances of `Point`) in the `Color` you specify.
- `drawImage(_:at:)` draws an `Image` at the specified `Point` (or just top left if `at` is omitted).
- `set(pixel:to:)` sets a pixel at a specific `Point` to the `Color` you specify.
- `get(pixel:)` returns the `Color` value of a pixel at a specific `Point`.
- `strokeEllipse(center:size:color:)` draws an empty ellipse at the center `Point`, with the `Size` and `Color` you specify.
- `func fillEllipse(center:size:color:)` fills an ellipse at the center `Point`, with the `Size` and `Color` you specify.
- `strokeRectangle(topLeft:bottomRight:color:)` draws an empty rectangle from `topLeft` to `bottomRight` (both instances of `Point`) using the `Color` you specify.
- `fillRectangle(topLeft:bottomRight:color:)` fills a rectangle from `topLeft` to `bottomRight` (both instances of `Point`) using the `Color` you specify.


## Manipulating images

There are several methods that apply filters to image objects:

- `pixelate(blockSize:)` simplifies your image to large pixels, with the pixel size dictated by the integer you provide as `blockSize`.
- `blur(radius:)` applies a Gaussian blur effect. Using a larger value for radius causes stronger blurs.
- `colorize(using:)` applies a tint using a `Color` you specify.
- `desaturate()` renders your image grayscale.
- `flip(_:)` flips your image horizontally, vertically, or both. Pass `.horizontal`, ``vertical`, or `.both` as its parameter.



## Example code

This first example creates a new 500x500 image, fills it red, draw a blue ellipse in the center, draws a green rectangle on top, runs the desaturate and colorize filters, and saves the resulting image to "output-1.png":

```swift
import Foundation
import SwiftGD

// figure out where to save our file
let currentDirectory = URL(fileURLWithPath: FileManager().currentDirectoryPath)
let destination = currentDirectory.appendingPathComponent("output-1.png")

// attempt to create a new 500x500 image
if let image = Image(width: 500, height: 500) {
    // flood from from X:250 Y:250 using red
    image.fill(from: Point(x: 250, y: 250), color: Color.red)

    // draw a filled blue ellipse in the center
    image.fillEllipse(center: Point(x: 250, y: 250), size: Size(width: 150, height: 150), color: Color.blue)
        
    // draw a filled green rectangle also in the center
    image.fillRectangle(topLeft: Point(x: 200, y: 200), bottomRight: Point(x: 300, y: 300), color: Color.green)

    // remove all the colors from the image
    image.desaturate()
        
    // now apply a dark red tint
    image.colorize(using: Color(red: 0.3, green: 0, blue: 0, alpha: 1))
        
    // save the final image to disk
    image.write(to: destination)
}
```

This second examples draws concentric rectangles in alternating blue and white colors, then applies a Gaussian blur to the result:

```swift
import Foundation
import SwiftGD

let currentDirectory = URL(fileURLWithPath: FileManager().currentDirectoryPath)
let destination = currentDirectory.appendingPathComponent("output-2.png")

if let image = Image(width: 500, height: 500) {
    var counter = 0
        
    for i in stride(from: 0, to: 250, by: 10) {
        let drawColor: Color
        
        if counter % 2 == 0 {
            drawColor = .blue
        } else {
            drawColor = .white
        }
        
        image.fillRectangle(topLeft: Point(x: i, y: i), bottomRight: Point(x: 500 - i, y: 500 - i), color: drawColor)
        counter += 1
    }

    image.blur(radius: 10)
    image.write(to: destination)
}
```

This third example creates a black, red, green, and yellow gradient by setting individual pixels in a nested loop:

```swift
import Foundation
import SwiftGD

let currentDirectory = URL(fileURLWithPath: FileManager().currentDirectoryPath)
let destination = currentDirectory.appendingPathComponent("output-3.png")

let size = 500

if let image = Image(width: size, height: size) {
    for x in 0 ... size {
        for y in 0 ... size {
            image.set(pixel: Point(x: x, y: y), to: Color(red: Double(x) / Double(size), green: Double(y) / Double(size), blue: 0, alpha: 1))
        }
    }
        
    image.write(to: destination)
}
```


## License

This package is released under the MIT License, which is copied below.

Copyright (c) 2017 Paul Hudson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
