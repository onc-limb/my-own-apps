public struct AllocationNode: Sendable, Equatable {
    public let activityID: ActivityID
    public let mode: BudgetMode
    /// その週に適用される予算の方向。予算レコードがなければ nil。
    public let direction: BudgetDirection?
    public let wishMinutes: Int?
    public let committedMinutes: Int?
    public let childrenCommittedMinutes: Int
    public let unallocatedMinutes: Int?
    public let overflowMinutes: Int
}
