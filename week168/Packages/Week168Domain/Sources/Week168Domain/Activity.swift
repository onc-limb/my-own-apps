public struct Activity: Sendable, Equatable, Identifiable {
    public let id: ActivityID
    public var name: String
    public var parentID: ActivityID?
    public var sortOrder: Int
    public var budgetMode: BudgetMode
    /// nil は既定なし（予定なしで開始する）。
    public var defaultPlannedMinutes: Int?
    public var colorHex: String
    public var isArchived: Bool

    public init(
        id: ActivityID, name: String, parentID: ActivityID?, sortOrder: Int,
        budgetMode: BudgetMode, defaultPlannedMinutes: Int?, colorHex: String,
        isArchived: Bool
    ) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.sortOrder = sortOrder
        self.budgetMode = budgetMode
        self.defaultPlannedMinutes = defaultPlannedMinutes
        self.colorHex = colorHex
        self.isArchived = isArchived
    }
}
