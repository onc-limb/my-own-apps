public struct ActivitySummary: Sendable, Equatable {
    public let activityID: ActivityID
    public let ownMinutes: Int
    public let totalMinutes: Int
    public let budgetMinutes: Int?
    public let direction: BudgetDirection?

    public init(
        activityID: ActivityID, ownMinutes: Int, totalMinutes: Int,
        budgetMinutes: Int?, direction: BudgetDirection?
    ) {
        self.activityID = activityID
        self.ownMinutes = ownMinutes
        self.totalMinutes = totalMinutes
        self.budgetMinutes = budgetMinutes
        self.direction = direction
    }
}

public extension ActivitySummary {
    /// 上限は超過、目標は不足。正の値だけが問題を表す。
    var deviationMinutes: Int? {
        guard let budgetMinutes, let direction else { return nil }
        switch direction {
        case .cap: return max(0, totalMinutes - budgetMinutes)
        case .goal: return max(0, budgetMinutes - totalMinutes)
        }
    }
}
