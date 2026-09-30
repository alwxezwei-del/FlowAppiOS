import XCTest

final class FlowAppiOSUITests: XCTestCase {
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Flow"].waitForExistence(timeout: 2))
    }
}
