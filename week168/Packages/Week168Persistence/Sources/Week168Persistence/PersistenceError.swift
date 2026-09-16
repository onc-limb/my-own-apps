import Week168Domain

public enum PersistenceError: Error {
    case saveFailed(underlying: any Error)
    case invalidStoredValue(String)
    case budgetNotSet(ActivityID)
    case staleSwitch
}
