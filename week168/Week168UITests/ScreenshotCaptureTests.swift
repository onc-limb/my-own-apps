import XCTest

/// Walks the app and writes a PNG per screen, for release screenshots and for eyeballing
/// layout at sizes that are awkward to reach by hand. Skipped unless WEEK168_CAPTURE is set,
/// because it is slow and produces no assertions.
final class ScreenshotCaptureTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WEEK168_CAPTURE"] == "1",
                          "Set WEEK168_CAPTURE=1 to capture screenshots.")
        directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("week168-shots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        print("WEEK168_SHOTS_DIR=\(directory.path)")
    }

    @MainActor
    func testCaptureEveryTab() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        let tabs = ["ホーム", "配分", "活動", "記録", "振り返り"]
        for (index, label) in tabs.enumerated() {
            app.tabBars.buttons[label].tap()
            usleep(1_200_000)
            capture(named: String(format: "%02d-%@", index + 1, romanised(label)))
        }

        app.tabBars.buttons["ホーム"].tap()
        usleep(600_000)
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        usleep(800_000)
        capture(named: "06-settings")
    }

    private func romanised(_ label: String) -> String {
        switch label {
        case "ホーム": "home"
        case "配分": "allocation"
        case "活動": "activities"
        case "記録": "entries"
        case "振り返り": "review"
        default: "screen"
        }
    }

    @MainActor
    private func capture(named name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = directory.appendingPathComponent("\(name).png")
        do { try data.write(to: url) } catch { XCTFail("could not write \(name): \(error)") }
    }
}
