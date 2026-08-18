import Foundation

enum TimerMetrics {
    /// ティック間隔（10Hz）。90 秒の種目で最大 900 ティック
    static let tickInterval: Double = 0.1
    /// durationSeconds のクランプ範囲（異常値でも無限カウント・即時完了にしない）
    static let minDuration = 1
    static let maxDuration = 600
    /// VoiceOver の残り時間読み上げの更新刻み（1 秒ごとの割り込みを避ける）
    static let accessibilityValueStep = 10

    static let countdownFontSize: CGFloat = 64
    static let progressBarHeight: CGFloat = 6
    static let footerHeight: CGFloat = 56
    static let screenPadding: CGFloat = 16
}
