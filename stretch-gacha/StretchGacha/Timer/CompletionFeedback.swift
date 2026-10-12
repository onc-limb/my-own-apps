import UIKit

/// 完了フィードバックのポート。プロトコルにしているのはテストから発火回数を数えるため。
protocol CompletionFeedback {
    func notifySuccess()
}

/// 完了時に成功ハプティクスを 1 回鳴らす。音は鳴らさない
/// （音源アセットを持たない・フィードバックはハプティクスのみというユーザー決定を維持）。
struct HapticCompletionFeedback: CompletionFeedback {
    func notifySuccess() {
        Task { @MainActor in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
