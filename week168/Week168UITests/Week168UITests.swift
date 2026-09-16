import XCTest

final class Week168UITests: XCTestCase {
    @MainActor
    func testAppLaunchesWithHomeScreen() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.firstMatch.buttons.count, 5)
        XCTAssertTrue(app.staticTexts["今週まだ届いていない目標"].waitForExistence(timeout: 5))
    }
}
