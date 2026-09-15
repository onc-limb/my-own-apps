public enum BudgetResolver {
    public static func resolve(
        week: LogicalWeek, entries: [BudgetEntry], capacities: [CapacityEntry]
    ) -> ResolvedBudgets {
        var latest: [ActivityID: BudgetEntry] = [:]
        for entry in entries where entry.effectiveFrom <= week {
            // ASSUMPTION: 同じ活動・適用週の重複は入力の最後を採用する。総枠の同週重複も同様。
            // 重複は JSON インポート時の検証で弾かれる前提。
            if let previous = latest[entry.activityID], previous.effectiveFrom > entry.effectiveFrom {
                continue
            }
            latest[entry.activityID] = entry
        }
        var capacity: CapacityEntry?
        for entry in capacities where entry.effectiveFrom <= week {
            if let previous = capacity, previous.effectiveFrom > entry.effectiveFrom { continue }
            capacity = entry
        }
        return ResolvedBudgets(week: week, capacityMinutes: capacity?.totalMinutes, entriesByActivity: latest)
    }
}
