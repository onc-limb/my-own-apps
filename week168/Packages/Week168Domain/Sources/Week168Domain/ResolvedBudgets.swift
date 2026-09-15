public struct ResolvedBudgets: Sendable {
    public let week: LogicalWeek
    public let capacityMinutes: Int?
    private let entriesByActivity: [ActivityID: BudgetEntry]

    init(week: LogicalWeek, capacityMinutes: Int?, entriesByActivity: [ActivityID: BudgetEntry]) {
        self.week = week
        self.capacityMinutes = capacityMinutes
        self.entriesByActivity = entriesByActivity
    }

    public func budget(for id: ActivityID) -> BudgetEntry? {
        entriesByActivity[id]
    }
}
