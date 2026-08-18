import Foundation

/// 端末ローカル暦の日付キー "yyyy-MM-dd"。DailyDrawState.dayKey と同一表現。
/// DateFormatter は使わない（ロケール・カレンダー設定による出力揺れを避けるため）。
enum DayKey {
    static func make(from date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func isValid(_ key: String) -> Bool {
        DayNumber.from(dayKey: key) != nil
    }
}
