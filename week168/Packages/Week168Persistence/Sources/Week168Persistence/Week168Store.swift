import Foundation
import SwiftData
import Week168Domain

/// Keep one store per database for the lifetime of the application. All mutations
/// and their validation run without suspension on this actor's serial executor.
@ModelActor
public actor Week168Store {
    // Internal injection allows deterministic save-failure tests against a real store.
    var saveOperation: (ModelContext) throws -> Void = { try $0.save() }

    public init(container: ModelContainer) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = container
    }

    // Also configure the context when callers use the macro-generated initializer.
    private var context: ModelContext {
        modelContext.autosaveEnabled = false
        return modelContext
    }

    /// Explicitly local storage: no automatic CloudKit discovery or network access.
    public static func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema([
            StoredActivity.self, StoredBudgetEntry.self, StoredCapacityEntry.self,
            StoredTimeEntry.self, StoredCalendarSettings.self, StoredCommitmentRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public func loadSettings() throws -> CalendarSettings? {
        try context.fetch(FetchDescriptor<StoredCalendarSettings>()).first?.domainValue()
    }

    public func loadActivities() throws -> [Activity] {
        try context.fetch(FetchDescriptor<StoredActivity>()).map { try $0.domainValue() }
            .sorted { ($0.sortOrder, $0.id.rawValue.uuidString) < ($1.sortOrder, $1.id.rawValue.uuidString) }
    }

    public func loadBudgets() throws -> [BudgetEntry] {
        try context.fetch(FetchDescriptor<StoredBudgetEntry>()).map { try $0.domainValue() }
    }

    public func loadCapacities() throws -> [CapacityEntry] {
        try context.fetch(FetchDescriptor<StoredCapacityEntry>()).map { $0.domainValue() }
    }

    public func loadEntries(overlapping interval: DateInterval) throws -> [TimeEntry] {
        guard interval.duration > 0 else { return [] }
        // ASSUMPTION: Query intervals are half-open; ongoing entries have an open end.
        let start = interval.start
        let end = interval.end
        // SwiftData's SQLite translator rejects endedAt! in the compound predicate:
        // "The 'Foundation.PredicateExpressions.ForcedUnwrap' operator is not supported".
        // Filter the start in SQLite, then apply the open-ended condition to fetched rows.
        let descriptor = FetchDescriptor<StoredTimeEntry>(predicate: #Predicate { $0.startedAt < end })
        return try context.fetch(descriptor).filter { $0.endedAt.map { $0 > start } ?? true }
            .map { $0.domainValue() }
            .sorted { ($0.startedAt, $0.id.rawValue.uuidString) < ($1.startedAt, $1.id.rawValue.uuidString) }
    }

    public func loadRunningEntry() throws -> TimeEntry? {
        let descriptor = FetchDescriptor<StoredTimeEntry>(predicate: #Predicate { $0.endedAt == nil })
        return try context.fetch(descriptor).map { $0.domainValue() }
            .min { ($0.startedAt, $0.id.rawValue.uuidString) < ($1.startedAt, $1.id.rawValue.uuidString) }
    }

    public func saveSettings(_ settings: CalendarSettings) throws {
        _ = try CalendarSettings.validated(timeZoneIdentifier: settings.timeZoneIdentifier,
                                          dayStartHour: settings.dayStartHour,
                                          weekStartWeekday: settings.weekStartWeekday)
        let rows = try context.fetch(FetchDescriptor<StoredCalendarSettings>())
        if let row = rows.first { row.update(settings) }
        else { context.insert(StoredCalendarSettings(settings)) }
        for row in rows.dropFirst() { context.delete(row) }
        try saveChanges()
    }

    public func upsertActivity(_ activity: Activity, invalidatingCommitmentFor week: LogicalWeek? = nil) throws {
        do {
            var proposed = try loadActivities().filter { $0.id != activity.id }
            proposed.append(activity)
            _ = try ActivityTree.build(from: proposed)
            let id = activity.id.rawValue
            var descriptor = FetchDescriptor<StoredActivity>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            if let row = try context.fetch(descriptor).first { row.update(activity) }
            else { context.insert(StoredActivity(activity)) }
            if let week { try removeCommitments { $0 == week } }
            try saveChanges()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func deleteActivity(_ id: ActivityID) throws -> (deletedChildren: Int, deletedEntries: Int) {
        do {
            let activities = try context.fetch(FetchDescriptor<StoredActivity>())
            let entries = try context.fetch(FetchDescriptor<StoredTimeEntry>())
            let budgets = try context.fetch(FetchDescriptor<StoredBudgetEntry>())
            var ids: Set<UUID> = [id.rawValue]
            // Traverse in memory, including arbitrary depth and protecting against cycles.
            var changed = true
            while changed {
                changed = false
                for row in activities where row.parentID.map(ids.contains) ?? false {
                    if ids.insert(row.id).inserted { changed = true }
                }
            }
            let proposed = try activities.filter { !ids.contains($0.id) }.map { try $0.domainValue() }
            _ = try ActivityTree.build(from: proposed)
            let removed = activities.filter { ids.contains($0.id) }
            let removedEntries = entries.filter { ids.contains($0.activityID) }
            let childCount = removed.filter { $0.id != id.rawValue }.count
            for row in removed { context.delete(row) }
            for row in removedEntries { context.delete(row) }
            // ASSUMPTION: Activity deletion also removes its otherwise orphaned budget history.
            for row in budgets where ids.contains(row.activityID) { context.delete(row) }
            try saveChanges()
            return (childCount, removedEntries.count)
        } catch {
            context.rollback()
            throw error
        }
    }

    public func upsertBudget(_ entry: BudgetEntry) throws {
        do {
            try putBudget(entry)
            try removeCommitments { $0 == entry.effectiveFrom }
            try saveChanges()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func putBudget(_ entry: BudgetEntry) throws {
        // ASSUMPTION: The natural key is (activity ID, effective week); no gap rows are created.
        let id = entry.activityID.rawValue
        let year = entry.effectiveFrom.startDay.year
        let month = entry.effectiveFrom.startDay.month
        let day = entry.effectiveFrom.startDay.day
        var descriptor = FetchDescriptor<StoredBudgetEntry>(predicate: #Predicate {
            $0.activityID == id && $0.year == year && $0.month == month && $0.day == day
        })
        descriptor.fetchLimit = 1
        let match = try context.fetch(descriptor).first
        if let match { match.update(entry) } else { context.insert(StoredBudgetEntry(entry)) }
    }

    public func upsertCapacity(_ entry: CapacityEntry) throws {
        do {
            // ASSUMPTION: The natural key is the effective week.
            let year = entry.effectiveFrom.startDay.year
            let month = entry.effectiveFrom.startDay.month
            let day = entry.effectiveFrom.startDay.day
            var descriptor = FetchDescriptor<StoredCapacityEntry>(predicate: #Predicate {
                $0.year == year && $0.month == month && $0.day == day
            })
            descriptor.fetchLimit = 1
            let match = try context.fetch(descriptor).first
            if let match { match.update(entry) } else { context.insert(StoredCapacityEntry(entry)) }
            try removeCommitments { $0 >= entry.effectiveFrom }
            try saveChanges()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func loadCommitment(for week: LogicalWeek) throws -> CommitmentRecord? {
        try context.fetch(FetchDescriptor<StoredCommitmentRecord>())
            .map { $0.domainValue() }.first { $0.week == week }
    }

    public func saveCommitment(_ record: CommitmentRecord) throws {
        do {
            try putCommitment(record)
            try saveChanges()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func deleteCommitment(for week: LogicalWeek) throws {
        do {
            try removeCommitments { $0 == week }
            try saveChanges()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func commitAllocation(
        week: LogicalWeek, committed: [ActivityID: Int?], at instant: Date
    ) throws {
        do {
            let budgets = BudgetResolver.resolve(week: week, entries: try loadBudgets(), capacities: [])
            for (id, minutes) in committed {
                guard let old = budgets.budget(for: id) else { throw PersistenceError.budgetNotSet(id) }
                // Preserve sparse history when the resolved value is unchanged.
                guard old.committedMinutes != minutes else { continue }
                // ASSUMPTION: A changed inherited budget is materialized in the target week, preserving history.
                try putBudget(BudgetEntry(activityID: id, effectiveFrom: week, direction: old.direction,
                                          wishMinutes: old.wishMinutes, committedMinutes: minutes))
            }
            try putCommitment(CommitmentRecord(week: week, committedAt: instant))
            try saveChanges()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func removeCommitments(where matches: (LogicalWeek) -> Bool) throws {
        for row in try context.fetch(FetchDescriptor<StoredCommitmentRecord>())
            where matches(row.domainValue().week) {
            context.delete(row)
        }
    }

    private func putCommitment(_ record: CommitmentRecord) throws {
        try removeCommitments { $0 == record.week }
        context.insert(StoredCommitmentRecord(record))
    }

    public func saveEntry(_ entry: TimeEntry, now: Date) throws {
        try EntryValidator.validate(entry, against: allEntries(), now: now)
        try putEntry(entry)
        try saveChanges()
    }

    public func deleteEntry(_ id: EntryID) throws {
        let rawID = id.rawValue
        let descriptor = FetchDescriptor<StoredTimeEntry>(predicate: #Predicate { $0.id == rawID })
        for row in try context.fetch(descriptor) {
            context.delete(row)
        }
        try saveChanges()
    }

    public func applySwitch(_ result: SwitchResult) throws {
        let existing = try allEntries()
        // ASSUMPTION: Reject stale UI switch results rather than overwriting a newer transition.
        guard existing.first(where: { $0.endedAt == nil }) == result.previousRunning,
              result.started.endedAt == nil,
              !existing.contains(where: { $0.id == result.started.id }) else {
            throw PersistenceError.staleSwitch
        }
        // A missing closed value is only valid when the domain switch discards a zero-length entry.
        let expected = EntrySwitcher.switchActivity(
            running: result.previousRunning, to: result.started.activityID,
            plannedMinutes: result.started.plannedMinutes, at: result.started.startedAt,
            newID: result.started.id
        )
        guard result.closed == expected.closed else { throw PersistenceError.staleSwitch }
        var proposed = existing.filter { $0.id != result.previousRunning?.id }
        // ASSUMPTION: With no `now` argument, the switch instant is its validation clock.
        let now = result.started.startedAt
        if let closed = result.closed {
            try EntryValidator.validate(closed, against: proposed, now: now)
            proposed.append(closed)
        }
        try EntryValidator.validate(result.started, against: proposed, now: now)
        // Fetch the previous row before mutating, so a fetch failure leaves no partial transition.
        if let previous = result.previousRunning {
            let id = previous.id.rawValue
            let descriptor = FetchDescriptor<StoredTimeEntry>(predicate: #Predicate { $0.id == id })
            for row in try context.fetch(descriptor) { context.delete(row) }
        }
        if let closed = result.closed { context.insert(StoredTimeEntry(closed)) }
        context.insert(StoredTimeEntry(result.started))
        try saveChanges()
    }

    private func allEntries() throws -> [TimeEntry] {
        try context.fetch(FetchDescriptor<StoredTimeEntry>()).map { $0.domainValue() }
            .sorted { ($0.startedAt, $0.id.rawValue.uuidString) < ($1.startedAt, $1.id.rawValue.uuidString) }
    }

    private func putEntry(_ entry: TimeEntry) throws {
        let id = entry.id.rawValue
        var descriptor = FetchDescriptor<StoredTimeEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let row = try context.fetch(descriptor).first { row.update(entry) }
        else { context.insert(StoredTimeEntry(entry)) }
    }

    private func saveChanges() throws {
        // ASSUMPTION: Three immediate attempts avoid actor reentrancy during a transition.
        for attempt in 1...3 {
            guard context.hasChanges else { return }
            do {
                try saveOperation(context)
                return
            } catch {
                if attempt == 3 {
                    context.rollback()
                    throw PersistenceError.saveFailed(underlying: error)
                }
            }
        }
    }
}
