import Foundation

/// 残り時間・進捗・完了判定の純粋計算。SwiftUI・SwiftData・システム時刻・乱数に依存しない。
/// 将来 segments（左右のセグメント分割）を導入する場合は、この型に手順ごとの区間を
/// 渡す形で拡張する（カタログのスキーマ拡張 → 本型の分割対応 → 手順テキストの再修正の順）。
enum TimerEngine {

    /// 実施秒数。カタログ規約（20...90）の外側でもクラッシュ・無限カウントを起こさない
    static func duration(for item: StretchItem) -> Int {
        min(max(item.durationSeconds, TimerMetrics.minDuration), TimerMetrics.maxDuration)
    }

    /// 残り秒数（実数）。0 以下は 0 に丸める
    static func remaining(deadline: Double, now: Double) -> Double {
        max(0, deadline - now)
    }

    /// 画面に出す整数秒。切り上げ（ceil）で求める。
    /// 残り 59.0 秒ちょうどは 59、59.0 を超えていれば 60 と表示する（例: 59.4 → 60）
    static func displaySeconds(remaining: Double) -> Int {
        Int(remaining.rounded(.up))
    }

    /// 進捗（0.0 = 開始直後、1.0 = 完了）
    static func progress(remaining: Double, duration: Int) -> Double {
        guard duration > 0 else { return 1 }
        return min(max(1 - remaining / Double(duration), 0), 1)
    }

    static func isFinished(remaining: Double) -> Bool { remaining <= 0 }
}
