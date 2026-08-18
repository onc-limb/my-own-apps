import Foundation
import SwiftData

/// SwiftData 読み書きの薄いラッパ。画面初期化で fetch 1 本、ガチャ 1 回あたり
/// fetch 0 本・save 1 回（演出中に I/O を走らせない）。テーブルは常に 0〜1 行。
@MainActor
final class DailyDrawStore {
    private let context: ModelContext
    private let now: () -> Date
    private var state: DailyDrawState?
    private var drawnTodayIDs: Set<String> = []

    init(context: ModelContext, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.now = now
    }

    /// 起動時に 1 回だけ呼ぶ。永続化データを「信頼しない入力」として扱い、
    /// カタログに存在しない ID は破棄する（破損しても重複回避が緩むだけにする）。
    func loadDrawnTodayIDs(validAgainst catalog: StretchCatalog) -> Set<String> {
        let today = Self.dayKey(for: now())
        let fetched = (try? context.fetch(FetchDescriptor<DailyDrawState>())) ?? []
        guard let row = fetched.first else {
            drawnTodayIDs = []
            return []
        }
        state = row
        if row.dayKey != today {
            // 行を追加せず既存行を上書きリセットする（常に 1 行以下を保つ）
            row.dayKey = today
            row.drawnItemIDs = []
            row.updatedAt = now()
            drawnTodayIDs = []
            return []
        }
        drawnTodayIDs = Set(row.drawnItemIDs.filter { catalog.item(id: $0) != nil })
        return drawnTodayIDs
    }

    var currentDrawnTodayIDs: Set<String> { drawnTodayIDs }

    /// メモリ上の状態だけ更新する（I/O なし。演出中に呼ばれる）。
    func recordInMemory(itemID: String) {
        guard !drawnTodayIDs.contains(itemID) else { return }
        drawnTodayIDs.insert(itemID)
        let today = Self.dayKey(for: now())
        if let state, state.dayKey == today {
            state.drawnItemIDs.append(itemID)
            state.updatedAt = now()
        } else if let state {
            state.dayKey = today
            state.drawnItemIDs = [itemID]
            state.updatedAt = now()
        } else {
            let row = DailyDrawState(dayKey: today, drawnItemIDs: [itemID], updatedAt: now())
            context.insert(row)
            state = row
        }
    }

    /// 演出終了後に 1 回だけ呼ぶ save。
    func flush() {
        try? context.save()
    }

    /// 端末ローカル暦の日付キー。DateFormatter は使わない（出力揺れ防止）。
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
