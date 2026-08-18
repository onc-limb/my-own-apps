import Foundation

/// 実施完了の記録ポート。実装は practice-record 側（StorePracticeRecorder）。
protocol PracticeRecording {
    /// 実施完了を記録する。中断時には呼ばれない
    func recordCompletion(itemID: String, completedAt: Date)
}

/// プレビュー・テスト用の既定実装。何もしない。
struct NoopPracticeRecorder: PracticeRecording {
    func recordCompletion(itemID: String, completedAt: Date) {}
}
