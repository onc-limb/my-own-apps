import Foundation
import Week168Domain
import Week168Persistence

struct ReviewActivity: Identifiable {
    var id: ActivityID { activity.id }
    let activity: Activity
    let path: [String]
    let isOutside: Bool
    let ownMinutes: Int
    let totalMinutes: Int
    let committedMinutes: Int?
    let wishMinutes: Int?
    let direction: BudgetDirection?
    let isJudged: Bool

    var deviationMinutes: Int {
        guard isJudged, let committedMinutes, let direction else { return 0 }
        return direction == .cap ? max(0, totalMinutes - committedMinutes) : max(0, committedMinutes - totalMinutes)
    }
    var status: String {
        guard isJudged, committedMinutes != nil, let direction else { return "not_judged" }
        return deviationMinutes > 0 ? (direction == .cap ? "over" : "unmet") : "within"
    }
}

struct ReviewWeek {
    let week: LogicalWeek
    let capacityMinutes: Int?
    let committedTotalMinutes: Int
    let wishTotalMinutes: Int
    let isCommitted: Bool
    let activities: [ReviewActivity]
}

struct ReviewSnapshot {
    let settings: CalendarSettings
    let activities: [Activity]
    let budgets: [BudgetEntry]
    let capacities: [CapacityEntry]
    let entries: [TimeEntry]

    static func load(store: Week168Store) async throws -> Self {
        guard let saved = try await store.loadSettings() else { throw ReviewError.missingSettings }
        let settings = try CalendarSettings.validated(timeZoneIdentifier: saved.timeZoneIdentifier,
            dayStartHour: saved.dayStartHour, weekStartWeekday: saved.weekStartWeekday)
        return try await Self(settings: settings, activities: store.loadActivities(), budgets: store.loadBudgets(),
            capacities: store.loadCapacities(), entries: store.loadEntries(overlapping:
                DateInterval(start: .distantPast, end: .distantFuture)))
    }

    func report(week: LogicalWeek, hasCommitment: Bool, now: Date, clipping: DateInterval? = nil) throws -> ReviewWeek {
        let tree = try ActivityTree.build(from: activities)
        let resolved = BudgetResolver.resolve(week: week, entries: budgets, capacities: capacities)
        let ordered = tree.topLevel().flatMap { [$0.id] + tree.descendants(of: $0.id) }.compactMap { tree.node($0) }
        // Check sums before invoking the domain's non-throwing integer arithmetic.
        _ = try reviewSum(ordered.map { resolved.budget(for: $0.id)?.wishMinutes ?? 0 })
        _ = try reviewSum(ordered.map { resolved.budget(for: $0.id)?.committedMinutes ?? 0 })
        let allocation = AllocationValidator.report(tree: tree, budgets: resolved, week: week)
        let committed = allocation.commitmentState(hasCommitmentRecord: hasCommitment) == .committed
        let full = TimeAxis.interval(of: week, settings: settings)
        let start = max(full.start, clipping?.start ?? full.start)
        let end = max(start, min(full.end, clipping?.end ?? full.end))
        let summaries = Aggregator.summarize(entries: entries, tree: tree, budgets: resolved,
            interval: DateInterval(start: start, end: end), now: now)
        let rows = ordered.compactMap { activity -> ReviewActivity? in
            guard let value = summaries[activity.id] else { return nil }
            let ancestors = tree.ancestors(of: activity.id).compactMap { tree.node($0) }
            let outside = activity.budgetMode == .excluded || ancestors.contains { $0.budgetMode == .excluded }
                || !(activity.budgetMode == .managed || ancestors.contains { $0.budgetMode == .managed })
            let budget = activity.budgetMode == .managed && !outside ? resolved.budget(for: activity.id) : nil
            return ReviewActivity(activity: activity, path: ancestors.reversed().map(\.name) + [activity.name],
                isOutside: outside, ownMinutes: value.ownMinutes, totalMinutes: value.totalMinutes,
                committedMinutes: budget?.committedMinutes, wishMinutes: budget?.wishMinutes,
                direction: budget?.direction, isJudged: committed && !outside)
        }
        return ReviewWeek(week: week, capacityMinutes: resolved.capacityMinutes,
            committedTotalMinutes: allocation.totalCommittedMinutes, wishTotalMinutes: allocation.totalWishMinutes,
            isCommitted: committed, activities: rows)
    }

    static func combine(_ weeks: [ReviewWeek]) throws -> [ReviewActivity] {
        guard let first = weeks.first else { return [] }
        return try first.activities.map { row in
            let values = weeks.compactMap { $0.activities.first { $0.id == row.id } }
            let budgets = values.compactMap(\.committedMinutes)
            let wishes = values.compactMap(\.wishMinutes)
            let sameDirection = values.allSatisfy { $0.direction == row.direction }
            // ASSUMPTION: Mixed cap/goal or any uncommitted week has no monthly judgment;
            // retain the per-week details so neither opposite directions nor pending weeks are hidden.
            return try ReviewActivity(activity: row.activity, path: row.path, isOutside: row.isOutside,
                ownMinutes: reviewSum(values.map(\.ownMinutes)), totalMinutes: reviewSum(values.map(\.totalMinutes)),
                committedMinutes: budgets.isEmpty ? nil : reviewSum(budgets),
                wishMinutes: wishes.isEmpty ? nil : reviewSum(wishes), direction: sameDirection ? row.direction : nil,
                isJudged: sameDirection && values.allSatisfy(\.isJudged))
        }
    }
}

enum ReviewError: Error { case missingSettings, invalidFile, numericRange, invalidPeriod }

func reviewSum(_ values: [Int]) throws -> Int {
    try values.reduce(0) { total, value in
        let next = total.addingReportingOverflow(value)
        guard value >= 0, !next.overflow else { throw ReviewError.numericRange }
        return next.partialValue
    }
}

func reviewText(_ key: String, _ arguments: CVarArg...) -> String {
    let values: [CVarArg]
    switch key {
    case "review.actual", "review.own", "review.budget", "review.over", "review.unmet":
        // Keep visible durations and accessibility values in the same h:mm format.
        values = arguments.map { value in
            if let minutes = value as? Int { return HomeTime.minutes(minutes) }
            return value
        }
    default:
        values = arguments
    }
    return String(format: String(localized: String.LocalizationValue(key)), arguments: values)
}

func reviewDay(_ day: LogicalDay) -> String {
    String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
}
