public struct HomeSections: Sendable, Equatable {
    public let unmetGoals: [ActivityID]
    public let recentlyUsed: [ActivityID]
    public let weeklyProgress: [ActivityID]

    public init(unmetGoals: [ActivityID], recentlyUsed: [ActivityID], weeklyProgress: [ActivityID]) {
        self.unmetGoals = unmetGoals
        self.recentlyUsed = recentlyUsed
        self.weeklyProgress = weeklyProgress
    }
}
