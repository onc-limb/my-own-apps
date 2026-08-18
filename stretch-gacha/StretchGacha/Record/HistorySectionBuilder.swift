import Foundation

struct HistorySection: Equatable, Identifiable {
    let id: Int                 // dayNumber
    let title: String           // 「今日」「昨日」「8月18日(火)」
    let entries: [PracticeEntry] // completedAt 降順
}

/// 履歴のセクション整形（純粋関数）。日付降順・セクション内は時刻降順。
enum HistorySectionBuilder {
    static func build(entries: [PracticeEntry], today: Int) -> [HistorySection] {
        let grouped = Dictionary(grouping: entries, by: \.dayNumber)
        return grouped.keys.sorted(by: >).map { day in
            let rows = grouped[day]!.sorted { $0.completedAt > $1.completedAt }
            return HistorySection(id: day,
                                  title: DayNumber.sectionTitle(day, today: today),
                                  entries: rows)
        }
    }
}
