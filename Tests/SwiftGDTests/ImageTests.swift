import XCTest
@testable import SwiftGD

class TestImage: XCTestCase {
    /// Trying to create a list that *should* have at least
    /// one font for most Swift-compatible platforms.
    /// NOTE: Tests might fail on platforms that don’t have
    /// one of these fonts installed. E.g.: Docker images
    internal static let fontList = [
        "SFCompact",
        "ArialMT",
        "Arial",
        "Roboto",
        "Ubuntu",
        "Noto",
        "Noto Sans",
        "SSTPro-Roman"
    ]

    func testRenderText() throws {
        guard let image = Image(width: 640, height: 480) else {
            throw Error.invalidImage(reason: "Could not initialize image")
        }
        let basepoint = Point(x: 320, y: 240)
        let renderBounds = image.renderText(
            "SwiftGD",
            from: basepoint,
            fontList: Self.fontList,
            color: .red,
            size: 50,
            angle: .degrees(-15)
        )

        XCTAssertFalse(try isEmptyBounds(for: renderBounds), "When text is rendered, it returns NON-zero Points")
    }

    func testRenderEmptyText() throws {
        guard let image = Image(width: 640, height: 480) else {
            throw Error.invalidImage(reason: "Could not initialize image")
        }
        let renderBounds = image.renderText("", from: .zero, fontList: ["Arial", "Ubuntu", "Roboto"], color: .black, size: 18.0)

        XCTAssertTrue(try isEmptyBounds(for: renderBounds), "Empty `text` values return tuple of zero-value Points")
    }

    func testRenderEmptyFontList() throws {
        guard let image = Image(width: 640, height: 480) else {
            throw Error.invalidImage(reason: "Could not create image")
        }
        let renderBounds = image.renderText("Hello, World", from: .zero, fontList: [], color: .white, size: 18.0)

        XCTAssertTrue(try isEmptyBounds(for: renderBounds), "Empty fontLists return tuple of zero-value Points")
    }
}

extension TestImage {
    private func isEmptyBounds(for resultValues: (upperLeft: Point, upperRight: Point, lowerRight: Point, lowerLeft: Point)) throws -> Bool {
        return [
            resultValues.upperLeft,
            resultValues.upperRight,
            resultValues.lowerRight,
            resultValues.lowerLeft
        ].allSatisfy {
            $0 == .zero
        }
    }
}
