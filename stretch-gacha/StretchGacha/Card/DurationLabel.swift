import Foundation

/// 秒数 → 表示文字列。DateComponentsFormatter は使わない
/// （ロケール依存の出力揺れを避け、テストを厳密値でアサートするため）。
enum DurationLabel {
    static func text(seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)秒" }
        let minutes = seconds / 60
        let rest = seconds % 60
        return rest == 0 ? "\(minutes)分" : "\(minutes)分\(rest)秒"
    }
}
