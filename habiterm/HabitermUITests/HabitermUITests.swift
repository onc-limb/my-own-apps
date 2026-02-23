import XCTest

@MainActor
final class HabitermUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Helper

    /// 習慣を追加する共通ヘルパー
    private func addHabit(name: String) {
        // ナビゲーションバーの + ボタンをタップ
        let addButton = app.navigationBars.buttons["習慣を追加"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // 習慣名を入力
        let nameField = app.textFields["習慣の名前"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)

        // 保存ボタンをタップ
        let saveButton = app.buttons["保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
    }

    // MARK: - 1. 習慣 CRUD テスト

    /// 新規習慣を追加し、一覧に表示されることを確認
    func testAddHabit() {
        // 習慣を追加
        addHabit(name: "テスト習慣")

        // Today タブの一覧に表示されることを確認
        let habitText = app.staticTexts["テスト習慣"]
        XCTAssertTrue(habitText.waitForExistence(timeout: 5),
                      "追加した習慣 'テスト習慣' が一覧に表示されること")
    }

    /// 習慣をタップして編集できることを確認
    func testEditHabit() {
        // まず習慣を追加
        addHabit(name: "編集前の習慣")

        // 追加した習慣をタップして編集画面を開く
        let habitText = app.staticTexts["編集前の習慣"]
        XCTAssertTrue(habitText.waitForExistence(timeout: 5))
        habitText.tap()

        // 編集画面が表示されることを確認
        let editTitle = app.staticTexts["習慣を編集"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5),
                      "編集画面のタイトルが表示されること")

        // 名前を変更
        let nameField = app.textFields["習慣の名前"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        // 既存テキストをクリアして新しい名前を入力
        nameField.press(forDuration: 1.0)
        app.menuItems["すべてを選択"].tap()
        nameField.typeText("編集後の習慣")

        // 保存
        let saveButton = app.buttons["保存"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // 変更後の名前が一覧に表示されることを確認
        let updatedText = app.staticTexts["編集後の習慣"]
        XCTAssertTrue(updatedText.waitForExistence(timeout: 5),
                      "変更後の名前 '編集後の習慣' が一覧に表示されること")
    }

    /// 習慣を削除できることを確認
    func testDeleteHabit() {
        // まず習慣を追加
        addHabit(name: "削除対象の習慣")

        // 追加した習慣が表示されていることを確認
        let habitText = app.staticTexts["削除対象の習慣"]
        XCTAssertTrue(habitText.waitForExistence(timeout: 5))

        // 習慣をタップして編集画面を開く
        habitText.tap()

        // 編集画面が表示されることを確認
        let editTitle = app.staticTexts["習慣を編集"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5))

        // 削除ボタンをタップ
        let deleteButton = app.buttons["この習慣を削除"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        // 一覧から消えていることを確認
        let deletedText = app.staticTexts["削除対象の習慣"]
        XCTAssertFalse(deletedText.waitForExistence(timeout: 3),
                       "削除した習慣が一覧から消えていること")
    }

    // MARK: - 2. タイマー操作テスト

    /// タイマーを開始しカウントダウンが表示される
    func testTimerStart() {
        // 習慣を追加
        addHabit(name: "タイマーテスト")

        // タイマーボタンをタップ
        let timerButton = app.buttons["タイマーを開始"]
        XCTAssertTrue(timerButton.waitForExistence(timeout: 5))
        timerButton.tap()

        // タイマー画面が表示されることを確認（習慣名がタイトルに表示）
        let timerTitle = app.staticTexts["タイマーテスト"]
        XCTAssertTrue(timerTitle.waitForExistence(timeout: 5),
                      "タイマー画面に習慣名が表示されること")

        // 「開始」ボタンをタップ
        let startButton = app.buttons["タイマーを開始"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // 「一時停止」ボタンが表示される = タイマーが開始された
        let pauseButton = app.buttons["一時停止"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5),
                      "タイマー開始後に一時停止ボタンが表示されること")
    }

    /// 一時停止・再開が動作する
    func testTimerPauseResume() {
        // 習慣を追加
        addHabit(name: "一時停止テスト")

        // タイマーボタンをタップ
        let timerButton = app.buttons["タイマーを開始"]
        XCTAssertTrue(timerButton.waitForExistence(timeout: 5))
        timerButton.tap()

        // タイマー画面でタイマーを開始
        let startButton = app.buttons["タイマーを開始"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // 「一時停止」ボタンをタップ
        let pauseButton = app.buttons["一時停止"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))
        pauseButton.tap()

        // 「再開」ボタンが表示されることを確認
        let resumeButton = app.buttons["タイマーを再開"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5),
                      "一時停止後に再開ボタンが表示されること")
    }

    // MARK: - 3. 週間カレンダーテスト

    /// Weekly タブで週間カレンダーが表示される
    func testWeeklyCalendarDisplay() {
        // Weekly タブをタップ
        let weeklyTab = app.tabBars.buttons["Weekly"]
        XCTAssertTrue(weeklyTab.waitForExistence(timeout: 5))
        weeklyTab.tap()

        // "Weekly" タイトルが表示されることを確認
        let weeklyTitle = app.staticTexts["Weekly"]
        XCTAssertTrue(weeklyTitle.waitForExistence(timeout: 5),
                      "Weekly タブで 'Weekly' タイトルが表示されること")
    }

    /// 習慣追加後に週間カレンダーにその習慣が表示される
    func testWeeklyCalendarShowsHabit() {
        // Today タブで習慣を追加
        addHabit(name: "週間テスト習慣")

        // 追加されたことを確認
        let habitInToday = app.staticTexts["週間テスト習慣"]
        XCTAssertTrue(habitInToday.waitForExistence(timeout: 5))

        // Weekly タブに切り替え
        let weeklyTab = app.tabBars.buttons["Weekly"]
        XCTAssertTrue(weeklyTab.waitForExistence(timeout: 5))
        weeklyTab.tap()

        // 追加した習慣名が Weekly タブに表示されることを確認
        let habitInWeekly = app.staticTexts["週間テスト習慣"]
        XCTAssertTrue(habitInWeekly.waitForExistence(timeout: 5),
                      "追加した習慣 '週間テスト習慣' が週間カレンダーに表示されること")
    }
}
