import Foundation

public enum Aggregator {
    public static func summarize(
        entries: [TimeEntry], tree: ActivityTree,
        budgets: ResolvedBudgets, interval: DateInterval, now: Date
    ) -> [ActivityID: ActivitySummary] {
        var ownSeconds: [ActivityID: TimeInterval] = [:]
        for entry in entries {
            // ASSUMPTION: ツリーにない活動と非正の記録期間は集計しない。
            let end = entry.endedAt ?? now
            guard tree.node(entry.activityID) != nil, entry.startedAt < end else { continue }
            ownSeconds[entry.activityID, default: 0] += TimeAxis.overlappingSeconds(
                of: DateInterval(start: entry.startedAt, end: end), within: interval
            )
        }

        var ordered: [Activity] = []
        var pending = Array(tree.topLevel().reversed())
        while let activity = pending.popLast() {
            ordered.append(activity)
            pending.append(contentsOf: tree.children(of: activity.id).reversed())
        }
        // 子から親へ秒のまま加算する。対象外も実績には含める。
        var totalSeconds = ownSeconds
        for activity in ordered.reversed() {
            if let parent = activity.parentID {
                totalSeconds[parent, default: 0] += totalSeconds[activity.id, default: 0]
            }
        }
        var result: [ActivityID: ActivitySummary] = [:]
        for activity in ordered {
            let budget = activity.budgetMode == .managed ? budgets.budget(for: activity.id) : nil
            result[activity.id] = ActivitySummary(
                activityID: activity.id,
                ownMinutes: Int(ownSeconds[activity.id, default: 0] / 60),
                totalMinutes: Int(totalSeconds[activity.id, default: 0] / 60),
                budgetMinutes: budget?.committedMinutes,
                direction: budget?.direction
            )
        }
        return result
    }

    public static func remainingMinutes(
        for activityID: ActivityID, summaries: [ActivityID: ActivitySummary]
    ) -> Int? {
        guard let summary = summaries[activityID], let budget = summary.budgetMinutes else { return nil }
        return budget - summary.totalMinutes
    }
}
