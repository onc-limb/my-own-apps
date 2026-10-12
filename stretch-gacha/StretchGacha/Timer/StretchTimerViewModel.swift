import Foundation
import Observation
import UIKit

enum TimerPhase: Equatable {
    case running        // カウントダウン中
    case paused         // バックグラウンド等で一時停止中
    case finished       // 0 秒に到達（完了表示）
}

/// タイマーの状態機械。何も永続化しない（強制終了時は中断扱いで記録もされない）。
/// 一時停止では残り秒を確定保持し、復帰時に deadline を引き直す
/// （バックグラウンド滞在時間に関係なく残り秒が保存される。誤差 0）。
@Observable
@MainActor
final class StretchTimerViewModel {

    let item: StretchItem
    private(set) var phase: TimerPhase = .running
    private(set) var remaining: Double

    var displaySeconds: Int { TimerEngine.displaySeconds(remaining: remaining) }
    var progress: Double { TimerEngine.progress(remaining: remaining, duration: duration) }

    let duration: Int
    private var deadline: Double
    private let clock: TimerClock
    private let feedback: CompletionFeedback
    private let recorder: PracticeRecording
    private let now: () -> Date
    private let setIdleTimerDisabled: @MainActor (Bool) -> Void
    private var finishHandled = false

    init(item: StretchItem,
         clock: TimerClock = MonotonicTimerClock(),
         feedback: CompletionFeedback = HapticCompletionFeedback(),
         recorder: PracticeRecording = NoopPracticeRecorder(),
         now: @escaping () -> Date = Date.init,
         setIdleTimerDisabled: @escaping @MainActor (Bool) -> Void = {
             UIApplication.shared.isIdleTimerDisabled = $0
         }) {
        self.item = item
        self.clock = clock
        self.feedback = feedback
        self.recorder = recorder
        self.now = now
        self.setIdleTimerDisabled = setIdleTimerDisabled
        let duration = TimerEngine.duration(for: item)
        self.duration = duration
        self.remaining = Double(duration)
        self.deadline = clock.nowSeconds() + Double(duration)
        setIdleTimerDisabled(true)   // 実施中だけ自動ロックを抑止する
    }

    /// 0.1 秒ごとにビューから呼ばれる。残りは毎回クロックから再計算する
    /// （ティックの取りこぼし・遅延が累積しない）。
    func tick() {
        guard phase == .running else { return }
        remaining = TimerEngine.remaining(deadline: deadline, now: clock.nowSeconds())
        if TimerEngine.isFinished(remaining: remaining) {
            finish()
        }
    }

    /// scenePhase != .active。残り秒を確定して保持し、tick を止める。
    func pause() {
        guard phase == .running else { return }
        remaining = TimerEngine.remaining(deadline: deadline, now: clock.nowSeconds())
        phase = .paused
        setIdleTimerDisabled(false)
    }

    /// scenePhase == .active。deadline を引き直して再開する（running 中は無視）。
    func resume() {
        guard phase == .paused else { return }
        deadline = clock.nowSeconds() + remaining
        phase = .running
        setIdleTimerDisabled(true)
    }

    /// 「やめる」タップ。記録しない・ハプティクスなし。
    func abort() {
        guard phase != .finished else { return }
        setIdleTimerDisabled(false)
    }

    /// 自動ロック抑止を必ず解除する合流点（どの経路で画面を抜けても通る）。
    func onDisappear() {
        setIdleTimerDisabled(false)
    }

    /// finished 遷移時の副作用は 1 回だけ（再入ガード）。
    private func finish() {
        guard !finishHandled else { return }
        finishHandled = true
        phase = .finished
        setIdleTimerDisabled(false)
        feedback.notifySuccess()
        recorder.recordCompletion(itemID: item.id, completedAt: now())
    }
}
