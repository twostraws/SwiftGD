import XCTest
@testable import SwiftGD

class TestImage: XCTestCase {
    private func assertEmptyBounds(for resultValues: Mirror.Child?) {
        guard let resultValues = resultValues?.value as? (upperLeft: Point, upperRight: Point, lowerRight: Point, lowerLeft: Point) else {
            XCTFail("Not a valid render result")
            return
        }
        XCTAssertEqual(resultValues.upperLeft, Point.zero)
        XCTAssertEqual(resultValues.upperRight, Point.zero)
        XCTAssertEqual(resultValues.lowerRight, Point.zero)
        XCTAssertEqual(resultValues.lowerLeft, Point.zero)
    }
    
    func testRenderText() {
        let image = Image(width: 640, height: 480)
        let render = image?.renderText("", from: .zero, fontList: ["Arial", "Ubuntu", "Roboto"], color: .black, size: 18.0)
        let mirror = render.customMirror
        let result = mirror.children.first
        
        switch result {
        case .some(let child):
            assertEmptyBounds(for: child)
        case .none:
            XCTFail("Did not get expected return type")
        }
    }
}
