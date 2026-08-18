import Foundation

/// 履歴行の時刻表示（24 時間表記固定）。DateFormatter は使わない
/// （ロケール依存の出力揺れを避け、テストを厳密値でアサートするため）。
enum TimeLabel {
    static func text(from date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
