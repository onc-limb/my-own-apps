import XCTest

final class Week168UITests: XCTestCase {
    @MainActor
    func testAppLaunchesWithPlaceholder() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["week168.placeholder"].waitForExistence(timeout: 5))
    }
}
