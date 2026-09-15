extension ActivityTree {
    public enum BuildError: Error, Equatable {
        case cycleDetected(involving: [ActivityID])
        case missingParent(ActivityID, parent: ActivityID)
        case duplicateID(ActivityID)
        // ASSUMPTION: 違反した活動と最も近い対象外の祖先を返す。
        case budgetUnderExcluded(ActivityID, ancestor: ActivityID)
    }
}
