import Foundation

public enum EntrySwitcher {
    public static func switchActivity(
        running: TimeEntry?, to activityID: ActivityID,
        plannedMinutes: Int?, at instant: Date, newID: EntryID
    ) -> SwitchResult {
        var closed: TimeEntry?
        if var running {
            // 呼び出し側は進行中の記録を渡す。
            precondition(running.endedAt == nil, "The entry must be ongoing.")
            // 端末時計が巻き戻った場合は開始時刻に丸め、長さ 0 の記録を破棄する。
            let closeAt = max(instant, running.startedAt)
            if closeAt > running.startedAt {
                running.endedAt = closeAt
                closed = running
            }
        }
        // ASSUMPTION: 新しい記録のメモは空文字から開始する。
        let started = TimeEntry(id: newID, activityID: activityID, startedAt: instant,
                                endedAt: nil, plannedMinutes: plannedMinutes, note: "")
        return SwitchResult(previousRunning: running, closed: closed, started: started)
    }

    /// started を捨て、切り替える前の状態に戻す。
    public static func undo(_ result: SwitchResult) -> TimeEntry? {
        result.previousRunning
    }
}
