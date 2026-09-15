public enum PersistenceError: Error {
    case saveFailed(underlying: any Error)
    case invalidStoredValue(String)
    case staleSwitch
}
