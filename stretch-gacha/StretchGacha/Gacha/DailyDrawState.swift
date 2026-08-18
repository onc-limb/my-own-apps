import Foundation
import SwiftData

/// 当日ドロー状態。同日重複回避をアプリ再起動をまたいで機能させるための 1 行だけの状態で、
/// 実施記録（practice-record）とは別物。履歴として貯めず、日付が変わったら上書きリセットする。
@Model
final class DailyDrawState {
    @Attribute(.unique) var dayKey: String   // 例 "2026-08-18"（端末ローカル暦）
    var drawnItemIDs: [String]               // 当日出た種目 ID（重複なし・出現順）
    var updatedAt: Date

    init(dayKey: String, drawnItemIDs: [String] = [], updatedAt: Date) {
        self.dayKey = dayKey
        self.drawnItemIDs = drawnItemIDs
        self.updatedAt = updatedAt
    }
}
