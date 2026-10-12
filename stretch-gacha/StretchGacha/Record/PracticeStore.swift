import Foundation
import Observation
import SwiftData

/// 実施記録の唯一の書き手。SwiftData に触るのはこの型だけで、他のファイルは値型しか扱わない。
/// 起動時に fetch 1 本で索引を作り、以後の記録・抽選・履歴表示は fetch 0 本。
@Observable
@MainActor
final class PracticeStore {

    private(set) var streakDays: Int = 0
    private(set) var sections: [HistorySection] = []

    private let context: ModelContext
    private let catalog: StretchCatalog
    private let now: () -> Date
    private let calendar: Calendar
    private var index: PracticeIndex = .empty
    private var today: Int = 0

    init(context: ModelContext,
         catalog: StretchCatalog = .shared,
         now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current) {
        self.context = context
        self.catalog = catalog
        self.now = now
        self.calendar = calendar
        loadIndex()
    }

    /// SwiftData fetch 1 本。起動時のみ。
    func loadIndex() {
        var descriptor = FetchDescriptor<PracticeRecord>()
        descriptor.sortBy = [SortDescriptor(\.completedAt, order: .reverse)]
        let records = (try? context.fetch(descriptor)) ?? []
        let rows = records.map { ($0.itemID, $0.completedAt, $0.dayKey) }
        index = PracticeIndex.build(from: rows,
                                    knownItemIDs: Set(catalog.allItems.map(\.id)))
        recomputeDerived()
    }

    /// タイマー完了時に 1 回だけ呼ばれる。insert 1 + save 1。fetch は行わない。
    func record(itemID: String, completedAt: Date) {
        let dayKey = DayKey.make(from: completedAt, calendar: calendar)
        let record = PracticeRecord(itemID: itemID, completedAt: completedAt, dayKey: dayKey)
        context.insert(record)
        do {
            try context.save()
        } catch {
            // 保存に失敗した実施は静かに記録されないだけにする（リトライ・ダイアログ・ログなし）
            context.delete(record)
            return
        }
        // 索引をメモリ上で更新する（fetch 0 本）
        guard catalog.item(id: itemID) != nil,
              let dayNumber = DayNumber.from(dayKey: dayKey) else { return }
        var entries = index.entries
        entries.insert(PracticeEntry(itemID: itemID, completedAt: completedAt, dayNumber: dayNumber),
                       at: 0)
        entries.sort { $0.completedAt > $1.completedAt }
        index = PracticeIndex(entries: entries,
                              ownedItemIDs: index.ownedItemIDs.union([itemID]),
                              practiceDays: index.practiceDays.union([dayNumber]))
        recomputeDerived()
    }

    /// 図鑑登録済み（1 回以上実施完了した）種目 ID。メモリ索引から返す（fetch 0 本）。
    func ownedItemIDs() -> Set<String> { index.ownedItemIDs }

    func isOwned(_ itemID: String) -> Bool { index.ownedItemIDs.contains(itemID) }

    /// アプリを開いたまま日をまたいだときの再計算（fetch 0 本）。
    func refreshForCurrentDay() {
        let newToday = DayNumber.from(dayKey: DayKey.make(from: now(), calendar: calendar)) ?? today
        guard newToday != today else { return }
        today = newToday
        recomputeDerived(todayAlreadySet: true)
    }

    private func recomputeDerived(todayAlreadySet: Bool = false) {
        if !todayAlreadySet {
            today = DayNumber.from(dayKey: DayKey.make(from: now(), calendar: calendar)) ?? 0
        }
        streakDays = StreakCalculator.streak(practiceDays: index.practiceDays, today: today)
        sections = HistorySectionBuilder.build(entries: index.entries, today: today)
    }
}
