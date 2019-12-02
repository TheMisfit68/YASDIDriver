import XCTest
@testable import YASDIDriver

final class YASDIDriverTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(YASDIDriver().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
