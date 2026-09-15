public struct SwitchResult: Sendable, Equatable {
    /// 切り替える前に進行中だった記録を変更せず保持する。なければ nil。
    public let previousRunning: TimeEntry?
    /// 切り替え時刻で終了した記録。長さ 0 で破棄した場合は nil。
    public let closed: TimeEntry?
    public let started: TimeEntry

    public init(previousRunning: TimeEntry?, closed: TimeEntry?, started: TimeEntry) {
        self.previousRunning = previousRunning
        self.closed = closed
        self.started = started
    }
}
