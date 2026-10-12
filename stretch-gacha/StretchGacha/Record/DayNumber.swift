import Foundation

/// 日付キー → 1970-01-01 を 0 とする通し日番号。以後の連続日数判定を整数演算だけにする。
/// Calendar / DateComponents / DateFormatter をこのファイルでは使わない（純粋な整数演算のみ）。
enum DayNumber {

    private static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    /// "2026-08-18" -> 通し日番号。形式不正・値域外なら nil
    static func from(dayKey: String) -> Int? {
        let parts = dayKey.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        return daysFromCivil(year: year, month: month, day: day)
    }

    /// 通し日番号 -> 曜日記号（1970-01-01 が木曜であることに由来する +4 の補正）
    static func weekdaySymbol(_ n: Int) -> String {
        weekdaySymbols[((n % 7) + 7 + 4) % 7]
    }

    /// 履歴のセクション見出し（今日 / 昨日 / 8月18日(火)）
    static func sectionTitle(_ n: Int, today: Int) -> String {
        if n == today { return "今日" }
        if n == today - 1 { return "昨日" }
        let (_, month, day) = civilFromDays(n)
        return "\(month)月\(day)日(\(weekdaySymbol(n)))"
    }

    // civil <-> days の標準的な変換（うるう年・400 年周期を含む整数演算）

    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    static func civilFromDays(_ z: Int) -> (year: Int, month: Int, day: Int) {
        let z2 = z + 719468
        let era = (z2 >= 0 ? z2 : z2 - 146096) / 146097
        let doe = z2 - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (month <= 2 ? y + 1 : y, month, day)
    }
}
