import Foundation
import Week168Domain

public enum AlarmTiming {
    public static func plannedTimeFireDate(entry: TimeEntry) -> Date? {
        entry.plannedMinutes.map { entry.startedAt.addingTimeInterval(Double($0) * 60) }
    }

    public static func budgetExhaustionFireDate(
        running: TimeEntry, tree: ActivityTree,
        summaries: [ActivityID: ActivitySummary], isCommitted: Bool, now: Date
    ) -> (activityID: ActivityID, fireAt: Date)? {
        guard isCommitted, running.endedAt == nil,
              let activity = tree.node(running.activityID), activity.budgetMode != .excluded else { return nil }
        let path = [running.activityID] + tree.ancestors(of: running.activityID)
        guard !path.contains(where: { tree.node($0)?.budgetMode == .excluded }) else { return nil }
        // ASSUMPTION: Summaries already include elapsed running time through now. At exactly
        // zero remaining, notify now; negative remaining means the threshold has passed.
        return path.compactMap { id in
            guard tree.node(id)?.budgetMode == .managed,
                  let remaining = Aggregator.remainingMinutes(for: id, summaries: summaries),
                  remaining >= 0 else { return nil as (activityID: ActivityID, fireAt: Date)? }
            return (activityID: id, fireAt: now.addingTimeInterval(Double(remaining) * 60))
        }.min { $0.fireAt < $1.fireAt }
    }
}
