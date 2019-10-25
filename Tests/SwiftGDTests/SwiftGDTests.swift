import XCTest
@testable import SwiftGD

class SwiftGDTests: XCTestCase {
    func testReduceColors() {
        let size = 16
        let imColor = Color.init(red: 0.2,
                                 green: 0.10,
                                 blue: 0.77,
                                 alpha: 1.0)
        let image = Image(width: size, height: size)
        image!.fillRectangle(topLeft: Point.zero, bottomRight: Point(x: size, y: size), color: imColor)
        try! image?.reduceColors(max: 4, shouldDither: false)
        XCTAssert(image != nil, "ReduceColors without dithering should not destroy Image instance")
        try! image?.reduceColors(max: 2, shouldDither: true)
        XCTAssert(image != nil, "ReduceColors while dithering should not destroy Image instance")
        for ii in -1...1 {
            XCTAssertThrowsError(try image?.reduceColors(max: ii), "`Image` should throw with insane maxColor values when making indexed `Image`s")
        }
    }

    static var allTests: [(String, (SwiftGDTests) -> () throws -> Void)] {
        return [
            ("testReduceColors", testReduceColors)
        ]
    }
}
