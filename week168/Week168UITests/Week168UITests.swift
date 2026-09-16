import XCTest

final class Week168UITests: XCTestCase {
    @MainActor
    func testAppLaunchesWithHomeScreen() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.firstMatch.buttons.count, 5)
        XCTAssertEqual(app.tabBars.firstMatch.buttons.allElementsBoundByIndex.map(\.label),
                       ["ホーム", "配分", "活動", "記録", "振り返り"])
        XCTAssertFalse(app.tabBars.buttons["その他"].exists)
        XCTAssertTrue(app.staticTexts["今週まだ届いていない目標"].waitForExistence(timeout: 5))
    }
    @MainActor
    func testSettingsOpensFromEveryTabAndClosesToOriginalTab() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))

        for label in ["ホーム", "配分", "活動", "記録", "振り返り"] {
            let tab = app.tabBars.buttons[label]
            tab.tap()
            let gear = app.buttons["settings.open"]
            XCTAssertTrue(gear.waitForExistence(timeout: 5))
            XCTAssertEqual(gear.label, "設定")
            gear.tap()
            XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
            let close = app.buttons["settings.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            close.tap()
            XCTAssertTrue(close.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.navigationBars[label].waitForExistence(timeout: 5))
            XCTAssertTrue(tab.isSelected)
        }
    }
}
