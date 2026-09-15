extension ActivityTree {
    public enum BuildError: Error, Equatable {
        case cycleDetected(involving: [ActivityID])
        case missingParent(ActivityID, parent: ActivityID)
        case duplicateID(ActivityID)
    }
}
