/// 変更のあった週だけ保存する、希望と確定の独立した予算。
public struct BudgetEntry: Sendable, Equatable {
    public let activityID: ActivityID
    public let effectiveFrom: LogicalWeek
    public var direction: BudgetDirection
    public var wishMinutes: Int
    public var committedMinutes: Int?

    public init(
        activityID: ActivityID, effectiveFrom: LogicalWeek, direction: BudgetDirection,
        wishMinutes: Int, committedMinutes: Int?
    ) {
        self.activityID = activityID
        self.effectiveFrom = effectiveFrom
        self.direction = direction
        self.wishMinutes = wishMinutes
        self.committedMinutes = committedMinutes
    }
}
