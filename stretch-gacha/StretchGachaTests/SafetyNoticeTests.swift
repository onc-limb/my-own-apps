import XCTest
@testable import StretchGacha

final class SafetyNoticeTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "SafetyNoticeTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - 判定（フェイルセーフの向きは常に「表示する」）

    func testCurrentVersionIsOne() {
        XCTAssertEqual(SafetyNoticeGate.currentVersion, 1)
    }

    func testJudgementTable() {
        XCTAssertTrue(SafetyNoticeGate.shouldPresent(acceptedVersion: 0, currentVersion: 1))
        XCTAssertFalse(SafetyNoticeGate.shouldPresent(acceptedVersion: 1, currentVersion: 1))
        XCTAssertFalse(SafetyNoticeGate.shouldPresent(acceptedVersion: 2, currentVersion: 1))
        XCTAssertTrue(SafetyNoticeGate.shouldPresent(acceptedVersion: -1, currentVersion: 1))
    }

    // MARK: - ストア

    func testUnsavedKeyReadsAsZeroAndPresents() {
        let store = SafetyNoticeStore(defaults: defaults)
        XCTAssertEqual(store.acceptedVersion, 0)
        XCTAssertTrue(SafetyNoticeGate.shouldPresent(acceptedVersion: store.acceptedVersion))
    }

    func testAcceptStoresCurrentVersion() {
        let store = SafetyNoticeStore(defaults: defaults)
        store.accept()
        XCTAssertEqual(store.acceptedVersion, SafetyNoticeGate.currentVersion)
        XCTAssertFalse(SafetyNoticeGate.shouldPresent(acceptedVersion: store.acceptedVersion))
    }

    func testNonIntValueReadsAsZeroAndPresents() {
        defaults.set("broken", forKey: SafetyNoticeStore.acceptedVersionKey)
        let store = SafetyNoticeStore(defaults: defaults)
        XCTAssertEqual(store.acceptedVersion, 0)
        XCTAssertTrue(SafetyNoticeGate.shouldPresent(acceptedVersion: store.acceptedVersion))
    }

    func testOnlyOneKeyIsUsed() {
        let store = SafetyNoticeStore(defaults: defaults)
        store.accept()
        let stored = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertEqual(Array(stored.keys), [SafetyNoticeStore.acceptedVersionKey])
    }

    // MARK: - 文言規約

    func testBodyHasOneToFiveItemsEachWithin30Characters() {
        XCTAssertTrue((1...5).contains(SafetyNoticeText.body.count))
        for line in SafetyNoticeText.body {
            XCTAssertLessThanOrEqual(line.count, 30, line)
            XCTAssertFalse(line.isEmpty)
        }
    }

    func testForbiddenWordsAreAbsentFromAllStrings() {
        let forbidden = ["治る", "治療", "効能", "医学", "監修", "診断", "処方"]
        let texts = [SafetyNoticeText.headline, SafetyNoticeText.acceptButton]
            + SafetyNoticeText.body
        for word in forbidden {
            XCTAssertFalse(texts.contains { $0.contains(word) }, word)
        }
    }

    func testBodyCoversStopOnPainAndNoOverexertion() {
        let joined = SafetyNoticeText.body.joined()
        XCTAssertTrue(joined.contains("痛み"))
        XCTAssertTrue(joined.contains("中止"))
        XCTAssertTrue(joined.contains("無理をしない"))
    }

    // MARK: - 性能

    func testJudgementPerformance100kWithin2Seconds() {
        let start = Date()
        for i in 0..<100_000 {
            _ = SafetyNoticeGate.shouldPresent(acceptedVersion: i % 3)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testStoreReadPerformance1000Within2Seconds() {
        let store = SafetyNoticeStore(defaults: defaults)
        let start = Date()
        for _ in 0..<1000 {
            _ = store.acceptedVersion
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }
}
