public enum EntryValidationError: Error, Equatable {
    case endBeforeStart
    case zeroLength
    case overlaps(with: [EntryID])
    case anotherEntryRunning(EntryID)
    case inFuture
}
