import XCTest
import SwiftData
@testable import StretchGacha

final class PracticeRecordTests: XCTestCase {

    // MARK: - DayNumber（既知値の厳密アサート）

    func testDayNumberKnownValues() throws {
        let d0818 = try XCTUnwrap(DayNumber.from(dayKey: "2026-08-18"))
        let d0819 = try XCTUnwrap(DayNumber.from(dayKey: "2026-08-19"))
        XCTAssertEqual(d0819 - d0818, 1)
        XCTAssertEqual(try XCTUnwrap(DayNumber.from(dayKey: "2025-12-31")) + 1,
                       try XCTUnwrap(DayNumber.from(dayKey: "2026-01-01")))
        XCTAssertEqual(try XCTUnwrap(DayNumber.from(dayKey: "2026-03-01"))
                       - (try XCTUnwrap(DayNumber.from(dayKey: "2026-02-28"))), 1)   // 平年
        XCTAssertEqual(try XCTUnwrap(DayNumber.from(dayKey: "2028-02-29"))
                       - (try XCTUnwrap(DayNumber.from(dayKey: "2028-02-28"))), 1)   // うるう年
        XCTAssertEqual(try XCTUnwrap(DayNumber.from(dayKey: "2028-03-01"))
                       - (try XCTUnwrap(DayNumber.from(dayKey: "2028-02-29"))), 1)
        XCTAssertEqual(DayNumber.from(dayKey: "1970-01-01"), 0)
    }

    func testDayNumberRejectsInvalidKeys() {
        for key in ["2026-13-01", "2026-08-1", "abc", "", "2026/08/18", "2026-00-10"] {
            XCTAssertNil(DayNumber.from(dayKey: key), key)
        }
    }

    func testWeekdaySymbols() throws {
        XCTAssertEqual(DayNumber.weekdaySymbol(try XCTUnwrap(DayNumber.from(dayKey: "2026-08-18"))), "火")
        XCTAssertEqual(DayNumber.weekdaySymbol(try XCTUnwrap(DayNumber.from(dayKey: "2026-08-19"))), "水")
        XCTAssertEqual(DayNumber.weekdaySymbol(0), "木")   // 1970-01-01
    }

    func testSectionTitles() throws {
        let today = try XCTUnwrap(DayNumber.from(dayKey: "2026-08-20"))
        XCTAssertEqual(DayNumber.sectionTitle(today, today: today), "今日")
        XCTAssertEqual(DayNumber.sectionTitle(today - 1, today: today), "昨日")
        let d0818 = try XCTUnwrap(DayNumber.from(dayKey: "2026-08-18"))
        XCTAssertEqual(DayNumber.sectionTitle(d0818, today: today), "8月18日(火)")
    }

    func testCivilRoundTrip() {
        for key in ["2026-08-18", "2000-02-29", "1999-12-31", "2028-02-29"] {
            let n = DayNumber.from(dayKey: key)!
            let (y, m, d) = DayNumber.civilFromDays(n)
            XCTAssertEqual(String(format: "%04d-%02d-%02d", y, m, d), key)
        }
    }

    func testDayKeyFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 2026-08-18 14:32 JST
        let date = Date(timeIntervalSince1970: 1_776_835_920)
        let key = DayKey.make(from: date, calendar: calendar)
        XCTAssertNotNil(key.wholeMatch(of: /^\d{4}-\d{2}-\d{2}$/))
        XCTAssertTrue(DayKey.isValid(key))
    }

    // MARK: - StreakCalculator（仕様の境界値 12 ケース）

    func testStreakBoundaryCases() {
        let t = 20_000
        func streak(_ days: [Int]) -> Int {
            StreakCalculator.streak(practiceDays: Set(days), today: t)
        }
        XCTAssertEqual(streak([]), 0)                            // 1. 記録なし
        XCTAssertEqual(streak([t]), 1)                           // 2. 今日だけ
        XCTAssertEqual(streak([t, t - 1]), 2)                    // 3. 連続 2 日
        XCTAssertEqual(streak([t - 1]), 1)                       // 4. 今日未実施でも切れない
        XCTAssertEqual(streak([t - 2]), 1)                       // 5. 抜けは昨日 1 日のみ
        XCTAssertEqual(streak([t - 3]), 0)                       // 6. 2 日連続抜けでリセット
        XCTAssertEqual(streak([t, t - 2, t - 3]), 3)             // 7. 抜け 1 日を越えてつながる
        XCTAssertEqual(streak([t, t - 1, t - 3, t - 4]), 4)      // 8. 途中 1 日の抜け
        XCTAssertEqual(streak([t, t - 1, t - 4]), 2)             // 9. 2 日連続抜けで打ち切り
        XCTAssertEqual(streak([t - 3, t - 1, t]), 3)             // 10. 月水木（火抜け）= q1 の例
        XCTAssertEqual(streak([t, t, t]), 1)                     // 11. 同一日複数実施は 1 日
        XCTAssertEqual(streak([t, t + 1]), 1)                    // 12. 未来日は無視
    }

    func testStreakPerformance() {
        let days = Set((0..<365).compactMap { $0 % 2 == 0 ? 20_000 - $0 : nil })
        let start = Date()
        for _ in 0..<10_000 {
            _ = StreakCalculator.streak(practiceDays: days, today: 20_000)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    // MARK: - PracticeIndex（防御的処理）

    func testIndexExcludesInvalidRows() {
        let known: Set<String> = ["neck-01", "neck-02"]
        let base = Date(timeIntervalSince1970: 1_755_500_000)
        let rows: [(itemID: String, completedAt: Date, dayKey: String)] = [
            ("neck-01", base, "2026-08-18"),
            ("neck-02", base.addingTimeInterval(60), "2026-13-45"),   // 不正 dayKey → 除外
            ("ghost-99", base.addingTimeInterval(120), "2026-08-18"), // 未知 itemID → 除外
            ("neck-01", base.addingTimeInterval(180), "2026-08-18"),  // 重複 → 集合では畳まれる
        ]
        let index = PracticeIndex.build(from: rows, knownItemIDs: known)
        XCTAssertEqual(index.entries.count, 2)
        XCTAssertEqual(index.ownedItemIDs, ["neck-01"])
        XCTAssertEqual(index.practiceDays.count, 1)
        // completedAt 降順
        XCTAssertTrue(index.entries[0].completedAt > index.entries[1].completedAt)
    }

    func testIndexBuildPerformance10kRows() {
        let known: Set<String> = Set(StretchCatalog.shared.allItems.map(\.id))
        let ids = Array(known)
        let base = Date(timeIntervalSince1970: 1_755_500_000)
        let rows = (0..<10_000).map { i in
            (itemID: ids[i % ids.count],
             completedAt: base.addingTimeInterval(Double(i) * 300),
             dayKey: DayKey.make(from: base.addingTimeInterval(Double(i) * 300)))
        }
        let start = Date()
        let index = PracticeIndex.build(from: rows, knownItemIDs: known)
        _ = StreakCalculator.streak(practiceDays: index.practiceDays, today: 20_000)
        _ = HistorySectionBuilder.build(entries: index.entries, today: 20_000)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    // MARK: - HistorySectionBuilder

    func testSectionsAreOrderedByDayDescAndTimeDesc() {
        let base = Date(timeIntervalSince1970: 1_755_500_000)
        let entries = [
            PracticeEntry(itemID: "a", completedAt: base, dayNumber: 100),
            PracticeEntry(itemID: "b", completedAt: base.addingTimeInterval(60), dayNumber: 100),
            PracticeEntry(itemID: "c", completedAt: base.addingTimeInterval(-86_400), dayNumber: 99),
        ]
        let sections = HistorySectionBuilder.build(entries: entries, today: 100)
        XCTAssertEqual(sections.map(\.id), [100, 99])
        XCTAssertEqual(sections[0].title, "今日")
        XCTAssertEqual(sections[0].entries.map(\.itemID), ["b", "a"])
        XCTAssertEqual(sections[1].title, "昨日")
    }

    func testTimeLabelIs24HourFixed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 18
        components.hour = 14; components.minute = 32
        let date = calendar.date(from: components)!
        XCTAssertEqual(TimeLabel.text(from: date, calendar: calendar), "14:32")
    }

    // MARK: - PracticeStore（in-memory SwiftData）

    @MainActor
    private func makeStore(now: @escaping () -> Date) throws -> (PracticeStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyDrawState.self, PracticeRecord.self,
                                           configurations: config)
        let context = container.mainContext
        return (PracticeStore(context: context, now: now), context)
    }

    @MainActor
    func testRecordAddsOneRowAndUpdatesIndexWithoutRefetch() throws {
        let base = Date(timeIntervalSince1970: 1_755_500_000)
        let (store, context) = try makeStore(now: { base })
        let itemID = StretchCatalog.shared.allItems[0].id
        store.record(itemID: itemID, completedAt: base)
        let rows = try context.fetch(FetchDescriptor<PracticeRecord>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].itemID, itemID)
        XCTAssertEqual(rows[0].dayKey, DayKey.make(from: base))
        XCTAssertEqual(store.ownedItemIDs(), [itemID])
        XCTAssertTrue(store.isOwned(itemID))
        XCTAssertEqual(store.streakDays, 1)
        XCTAssertEqual(store.sections.count, 1)
    }

    @MainActor
    func testDuplicateCompletionsCollapseInOwnedSet() throws {
        let base = Date(timeIntervalSince1970: 1_755_500_000)
        let (store, context) = try makeStore(now: { base })
        let itemID = StretchCatalog.shared.allItems[0].id
        for i in 0..<3 {
            store.record(itemID: itemID, completedAt: base.addingTimeInterval(Double(i) * 60))
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<PracticeRecord>()).count, 3)
        XCTAssertEqual(store.ownedItemIDs().count, 1)
    }

    @MainActor
    func testLoadIndexSurvivesCorruptRows() throws {
        let base = Date(timeIntervalSince1970: 1_755_500_000)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyDrawState.self, PracticeRecord.self,
                                           configurations: config)
        let context = container.mainContext
        context.insert(PracticeRecord(itemID: "ghost-99", completedAt: base, dayKey: "2026-08-18"))
        context.insert(PracticeRecord(itemID: StretchCatalog.shared.allItems[0].id,
                                      completedAt: base, dayKey: "broken"))
        context.insert(PracticeRecord(itemID: StretchCatalog.shared.allItems[0].id,
                                      completedAt: base, dayKey: "2026-08-18"))
        try context.save()
        let store = PracticeStore(context: context, now: { base })
        XCTAssertEqual(store.ownedItemIDs().count, 1)
        XCTAssertEqual(store.sections.flatMap(\.entries).count, 1)
        // 除外はメモリ上のみで、保存済みの行は削除されない
        XCTAssertEqual(try context.fetch(FetchDescriptor<PracticeRecord>()).count, 3)
    }

    @MainActor
    func testRefreshForCurrentDayRecomputesStreak() throws {
        var now = Date(timeIntervalSince1970: 1_755_500_000)
        let (store, _) = try makeStore(now: { now })
        let itemID = StretchCatalog.shared.allItems[0].id
        store.record(itemID: itemID, completedAt: now)
        XCTAssertEqual(store.streakDays, 1)
        now = now.addingTimeInterval(3 * 86_400)   // 3 日後 = 2 日以上の連続抜け
        store.refreshForCurrentDay()
        XCTAssertEqual(store.streakDays, 0)
    }

    @MainActor
    func testAdaptersBridgeToStore() throws {
        let base = Date(timeIntervalSince1970: 1_755_500_000)
        let (store, _) = try makeStore(now: { base })
        let itemID = StretchCatalog.shared.allItems[0].id
        let recorder = StorePracticeRecorder(store: store)
        recorder.recordCompletion(itemID: itemID, completedAt: base)
        let provider = StoreOwnershipProvider(store: store)
        XCTAssertEqual(provider.ownedItemIDs(), [itemID])
    }

    @MainActor
    func testRecordPerformance1000Within10Seconds() throws {
        let base = Date(timeIntervalSince1970: 1_755_500_000)
        let (store, _) = try makeStore(now: { base })
        let ids = StretchCatalog.shared.allItems.map(\.id)
        let start = Date()
        for i in 0..<1000 {
            store.record(itemID: ids[i % ids.count],
                         completedAt: base.addingTimeInterval(Double(i)))
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 10.0)
    }
}
