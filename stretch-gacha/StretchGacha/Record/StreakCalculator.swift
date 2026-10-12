import Foundation

/// 連続日数（猶予 1 日）。抜けが連続 2 日になった時点でリセットする。
/// 猶予ありにするのは、L1 の成功指標が「週 4 日以上」であり、厳密日連続だと
/// 成功状態でも頻繁に 0 へ戻って継続の手応えと噛み合わないため（ユーザー決定）。
/// Set<Int> と Int のみに依存し、Calendar・Date・SwiftUI・SwiftData を参照しない。
enum StreakCalculator {

    /// practiceDays: 実施が 1 件以上あった日の通し日番号の集合
    /// today: 判定時点（端末ローカル暦の今日）の通し日番号
    static func streak(practiceDays: Set<Int>, today: Int) -> Int {
        // 1. today 以前の実施日のうち最大のもの。未来日の記録は無視する
        guard let last = practiceDays.filter({ $0 <= today }).max() else { return 0 }
        // 2. last と today の間の抜けが 2 日以上連続ならリセット。
        //    当日（today）はまだ終わっていないため抜けとして数えない
        if today - last - 1 >= 2 { return 0 }
        // 3. last から遡る。抜け 1 日までは許容し、数えるのは「実施した日」の数だけ
        var count = 1
        var cursor = last
        while true {
            if practiceDays.contains(cursor - 1) {
                cursor -= 1
                count += 1
            } else if practiceDays.contains(cursor - 2) {
                cursor -= 2
                count += 1
            } else {
                break
            }
        }
        return count
    }
}
