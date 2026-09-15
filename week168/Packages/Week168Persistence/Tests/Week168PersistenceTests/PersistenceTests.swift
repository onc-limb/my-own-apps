import Foundation
import SwiftData
import Testing
@testable import Week168Persistence
import Week168Domain

struct PersistenceTests {
    let now = Date(timeIntervalSince1970: 100_000)
    let activityID = ActivityID(rawValue: UUID())
    let settings = CalendarSettings(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 4, weekStartWeekday: 2)
    let week = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 14))

    func activity(parent: ActivityID? = nil, order: Int = 0, mode: BudgetMode = .managed) -> Activity {
        Activity(id: ActivityID(rawValue: UUID()), name: "Activity \(order)", parentID: parent,
                 sortOrder: order, budgetMode: mode, defaultPlannedMinutes: 25,
                 colorHex: "#abcdef", isArchived: order == 2)
    }

    func entry(_ start: Double = 100, _ end: Double? = 200, planned: Int? = 30) -> TimeEntry {
        TimeEntry(id: EntryID(rawValue: UUID()), activityID: activityID,
                  startedAt: Date(timeIntervalSince1970: start), endedAt: end.map { Date(timeIntervalSince1970: $0) },
                  plannedMinutes: planned, note: "記録メモ")
    }

    func budget(committed: Int? = 90) -> BudgetEntry {
        BudgetEntry(activityID: activityID, effectiveFrom: week, direction: .goal,
                    wishMinutes: 120, committedMinutes: committed)
    }

    var interval: DateInterval { DateInterval(start: Date(timeIntervalSince1970: 100), end: now) }

    @Test func t01SettingsRoundTrip() async throws {
        let disk = try DiskFixture()
        try await disk.store!.saveSettings(settings)
        #expect(try await disk.store!.loadSettings() == settings)
    }

    @Test func t02ThreeLevelActivitiesRoundTrip() async throws {
        let disk = try DiskFixture()
        let root = activity()
        let child = activity(parent: root.id, order: 1, mode: .unset)
        let leaf = activity(parent: child.id, order: 2, mode: .excluded)
        for value in [root, child, leaf] { try await disk.store!.upsertActivity(value) }
        #expect(try await disk.store!.loadActivities() == [root, child, leaf])
    }

    @Test func t03BudgetRoundTrip() async throws {
        let disk = try DiskFixture()
        try await disk.store!.upsertBudget(budget())
        #expect(try await disk.store!.loadBudgets() == [budget()])
    }

    @Test func t04NilCommittedBudget() async throws {
        let disk = try DiskFixture()
        try await disk.store!.upsertBudget(budget(committed: nil))
        try disk.reopen()
        #expect(try await disk.store!.loadBudgets() == [budget(committed: nil)])
    }

    @Test func t05CapacityRoundTripIncludingNil() async throws {
        let disk = try DiskFixture()
        for minutes: Int? in [600, nil] {
            let value = CapacityEntry(effectiveFrom: week, totalMinutes: minutes)
            try await disk.store!.upsertCapacity(value)
            try disk.reopen()
            #expect(try await disk.store!.loadCapacities() == [value])
        }
    }

    @Test func t06EntryRoundTrip() async throws {
        let disk = try DiskFixture()
        let value = entry()
        try await disk.store!.saveEntry(value, now: now)
        #expect(try await disk.store!.loadEntries(overlapping: interval) == [value])
    }

    @Test func t07RunningEndRemainsNil() async throws {
        let disk = try DiskFixture()
        let value = entry(100, nil)
        try await disk.store!.saveEntry(value, now: now)
        #expect(try await disk.store!.loadRunningEntry() == value)
    }

    @Test func t08NilPlannedMinutes() async throws {
        let disk = try DiskFixture()
        let value = entry(planned: nil)
        try await disk.store!.saveEntry(value, now: now)
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: interval) == [value])
    }

    @Test func t09RunningEntrySurvivesReopen() async throws {
        let disk = try DiskFixture()
        let value = entry(100, nil)
        try await disk.store!.saveEntry(value, now: now)
        weak var oldContainer = disk.container
        weak var oldStore = disk.store
        try disk.reopen()
        #expect(oldStore == nil)
        #expect(oldContainer == nil)
        #expect(try await disk.store!.loadRunningEntry() == value)
    }

    @Test func t10ActivitiesBudgetsSettingsSurviveReopen() async throws {
        let disk = try DiskFixture()
        let value = activity()
        try await disk.store!.upsertActivity(value)
        try await disk.store!.upsertBudget(budget())
        try await disk.store!.saveSettings(settings)
        try disk.reopen()
        #expect(try await disk.store!.loadActivities() == [value])
        #expect(try await disk.store!.loadBudgets() == [budget()])
        #expect(try await disk.store!.loadSettings() == settings)
    }

    @Test func t11UnsavedChangesDoNotSurviveReopen() async throws {
        let disk = try DiskFixture()
        try await disk.store!.insertWithoutSavingForTest(activity())
        #expect(try await disk.store!.loadActivities().count == 1)
        try disk.reopen()
        #expect(try await disk.store!.loadActivities().isEmpty)
    }

    @Test func t12OutsideAndTouchingBoundariesExcluded() async throws {
        let disk = try DiskFixture()
        for value in [entry(0, 100), entry(200, 300)] { try await disk.store!.saveEntry(value, now: now) }
        let query = DateInterval(start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 200))
        #expect(try await disk.store!.loadEntries(overlapping: query).isEmpty)
    }

    @Test func t13SpanningEntryIncluded() async throws {
        let disk = try DiskFixture()
        let value = entry(0, 300)
        try await disk.store!.saveEntry(value, now: now)
        let query = DateInterval(start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 200))
        #expect(try await disk.store!.loadEntries(overlapping: query) == [value])
    }

    @Test func t14RunningEntryOverlap() async throws {
        let disk = try DiskFixture()
        let value = entry(100, nil)
        try await disk.store!.saveEntry(value, now: now)
        #expect(try await disk.store!.loadEntries(overlapping: interval) == [value])
        let before = DateInterval(start: Date(timeIntervalSince1970: 0), end: value.startedAt)
        #expect(try await disk.store!.loadEntries(overlapping: before).isEmpty)
    }

    @Test func t15RejectSecondRunningAndDoNotPersist() async throws {
        let disk = try DiskFixture()
        let first = entry(100, nil)
        try await disk.store!.saveEntry(first, now: now)
        await #expect(throws: EntryValidationError.anotherEntryRunning(first.id)) {
            try await disk.store!.saveEntry(entry(300, nil), now: now)
        }
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: interval) == [first])
    }

    @Test func t16RejectOverlapAndDoNotPersist() async throws {
        let disk = try DiskFixture()
        let first = entry()
        try await disk.store!.saveEntry(first, now: now)
        await #expect(throws: EntryValidationError.overlaps(with: [first.id])) {
            try await disk.store!.saveEntry(entry(150, 250), now: now)
        }
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: interval) == [first])
    }

    @Test func t17RejectFutureAndDoNotPersist() async throws {
        let disk = try DiskFixture()
        await #expect(throws: EntryValidationError.inFuture) {
            try await disk.store!.saveEntry(entry(100_001, nil), now: now)
        }
        try disk.reopen()
        #expect(try await disk.store!.loadRunningEntry() == nil)
        #expect(try await disk.store!.loadEntries(overlapping: DateInterval(start: now, duration: 100)).isEmpty)
    }

    @Test func t18ValidSaveAfterValidationFailure() async throws {
        let disk = try DiskFixture()
        await #expect(throws: EntryValidationError.inFuture) {
            try await disk.store!.saveEntry(entry(100_001, nil), now: now)
        }
        let value = entry()
        try await disk.store!.saveEntry(value, now: now)
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: interval) == [value])
    }

    @Test func t19SwitchPersistsBothAtomically() async throws {
        let disk = try DiskFixture()
        let running = entry(100, nil)
        try await disk.store!.saveEntry(running, now: now)
        let result = EntrySwitcher.switchActivity(running: running, to: activityID, plannedMinutes: 20,
                                                 at: Date(timeIntervalSince1970: 200), newID: EntryID(rawValue: UUID()))
        try await disk.store!.applySwitch(result)
        try disk.reopen()
        #expect(try await disk.store!.loadRunningEntry() == result.started)
        #expect(try await disk.store!.loadEntries(overlapping: interval) == [result.closed!, result.started])
    }

    @Test func t20SwitchWithoutClosedEntry() async throws {
        let disk = try DiskFixture()
        let result = EntrySwitcher.switchActivity(running: nil, to: activityID, plannedMinutes: nil,
                                                 at: Date(timeIntervalSince1970: 200), newID: EntryID(rawValue: UUID()))
        try await disk.store!.applySwitch(result)
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: interval) == [result.started])
    }

    func seedTree(_ store: Week168Store) async throws -> (Activity, Activity) {
        let root = activity()
        let child = activity(parent: root.id, order: 1)
        let leaf = activity(parent: child.id, order: 2)
        let survivor = activity(order: 3)
        for (index, value) in [root, child, leaf, survivor].enumerated() {
            try await store.upsertActivity(value)
            var record = entry(Double(100 + index * 100), Double(200 + index * 100))
            record.activityID = value.id
            try await store.saveEntry(record, now: now)
        }
        return (root, survivor)
    }

    @Test func t21DeleteReturnsDescendantAndEntryCounts() async throws {
        let disk = try DiskFixture()
        let (root, _) = try await seedTree(disk.store!)
        let counts = try await disk.store!.deleteActivity(root.id)
        #expect(counts.deletedChildren == 2)
        #expect(counts.deletedEntries == 3)
    }

    @Test func t22DeletionDurableAndUnrelatedRecordsSurvive() async throws {
        let disk = try DiskFixture()
        let (root, survivor) = try await seedTree(disk.store!)
        _ = try await disk.store!.deleteActivity(root.id)
        try disk.reopen()
        #expect(try await disk.store!.loadActivities() == [survivor])
        let records = try await disk.store!.loadEntries(overlapping: interval)
        #expect(records.count == 1)
        #expect(records.first?.activityID == survivor.id)
    }

    @Test func t23NoUniqueAttributesInSources() throws {
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/Week168Persistence")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            #expect(!source.contains("#Unique"))
            #expect(source.range(of: #"@Attribute\s*\(\s*\.unique"#, options: .regularExpression) == nil)
        }
    }
}

extension Week168Store {
    func insertWithoutSavingForTest(_ activity: Activity) {
        #expect(!modelContext.autosaveEnabled)
        modelContext.insert(StoredActivity(activity))
    }
}
