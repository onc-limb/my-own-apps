import Foundation

/// 起動時に 1 度だけ構築するメモリ索引。以後の入手済み判定・履歴表示・連続日数は
/// すべてここから返す（ガチャ 1 回あたり fetch 0 本を維持する）。
struct PracticeIndex: Equatable {
    let entries: [PracticeEntry]        // completedAt 降順
    let ownedItemIDs: Set<String>
    let practiceDays: Set<Int>

    static let empty = PracticeIndex(entries: [], ownedItemIDs: [], practiceDays: [])

    /// 純粋関数。永続化データを「信頼しない入力」として扱い、
    /// 不正な dayKey・カタログに無い itemID の行は索引から除外する（行の削除はしない）。
    static func build(from rows: [(itemID: String, completedAt: Date, dayKey: String)],
                      knownItemIDs: Set<String>) -> PracticeIndex {
        var entries: [PracticeEntry] = []
        var owned = Set<String>()
        var days = Set<Int>()
        for row in rows {
            guard knownItemIDs.contains(row.itemID),
                  let dayNumber = DayNumber.from(dayKey: row.dayKey) else { continue }
            entries.append(PracticeEntry(itemID: row.itemID,
                                         completedAt: row.completedAt,
                                         dayNumber: dayNumber))
            owned.insert(row.itemID)
            days.insert(dayNumber)
        }
        entries.sort { $0.completedAt > $1.completedAt }
        return PracticeIndex(entries: entries, ownedItemIDs: owned, practiceDays: days)
    }
}
