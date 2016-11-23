import XCTest
@testable import swiftgd

class swiftgdTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(swiftgd().text, "Hello, World!")
    }


    static var allTests : [(String, (swiftgdTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
