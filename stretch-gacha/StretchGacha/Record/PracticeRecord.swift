import Foundation
import SwiftData

/// 実施記録。1 実施完了 = 1 行の追記専用（更新・削除しない）。
/// dayKey は記録時に確定して保存し、以後タイムゾーンが変わっても再計算しない。
@Model
final class PracticeRecord {
    @Attribute(.unique) var id: UUID
    var itemID: String       // StretchItem.id（カタログの安定キー）
    var completedAt: Date    // 完了時刻（壁時計。表示と並べ替えに使う）
    var dayKey: String       // 端末ローカル暦の日付 "2026-08-18"

    init(id: UUID = UUID(), itemID: String, completedAt: Date, dayKey: String) {
        self.id = id
        self.itemID = itemID
        self.completedAt = completedAt
        self.dayKey = dayKey
    }
}
