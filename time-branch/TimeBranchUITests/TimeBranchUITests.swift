import XCTest

@MainActor
final class TimeBranchUITests: XCTestCase {
    private func launchJapaneseApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["UITEST_INITIAL_LANGUAGE"] = "ja"
        app.launch()
        return app
    }

    func testFirstLaunchShowsCoreNavigationAndEmptyState() {
        let app = launchJapaneseApp()

        XCTAssertTrue(app.navigationBars["TimeBranch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["計測"].exists)
        XCTAssertTrue(app.tabBars.buttons["レポート"].exists)
        XCTAssertTrue(app.tabBars.buttons["プロジェクト"].exists)
        XCTAssertTrue(app.tabBars.buttons["設定"].exists)
        XCTAssertTrue(app.staticTexts["プロジェクトがありません"].exists)
    }

    func testCreateProjectTrackAndShowReportWithoutCreatingPage() {
        let app = launchJapaneseApp()
        let projectName = "UIテストプロジェクト"

        app.tabBars.buttons["プロジェクト"].tap()
        app.navigationBars["プロジェクト"].buttons["追加"].tap()

        let nameField = app.textFields["名前"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(projectName)
        app.navigationBars["プロジェクトを追加"].buttons["保存"].tap()

        app.tabBars.buttons["計測"].tap()
        let projectButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", projectName)
        ).firstMatch
        XCTAssertTrue(projectButton.waitForExistence(timeout: 3))
        projectButton.tap()
        XCTAssertTrue(app.staticTexts["計測中: \(projectName)"].waitForExistence(timeout: 3))
        projectButton.tap()

        app.tabBars.buttons["レポート"].tap()
        XCTAssertTrue(app.staticTexts[projectName].waitForExistence(timeout: 3))
    }

    func testLanguageChangePersistsAfterRelaunch() {
        let app = launchJapaneseApp()

        app.tabBars.buttons["設定"].tap()
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "表示言語")
        ).firstMatch.tap()
        app.buttons["英語"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Timer"].exists)

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "UITEST_INITIAL_LANGUAGE")
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Timer"].exists)
    }
}
