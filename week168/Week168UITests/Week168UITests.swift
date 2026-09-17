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

extension Week168UITests {
    @MainActor
    func testMaximumDynamicTypeScreensAndNamedControls() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
                                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        for title in ["ホーム", "配分", "活動", "記録", "振り返り"] {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            let gear = app.buttons["settings.open"]
            XCTAssertEqual(gear.label, "設定")
            XCTAssertTrue(gear.isHittable)
            let screen = XCTAttachment(screenshot: app.screenshot())
            screen.name = "Accessibility maximum - \(title)"
            screen.lifetime = .keepAlways
            add(screen)
            gear.tap()
            XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
            for button in app.buttons.allElementsBoundByIndex where button.isHittable {
                XCTAssertFalse(button.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            let settings = XCTAttachment(screenshot: app.screenshot())
            settings.name = "Accessibility maximum - settings from \(title)"
            settings.lifetime = .keepAlways
            add(settings)
            app.buttons["settings.close"].tap()
        }
        // Screenshots support review; actual clipping, reading order and spoken timer updates
        // must still be verified on a device with VoiceOver enabled (AC-76).
    }
}

extension Week168UITests {
    @MainActor
    func testTimingControlsNameTheirActivityAndKeepAStableReading() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["活動"].tap()
        app.buttons["活動を追加"].tap()
        let name = "Accessibility \(UUID().uuidString.prefix(8))"
        let field = app.textFields["名前"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        let save = app.buttons["活動を保存"]
        XCTAssertFalse(save.label.isEmpty)
        save.tap()
        app.tabBars.buttons["ホーム"].tap()
        let start = app.buttons["\(name) の計測を開始"].firstMatch
        for _ in 0..<12 {
            if start.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(start.isHittable)
        start.tap()
        for _ in 0..<12 {
            if app.buttons["timer.stop"].isHittable { break }
            app.swipeDown()
        }
        let stop = app.buttons["timer.stop"]
        let plan = app.buttons["timer.changePlan"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        XCTAssertEqual(stop.label, "\(name) の計測を停止")
        XCTAssertEqual(plan.label, "\(name) の予定時間を変更")
        let summary = app.descendants(matching: .any)["timer.summary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains(name))
        let reading = summary.value as? String
        XCTAssertNotNil(reading)
        XCTAssertTrue(reading?.contains("今回の経過") == true)
        // Observe the value through several visual ticks without changing accessibility focus.
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (summary.value as? String) != reading
        }, object: nil)
        changed.isInverted = true
        wait(for: [changed], timeout: 3)
        stop.tap()
    }
}

extension Week168UITests {
    @MainActor
    func testWeekStartDisplaysLocalizedMondayAndAllWeekdayChoices() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let gear = app.buttons["settings.open"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5))
        gear.tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        let picker = app.descendants(matching: .any).matching(identifier: "settings.weekStart").firstMatch
        for _ in 0..<6 {
            if picker.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        for weekday in ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"] {
            XCTAssertTrue(app.buttons[weekday].waitForExistence(timeout: 5), weekday)
        }
        // The menu's own labels are the reliable read here: the Form row wrapping the picker
        // reports an empty value through XCUITest, so asserting on it tests the harness, not
        // the app. testMajorScreenLabelsDoNotExposeLocalizationKeys covers the rendered value,
        // and fails on the interpolated-key bug this guards against.
        assertNoUnresolvedLocalizationKeys(in: app)
        app.buttons["月曜日"].tap()
        // Close without saving so the test does not change persisted calendar settings.
        XCTAssertTrue(app.buttons["settings.close"].waitForExistence(timeout: 5))
        app.buttons["settings.close"].tap()
    }

    @MainActor
    func testMajorScreenLabelsDoNotExposeLocalizationKeys() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        for title in ["ホーム", "配分", "活動", "記録", "振り返り"] {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            assertNoUnresolvedLocalizationKeys(in: app)
            app.swipeUp()
            assertNoUnresolvedLocalizationKeys(in: app)
        }
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        for _ in 0..<4 {
            assertNoUnresolvedLocalizationKeys(in: app)
            app.swipeUp()
        }
    }

    @MainActor
    private func assertNoUnresolvedLocalizationKeys(in app: XCUIApplication,
                                                   file: StaticString = #filePath, line: UInt = #line) {
        let labels = app.staticTexts.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex
        for element in labels where element.isHittable {
            for text in [element.label, element.value as? String ?? ""] {
                // Match ASCII dotted keys, including keys embedded in a combined label.
                // Plain numeric values and h:mm durations are valid display content.
                XCTAssertNil(text.range(of: #"\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+\b"#,
                                        options: .regularExpression),
                             "Unresolved localization key: \(text)", file: file, line: line)
            }
        }
    }
}
