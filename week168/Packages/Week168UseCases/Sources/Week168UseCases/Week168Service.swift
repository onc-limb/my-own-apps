import Foundation
import Week168Domain
import Week168Persistence

public actor Week168Service {
    private let store: Week168Store
    private let clock: any Clock
    private let alarms: any AlarmScheduling
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(store: Week168Store, clock: any Clock, alarms: any AlarmScheduling) {
        self.store = store
        self.clock = clock
        self.alarms = alarms
    }

    // ASSUMPTION: One service owns mutations for a store. Serialize complete operations,
    // including their alarm updates, across actor suspension points.
    private func enter() async {
        if !busy { busy = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func leave() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }

    private func settings() async throws -> CalendarSettings {
        if let stored = try await store.loadSettings() { return stored }
        // D-065: Capture the device timezone once, then aggregate using the saved settings.
        let initial = CalendarSettings(
            timeZoneIdentifier: TimeZone.current.identifier, dayStartHour: 4, weekStartWeekday: 2)
        try await store.saveSettings(initial)
        return initial
    }

    private func tree() async throws -> ActivityTree {
        try ActivityTree.build(from: await store.loadActivities())
    }

    private func activity(_ id: ActivityID) async throws -> Activity {
        guard let activity = try await tree().node(id) else {
            throw Week168ServiceError.activityNotFound(id)
        }
        return activity
    }

    private func resolved(_ week: LogicalWeek) async throws -> ResolvedBudgets {
        try await BudgetResolver.resolve(week: week, entries: store.loadBudgets(), capacities: store.loadCapacities())
    }

    private func report(_ week: LogicalWeek) async throws -> AllocationReport {
        try await AllocationValidator.report(tree: tree(), budgets: resolved(week), week: week)
    }

    private func commitmentState(_ week: LogicalWeek) async throws -> CommitmentState {
        let allocation = try await report(week)
        return try await allocation.commitmentState(hasCommitmentRecord: store.loadCommitment(for: week) != nil)
    }

    private func currentWeek(at now: Date) async throws -> LogicalWeek {
        let settings = try await settings()
        return TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: now, settings: settings), settings: settings)
    }

    private func summary(_ week: LogicalWeek, now: Date) async throws -> [ActivityID: ActivitySummary] {
        let interval = try await TimeAxis.interval(of: week, settings: settings())
        return try await Aggregator.summarize(entries: store.loadEntries(overlapping: interval),
                                             tree: tree(), budgets: resolved(week), interval: interval, now: now)
    }

    private func prepareAlarmRefresh(
        cancel old: TimeEntry?, now: Date,
        allocation: (tree: ActivityTree, budgets: ResolvedBudgets, state: CommitmentState, history: [BudgetEntry])? = nil
    ) async throws -> @Sendable () async -> Void {
        let alarms = self.alarms
        guard let running = try await store.loadRunningEntry() else {
            return { if let old { await alarms.cancelAll(for: old.id) } }
        }
        let tree: ActivityTree
        if let allocation { tree = allocation.tree } else { tree = try await self.tree() }
        guard let activity = tree.node(running.activityID) else {
            return {
                if let old { await alarms.cancelAll(for: old.id) }
                if old?.id != running.id { await alarms.cancelAll(for: running.id) }
            }
        }
        let week = try await currentWeek(at: now)
        let state: CommitmentState
        let summaries: [ActivityID: ActivitySummary]
        if let allocation {
            let budgets: ResolvedBudgets
            if allocation.budgets.week == week {
                budgets = allocation.budgets
                state = allocation.state
            } else {
                // Historical changes may also alter the current week's inherited budget.
                budgets = try await BudgetResolver.resolve(week: week, entries: allocation.history,
                                                             capacities: store.loadCapacities())
                state = try await AllocationValidator.report(tree: tree, budgets: budgets, week: week)
                    .commitmentState(hasCommitmentRecord: store.loadCommitment(for: week) != nil)
            }
            let interval = try await TimeAxis.interval(of: week, settings: settings())
            summaries = try await Aggregator.summarize(
                entries: store.loadEntries(overlapping: interval), tree: tree,
                budgets: budgets, interval: interval, now: now)
        } else {
            state = try await commitmentState(week)
            summaries = try await summary(week, now: now)
        }
        let plannedFireAt = AlarmTiming.plannedTimeFireDate(entry: running)
        let notice = AlarmTiming.budgetExhaustionFireDate(
            running: running, tree: tree, summaries: summaries,
            isCommitted: state == .committed, now: now)
        let owner = notice.flatMap { tree.node($0.activityID) }
        // All fallible reads and calculations finish before mutating notification reservations.
        return {
            if let old { await alarms.cancelAll(for: old.id) }
            if old?.id != running.id { await alarms.cancelAll(for: running.id) }
            if let fireAt = plannedFireAt {
                await alarms.schedulePlannedTimeAlarm(entryID: running.id, activityName: activity.name, fireAt: fireAt)
            }
            if let notice, let owner {
                await alarms.scheduleBudgetExhaustionNotice(activityID: owner.id, activityName: owner.name, fireAt: notice.fireAt)
            }
        }
    }

    private func refreshAlarms(cancel old: TimeEntry?, now: Date) async throws {
        let refresh = try await prepareAlarmRefresh(cancel: old, now: now)
        await refresh()
    }

    private func refreshCurrent() async throws {
        try await refreshAlarms(cancel: store.loadRunningEntry(), now: clock.now())
    }

    public func setCapacity(minutes: Int?, from week: LogicalWeek) async throws {
        await enter(); defer { leave() }
        guard minutes.map({ $0 >= 0 }) ?? true else { throw Week168ServiceError.invalidMinutes }
        // ASSUMPTION: Capacity edits may make allocation uncommitted, enabling later redistribution.
        let current = try await resolved(week)
        if current.capacityMinutes != minutes {
            try await store.upsertCapacity(CapacityEntry(effectiveFrom: week, totalMinutes: minutes))
        }
        try await refreshCurrent()
    }

    public func updateCalendarSettings(_ settings: CalendarSettings) async throws {
        await enter(); defer { leave() }
        let validated = try CalendarSettings.validated(timeZoneIdentifier: settings.timeZoneIdentifier,
                                                       dayStartHour: settings.dayStartHour,
                                                       weekStartWeekday: settings.weekStartWeekday)
        try await store.saveSettings(validated)
        try await refreshCurrent()
    }

    public func createActivity(
        name: String, parentID: ActivityID? = nil, sortOrder: Int = 0,
        budgetMode: BudgetMode = .unset, defaultPlannedMinutes: Int? = nil,
        colorHex: String = "", isArchived: Bool = false
    ) async throws -> Activity {
        await enter(); defer { leave() }
        // ASSUMPTION: Unspecified creation fields use domain-neutral defaults; IDs are generated here.
        let activity = Activity(id: ActivityID(rawValue: UUID()), name: name, parentID: parentID,
                                sortOrder: sortOrder, budgetMode: budgetMode,
                                defaultPlannedMinutes: defaultPlannedMinutes, colorHex: colorHex,
                                isArchived: isArchived)
        try await saveActivity(activity)
        return activity
    }

    private func saveActivity(_ activity: Activity, invalidatingCommitmentFor week: LogicalWeek? = nil) async throws {
        guard activity.defaultPlannedMinutes.map({ $0 > 0 }) ?? true else {
            throw Week168ServiceError.invalidMinutes
        }
        var activities = try await store.loadActivities().filter { $0.id != activity.id }
        activities.append(activity)
        _ = try ActivityTree.build(from: activities)
        try await store.upsertActivity(activity, invalidatingCommitmentFor: week)
        try await refreshCurrent()
    }

    public func updateActivity(_ activity: Activity) async throws {
        await enter(); defer { leave() }
        let previous = try await self.activity(activity.id)
        // ASSUMPTION: Activity edits have no week parameter, so invalidate the clock's current week.
        let week = previous.budgetMode == activity.budgetMode ? nil : try await currentWeek(at: clock.now())
        try await saveActivity(activity, invalidatingCommitmentFor: week)
    }

    public func archiveActivity(_ id: ActivityID, archived: Bool) async throws {
        await enter(); defer { leave() }
        var activity = try await activity(id)
        activity.isArchived = archived
        try await saveActivity(activity)
    }

    public func deleteActivity(_ id: ActivityID) async throws -> (children: Int, entries: Int) {
        await enter(); defer { leave() }
        _ = try await activity(id)
        let old = try await store.loadRunningEntry()
        let result = try await store.deleteActivity(id)
        try await refreshAlarms(cancel: old, now: clock.now())
        return (result.deletedChildren, result.deletedEntries)
    }

    public func reorderActivities(_ orderedIDs: [ActivityID], under parent: ActivityID?) async throws {
        await enter(); defer { leave() }
        let tree = try await tree()
        if let parent { _ = try await activity(parent) }
        let siblings = tree.children(of: parent)
        // ASSUMPTION: Reordering supplies each sibling exactly once, including archived siblings.
        guard Set(orderedIDs) == Set(siblings.map(\.id)), orderedIDs.count == siblings.count else {
            throw Week168ServiceError.invalidOrder
        }
        for (order, id) in orderedIDs.enumerated() {
            var activity = tree.node(id)!
            activity.sortOrder = order
            try await store.upsertActivity(activity)
        }
    }

    public func allocationReport(for week: LogicalWeek) async throws -> (report: AllocationReport, state: CommitmentState) {
        await enter(); defer { leave() }
        let allocation = try await report(week)
        let state = try await allocation.commitmentState(hasCommitmentRecord: store.loadCommitment(for: week) != nil)
        return (allocation, state)
    }

    public func setWish(activityID: ActivityID, minutes: Int, direction: BudgetDirection, week: LogicalWeek) async throws {
        await enter(); defer { leave() }
        // Wishes have no allocation constraints, including when the tree is already over budget.
        let current = try await resolved(week).budget(for: activityID)
        if current?.wishMinutes != minutes || current?.direction != direction {
            try await store.upsertBudget(BudgetEntry(activityID: activityID, effectiveFrom: week,
                direction: direction, wishMinutes: minutes, committedMinutes: current?.committedMinutes))
        }
        try await refreshCurrent()
    }

    public func commitAllocation(week: LogicalWeek, committed: [ActivityID: Int?]) async throws {
        await enter(); defer { leave() }
        let budgets = try await resolved(week)
        let tree = try await tree()
        for (id, minutes) in committed {
            guard tree.node(id) != nil else { throw Week168ServiceError.activityNotFound(id) }
            guard minutes.map({ $0 >= 0 }) ?? true else { throw Week168ServiceError.invalidMinutes }
            guard budgets.budget(for: id) != nil else { throw Week168ServiceError.budgetNotSet }
        }
        let allocation = AllocationValidator.reportApplying(
            tree: tree, budgets: budgets, week: week, proposedCommitted: committed)
        guard allocation.canCommit else { throw Week168ServiceError.allocationRejected(allocation) }
        var proposedEntries = try await store.loadBudgets()
        for (id, minutes) in committed {
            guard let entry = budgets.budget(for: id), entry.committedMinutes != minutes else { continue }
            proposedEntries.removeAll { $0.activityID == id && $0.effectiveFrom == week }
            proposedEntries.append(BudgetEntry(activityID: id, effectiveFrom: week, direction: entry.direction,
                                              wishMinutes: entry.wishMinutes, committedMinutes: minutes))
        }
        let proposedBudgets = BudgetResolver.resolve(week: week, entries: proposedEntries,
            capacities: [CapacityEntry(effectiveFrom: week, totalMinutes: budgets.capacityMinutes)])
        let now = clock.now()
        let refresh = try await prepareAlarmRefresh(cancel: store.loadRunningEntry(), now: now,
            allocation: (tree, proposedBudgets, allocation.commitmentState(hasCommitmentRecord: true), proposedEntries))
        try await store.commitAllocation(week: week, committed: committed, at: now)
        await refresh()
    }

    public func uncommitAllocation(week: LogicalWeek) async throws {
        await enter(); defer { leave() }
        try await store.deleteCommitment(for: week)
        try await refreshCurrent()
    }

    public func previewAllocation(week: LogicalWeek, committed: [ActivityID: Int?]) async throws -> AllocationReport {
        await enter(); defer { leave() }
        return try await AllocationValidator.reportApplying(
            tree: tree(), budgets: resolved(week), week: week, proposedCommitted: committed)
    }

    public func requiredReductionForParent(_ id: ActivityID, newCommitted: Int, week: LogicalWeek) async throws -> (excess: Int, children: [ActivityID]) {
        await enter(); defer { leave() }
        _ = try await activity(id)
        guard newCommitted >= 0 else { throw Week168ServiceError.invalidMinutes }
        let result = try await AllocationValidator.requiredReduction(tree: tree(), budgets: resolved(week),
                                                                     parent: id, newCommittedMinutes: newCommitted)
        return (result.excessMinutes, result.affectedChildren)
    }

    public func startOrSwitch(to activityID: ActivityID) async throws -> SwitchResult {
        await enter(); defer { leave() }
        let activity = try await activity(activityID)
        let now = clock.now()
        let old = try await store.loadRunningEntry()
        let result = EntrySwitcher.switchActivity(running: old, to: activityID,
            plannedMinutes: activity.defaultPlannedMinutes, at: now, newID: EntryID(rawValue: UUID()))
        try await store.applySwitch(result)
        try await refreshAlarms(cancel: old, now: now)
        return result
    }

    public func stopRunning() async throws {
        await enter(); defer { leave() }
        guard var running = try await store.loadRunningEntry() else { return }
        let now = clock.now()
        if now <= running.startedAt {
            // ASSUMPTION: Like an immediate switch, a zero-length stop discards the entry.
            try await store.deleteEntry(running.id)
        } else {
            running.endedAt = now
            try await store.saveEntry(running, now: now)
        }
        await alarms.cancelAll(for: running.id)
    }

    public func undoLastSwitch(_ result: SwitchResult) async throws {
        await enter(); defer { leave() }
        guard try await store.loadRunningEntry() == result.started else { throw Week168ServiceError.staleSwitch }
        let now = clock.now()
        let previous = EntrySwitcher.undo(result)
        let entries = try await store.loadEntries(overlapping: DateInterval(start: .distantPast, end: .distantFuture))
        if let previous {
            _ = try await activity(previous.activityID)
            // ASSUMPTION: Undo must not overwrite a correction made after the switch.
            guard entries.first(where: { $0.id == previous.id }) == result.closed else {
                throw Week168ServiceError.staleSwitch
            }
            try EntryValidator.validate(previous, against: entries.filter { $0.id != result.started.id }, now: now)
        }
        // ASSUMPTION: Store has no atomic undo API. Validate first and compensate the deleted
        // new entry if restoring the previous entry fails; surface any persistence failure.
        try await store.deleteEntry(result.started.id)
        do {
            if let previous { try await store.saveEntry(previous, now: now) }
        } catch {
            try await store.saveEntry(result.started, now: now)
            throw error
        }
        try await refreshAlarms(cancel: result.started, now: now)
    }

    public func changePlannedMinutes(_ minutes: Int?) async throws {
        await enter(); defer { leave() }
        guard minutes.map({ $0 > 0 }) ?? true else { throw Week168ServiceError.invalidMinutes }
        guard var running = try await store.loadRunningEntry() else { return }
        running.plannedMinutes = minutes
        let now = clock.now()
        try await store.saveEntry(running, now: now)
        try await refreshAlarms(cancel: running, now: now)
    }

    public func addEntry(activityID: ActivityID, startedAt: Date, endedAt: Date, note: String) async throws {
        await enter(); defer { leave() }
        _ = try await activity(activityID)
        let entry = TimeEntry(id: EntryID(rawValue: UUID()), activityID: activityID,
                              startedAt: startedAt, endedAt: endedAt, plannedMinutes: nil, note: note)
        try await store.saveEntry(entry, now: clock.now())
        try await refreshCurrent()
    }

    public func updateEntry(_ entry: TimeEntry) async throws {
        await enter(); defer { leave() }
        _ = try await activity(entry.activityID)
        guard entry.plannedMinutes.map({ $0 > 0 }) ?? true else { throw Week168ServiceError.invalidMinutes }
        let old = try await store.loadRunningEntry()
        let now = clock.now()
        try await store.saveEntry(entry, now: now)
        try await refreshAlarms(cancel: old, now: now)
    }

    public func deleteEntry(_ id: EntryID) async throws {
        await enter(); defer { leave() }
        let old = try await store.loadRunningEntry()
        try await store.deleteEntry(id)
        try await refreshAlarms(cancel: old, now: clock.now())
    }

    public func homeSections(recentLimit: Int) async throws -> (sections: HomeSections, summaries: [ActivityID: ActivitySummary], isCommitted: Bool, state: CommitmentState) {
        await enter(); defer { leave() }
        let now = clock.now()
        let week = try await currentWeek(at: now)
        let summaries = try await summary(week, now: now)
        let state = try await commitmentState(week)
        let committed = state == .committed
        let entries = try await store.loadEntries(overlapping: DateInterval(start: .distantPast, end: .distantFuture))
        // ASSUMPTION: Last use means entry start, across all history, including the running entry.
        let recent = entries.reduce(into: [ActivityID: Date]()) { result, entry in
            result[entry.activityID] = max(result[entry.activityID] ?? .distantPast, entry.startedAt)
        }
        let sections = try await HomeComposer.compose(tree: tree(), summaries: summaries, lastUsedAt: recent,
                                                       recentLimit: recentLimit, isCommitted: committed)
        // Consumers show the uncommitted banner only when state == .pending.
        return (sections, summaries, committed, state)
    }

    /// Serialize restore with recording/allocation changes and refresh notification reservations.
    public func restore(_ replacement: StoreBackup, replacing expected: StoreBackup) async throws {
        await enter(); defer { leave() }
        let old = try await store.loadRunningEntry()
        try await store.replaceAll(with: replacement, expected: expected, now: clock.now())
        // The replacement is already committed. A later notification refresh error must not
        // be reported as a failed restore or cause a second destructive replacement.
        if let old { await alarms.cancelAll(for: old.id) }
        try? await refreshCurrent()
    }

    public func weeklyReport(for week: LogicalWeek) async throws -> [ActivityID: ActivitySummary] {
        await enter(); defer { leave() }
        return try await summary(week, now: clock.now())
    }

    public func monthlyReport(year: Int, month: Int) async throws -> (perActivity: [ActivityID: ActivitySummary], weekCount: Int) {
        await enter(); defer { leave() }
        guard (1...12).contains(month), (1...9999).contains(year) else { throw Week168ServiceError.invalidMonth }
        let weeks = try await TimeAxis.weeks(inYear: year, month: month, settings: settings())
        let now = clock.now()
        var result: [ActivityID: ActivitySummary] = [:]
        for week in weeks {
            for (id, value) in try await summary(week, now: now) {
                guard let old = result[id] else { result[id] = value; continue }
                // AC-51 compares monthly actuals against the sum of each week's applicable budget.
                // ASSUMPTION: Sum optional budgets as zero when absent, retaining nil if all are absent.
                // If budget directions differ, monthly direction is nil to avoid a false judgment.
                result[id] = ActivitySummary(activityID: id,
                    ownMinutes: old.ownMinutes + value.ownMinutes, totalMinutes: old.totalMinutes + value.totalMinutes,
                    budgetMinutes: old.budgetMinutes == nil && value.budgetMinutes == nil ? nil
                        : (old.budgetMinutes ?? 0) + (value.budgetMinutes ?? 0),
                    direction: old.direction == value.direction ? old.direction : nil)
            }
        }
        return (result, weeks.count)
    }
}
