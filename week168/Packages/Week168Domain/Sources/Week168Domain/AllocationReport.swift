public struct AllocationReport: Sendable, Equatable {
    public let week: LogicalWeek
    public let totalWishMinutes: Int
    public let totalCommittedMinutes: Int
    public let capacityMinutes: Int?
    public let capacityOverflowMinutes: Int
    public let wishOverflowMinutes: Int
    public let nodes: [AllocationNode]

    public var canCommit: Bool {
        capacityOverflowMinutes == 0 && nodes.allSatisfy { $0.overflowMinutes == 0 }
    }

    public var offendingActivities: [ActivityID] {
        nodes.filter { $0.overflowMinutes > 0 }.map(\.activityID)
    }
}
