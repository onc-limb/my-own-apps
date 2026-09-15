import Foundation

public enum HomeComposer {
    public static func compose(
        tree: ActivityTree, summaries: [ActivityID: ActivitySummary],
        lastUsedAt: [ActivityID: Date], recentLimit: Int, isCommitted: Bool
    ) -> HomeSections {
        var ordered: [Activity] = []
        var pending = Array(tree.topLevel().reversed())
        while let activity = pending.popLast() {
            ordered.append(activity)
            pending.append(contentsOf: tree.children(of: activity.id).reversed())
        }
        let active = ordered.filter { !$0.isArchived }.map(\.id)
        let ranks = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset) })
        var unmetGoals: [ActivityID] = []
        if isCommitted {
            unmetGoals = active.filter {
                summaries[$0]?.direction == .goal && (summaries[$0]?.deviationMinutes ?? 0) > 0
            }.sorted {
                let left = summaries[$0]?.deviationMinutes ?? 0
                let right = summaries[$1]?.deviationMinutes ?? 0
                return left == right ? ranks[$0]! < ranks[$1]! : left > right
            }
        }
        let recent = active.filter { lastUsedAt[$0] != nil }.sorted {
            // ASSUMPTION: 最終使用日時が同じ場合は階層順とする。
            let left = lastUsedAt[$0]!
            let right = lastUsedAt[$1]!
            return left == right ? ranks[$0]! < ranks[$1]! : left > right
        }
        // Propagate inclusion from descendants to ancestors before preserving preorder.
        var weeklyIDs: Set<ActivityID> = []
        for activity in ordered.reversed() {
            if !activity.isArchived || (summaries[activity.id]?.totalMinutes ?? 0) >= 1 {
                weeklyIDs.insert(activity.id)
            }
            if weeklyIDs.contains(activity.id), let parent = activity.parentID {
                weeklyIDs.insert(parent)
            }
        }
        return HomeSections(
            unmetGoals: unmetGoals,
            // ASSUMPTION: 負の件数制限は 0 件として扱う。
            recentlyUsed: Array(recent.prefix(max(0, recentLimit))),
            weeklyProgress: ordered.filter { weeklyIDs.contains($0.id) }.map(\.id)
        )
    }
}
