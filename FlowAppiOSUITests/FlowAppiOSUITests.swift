import XCTest

final class FlowAppiOSUITests: XCTestCase {
    func testLaunchShowsBottomBarTabs() throws {
        let app = XCUIApplication()
        app.launch()
        for tab in ["Home", "Tasks", "Focus", "Stats"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 5), "Missing tab \(tab)")
        }
    }
}
