/// 変更のあった週だけ保存する総枠。nil は制約なし。
public struct CapacityEntry: Sendable, Equatable {
    public let effectiveFrom: LogicalWeek
    public var totalMinutes: Int?

    public init(effectiveFrom: LogicalWeek, totalMinutes: Int?) {
        self.effectiveFrom = effectiveFrom
        self.totalMinutes = totalMinutes
    }
}
