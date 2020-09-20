import XCTest
@testable import YASDIDriver

final class YASDIDriverTests: XCTestCase {
    
    func testYASDIConfiguration() throws {
        
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertNotNil(YASDIDriver.InstallDrivers())
        
    }
    
    static var allTests = [
        ("testYASDIConfiguration", testYASDIConfiguration),
    ]
}
