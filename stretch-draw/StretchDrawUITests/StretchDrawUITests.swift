import XCTest

final class StretchDrawUITests: XCTestCase {
    func testLaunchShowsOneDailyAction() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        let stretchAction = app.buttons["60秒だけやる"]
        let restAction = app.buttons["今日は休む"]
        XCTAssertTrue(stretchAction.waitForExistence(timeout: 4) || restAction.exists)
    }
}
