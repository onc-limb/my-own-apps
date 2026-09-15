import Week168Domain

public enum Week168ServiceError: Error, Sendable {
    case allocationRejected(AllocationReport)
    case activityNotFound(ActivityID)
    case budgetNotSet
    case invalidOrder
    case invalidMinutes
    case invalidMonth
    case staleSwitch
}
