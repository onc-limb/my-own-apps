import Foundation

/// 単調増加クロックの抽象。壁時計（Date）を使わないのは、端末の時刻変更・
/// タイムゾーン変更でカウントが飛ばないようにするため。
protocol TimerClock {
    /// 任意の原点からの単調増加秒数
    func nowSeconds() -> Double
}

struct MonotonicTimerClock: TimerClock {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    init() {
        origin = clock.now
    }

    func nowSeconds() -> Double {
        let elapsed = origin.duration(to: clock.now)
        let (seconds, attoseconds) = elapsed.components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
