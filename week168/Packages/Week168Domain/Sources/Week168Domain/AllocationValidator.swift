public enum AllocationValidator {
    public static func report(
        tree: ActivityTree, budgets: ResolvedBudgets, week: LogicalWeek
    ) -> AllocationReport {
        // ASSUMPTION: 解決済み予算と要求週は一致することを呼び出し側の契約とする。
        precondition(budgets.week == week, "Resolved budgets must match the report week")
        var nodes: [AllocationNode] = []
        var totalWish = 0
        var totalCommitted = 0
        // ASSUMPTION: ノードの並びは既存の descendants と同じ深さ優先の先行順。
        var pending = Array(tree.topLevel().reversed())
        while let activity = pending.popLast() {
            let entry = managedBudget(for: activity, budgets: budgets)
            let childrenTotal = committedChildren(tree: tree, budgets: budgets, parent: activity.id)
            let managed: Bool
            if case .managed = activity.budgetMode { managed = true } else { managed = false }
            // ASSUMPTION: managed の未入力は差分計算でも 0。未配分は超過時に負値を保持する。
            let remainder = managed ? (entry?.committedMinutes ?? 0) - childrenTotal : nil
            nodes.append(AllocationNode(
                activityID: activity.id, mode: activity.budgetMode, direction: entry?.direction,
                wishMinutes: entry?.wishMinutes,
                committedMinutes: entry?.committedMinutes, childrenCommittedMinutes: childrenTotal,
                unallocatedMinutes: remainder, overflowMinutes: remainder.map { max(0, -$0) } ?? 0
            ))
            if activity.parentID == nil {
                totalWish += entry?.wishMinutes ?? 0
                totalCommitted += entry?.committedMinutes ?? 0
            }
            pending.append(contentsOf: tree.children(of: activity.id).reversed())
        }
        return AllocationReport(
            week: week, totalWishMinutes: totalWish, totalCommittedMinutes: totalCommitted,
            capacityMinutes: budgets.capacityMinutes,
            capacityOverflowMinutes: budgets.capacityMinutes.map { max(0, totalCommitted - $0) } ?? 0,
            wishOverflowMinutes: budgets.capacityMinutes.map { max(0, totalWish - $0) } ?? 0,
            nodes: nodes
        )
    }

    public static func requiredReduction(
        tree: ActivityTree, budgets: ResolvedBudgets,
        parent: ActivityID, newCommittedMinutes: Int
    ) -> (excessMinutes: Int, affectedChildren: [ActivityID]) {
        let total = committedChildren(tree: tree, budgets: budgets, parent: parent)
        let excess = max(0, total - newCommittedMinutes)
        let affected = excess == 0 ? [] : tree.children(of: parent).filter {
            if case .managed = $0.budgetMode { return true }
            return false
        }.map(\.id)
        return (excess, affected)
    }

    private static func managedBudget(for activity: Activity, budgets: ResolvedBudgets) -> BudgetEntry? {
        guard case .managed = activity.budgetMode else { return nil }
        return budgets.budget(for: activity.id)
    }

    private static func committedChildren(tree: ActivityTree, budgets: ResolvedBudgets, parent: ActivityID) -> Int {
        tree.children(of: parent).reduce(0) { $0 + (managedBudget(for: $1, budgets: budgets)?.committedMinutes ?? 0) }
    }
}
