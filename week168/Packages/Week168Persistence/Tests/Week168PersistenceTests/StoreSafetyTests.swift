import Foundation
import Testing
@testable import Week168Persistence
import Week168Domain

struct StoreSafetyTests {
    let values = PersistenceTests()

    @Test("F-2: 循環を作る更新は拒否され、再読込後も元のツリーを保持")
    func cyclicActivityUpdateDoesNotPersist() async throws {
        let disk = try DiskFixture()
        let root = values.activity()
        let child = values.activity(parent: root.id, order: 1)
        for value in [root, child] { try await disk.store!.upsertActivity(value) }
        var invalid = root
        invalid.parentID = child.id
        await #expect(throws: ActivityTree.BuildError.self) {
            try await disk.store!.upsertActivity(invalid)
        }
        #expect(try await disk.store!.loadActivities() == [root, child])
        try disk.reopen()
        #expect(try await disk.store!.loadActivities() == [root, child])
    }

    @Test("F-2: 予算対象外の子への managed 設定は保存されない")
    func managedChildUnderExcludedDoesNotPersist() async throws {
        let disk = try DiskFixture()
        let root = values.activity(mode: .excluded)
        let child = values.activity(parent: root.id, order: 1, mode: .unset)
        for value in [root, child] { try await disk.store!.upsertActivity(value) }
        var invalid = child
        invalid.budgetMode = .managed
        await #expect(throws: ActivityTree.BuildError.budgetUnderExcluded(child.id, ancestor: root.id)) {
            try await disk.store!.upsertActivity(invalid)
        }
        #expect(try await disk.store!.loadActivities() == [root, child])
        try disk.reopen()
        #expect(try await disk.store!.loadActivities() == [root, child])
    }

    @Test("F-2: 検証失敗後も同じストアで正しい活動を保存できる")
    func validActivityUpdateAfterInvariantFailurePersists() async throws {
        let disk = try DiskFixture()
        let root = values.activity(mode: .excluded)
        var child = values.activity(parent: root.id, order: 1, mode: .unset)
        for value in [root, child] { try await disk.store!.upsertActivity(value) }
        var cyclic = root
        cyclic.parentID = child.id
        await #expect(throws: ActivityTree.BuildError.self) {
            try await disk.store!.upsertActivity(cyclic)
        }
        var invalid = child
        invalid.budgetMode = .managed
        await #expect(throws: ActivityTree.BuildError.self) {
            try await disk.store!.upsertActivity(invalid)
        }
        child.name = "Valid update"
        try await disk.store!.upsertActivity(child)
        let added = values.activity(order: 2)
        try await disk.store!.upsertActivity(added)
        try disk.reopen()
        let saved = try await disk.store!.loadActivities()
        #expect(saved == [root, child, added])
        _ = try ActivityTree.build(from: saved)
    }

    @Test func saveRetriesTwiceThenPersists() async throws {
        let disk = try DiskFixture()
        await disk.store!.failNextSaves(2)
        try await disk.store!.saveSettings(values.settings)
        try disk.reopen()
        #expect(try await disk.store!.loadSettings() == values.settings)
    }

    @Test func saveFailureThrowsUnderlyingThirdErrorAndRollsBack() async throws {
        let disk = try DiskFixture()
        await disk.store!.failNextSaves(3)
        do {
            try await disk.store!.saveSettings(values.settings)
            Issue.record("Expected save failure")
        } catch PersistenceError.saveFailed(let underlying) {
            #expect(underlying as? StoreFailure == StoreFailure(attempt: 3))
        }
        #expect(try await disk.store!.loadSettings() == nil)
        try disk.reopen()
        #expect(try await disk.store!.loadSettings() == nil)
    }

    @Test func failedSaveDoesNotLeakIntoNextTransition() async throws {
        let disk = try DiskFixture()
        await disk.store!.failNextSaves(3)
        await #expect(throws: PersistenceError.self) {
            try await disk.store!.saveEntry(values.entry(100, nil), now: values.now)
        }
        let valid = values.entry(300, nil)
        try await disk.store!.saveEntry(valid, now: values.now)
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: values.interval) == [valid])
    }

    @Test func unchangedContextDoesNotAttemptSave() async throws {
        let disk = try DiskFixture()
        await disk.store!.failNextSaves(3)
        try await disk.store!.deleteEntry(EntryID(rawValue: UUID()))
        await #expect(throws: PersistenceError.self) {
            try await disk.store!.saveSettings(values.settings)
        }
    }

    @Test func failedSwitchRestoresPreviousRunningEntry() async throws {
        let disk = try DiskFixture()
        let running = values.entry(100, nil)
        try await disk.store!.saveEntry(running, now: values.now)
        let result = EntrySwitcher.switchActivity(running: running, to: values.activityID, plannedMinutes: nil,
                                                 at: Date(timeIntervalSince1970: 200), newID: EntryID(rawValue: UUID()))
        await disk.store!.failNextSaves(3)
        await #expect(throws: PersistenceError.self) { try await disk.store!.applySwitch(result) }
        #expect(try await disk.store!.loadRunningEntry() == running)
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: values.interval) == [running])
    }

    @Test func zeroLengthSwitchDiscardsPreviousEntry() async throws {
        let disk = try DiskFixture()
        let running = values.entry(100, nil)
        try await disk.store!.saveEntry(running, now: values.now)
        let result = EntrySwitcher.switchActivity(running: running, to: values.activityID, plannedMinutes: nil,
                                                 at: running.startedAt, newID: EntryID(rawValue: UUID()))
        #expect(result.closed == nil)
        try await disk.store!.applySwitch(result)
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: values.interval) == [result.started])
    }

    @Test func staleSwitchRejectedWithoutChangingPersistedState() async throws {
        let disk = try DiskFixture()
        let result = EntrySwitcher.switchActivity(running: nil, to: values.activityID, plannedMinutes: nil,
                                                 at: Date(timeIntervalSince1970: 200), newID: EntryID(rawValue: UUID()))
        let running = values.entry(100, nil)
        try await disk.store!.saveEntry(running, now: values.now)
        await #expect(throws: PersistenceError.self) { try await disk.store!.applySwitch(result) }
        try disk.reopen()
        #expect(try await disk.store!.loadRunningEntry() == running)
    }

    @Test func malformedSwitchCannotDiscardElapsedTime() async throws {
        let disk = try DiskFixture()
        let running = values.entry(100, nil)
        try await disk.store!.saveEntry(running, now: values.now)
        let malformed = SwitchResult(previousRunning: running, closed: nil,
                                     started: values.entry(200, nil))
        await #expect(throws: PersistenceError.self) { try await disk.store!.applySwitch(malformed) }
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: values.interval) == [running])
    }

    @Test func concurrentRunningSavesHaveExactlyOneWinner() async throws {
        let disk = try DiskFixture()
        let store = disk.store!
        let successes = try await withThrowingTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                let candidate = values.entry(100, nil)
                let now = values.now
                group.addTask {
                    do {
                        try await store.saveEntry(candidate, now: now)
                        return true
                    } catch EntryValidationError.anotherEntryRunning { return false }
                }
            }
            var count = 0
            for try await success in group where success { count += 1 }
            return count
        }
        #expect(successes == 1)
        // The store is still retained here; close/reopen durability is covered separately.
        #expect(try await store.loadEntries(overlapping: values.interval).count == 1)
    }

    @Test func upsertsReplaceNaturalKeysAndPreserveSparseHistory() async throws {
        let disk = try DiskFixture()
        var activity = values.activity()
        try await disk.store!.upsertActivity(activity)
        activity.name = "Updated"
        activity.defaultPlannedMinutes = nil
        try await disk.store!.upsertActivity(activity)
        var budget = values.budget()
        try await disk.store!.upsertBudget(budget)
        budget.committedMinutes = nil
        budget.direction = .cap
        try await disk.store!.upsertBudget(budget)
        let later = BudgetEntry(activityID: budget.activityID,
                                effectiveFrom: LogicalWeek(startDay: LogicalDay(year: 2026, month: 10, day: 12)),
                                direction: .goal, wishMinutes: 100, committedMinutes: 50)
        try await disk.store!.upsertBudget(later)
        try disk.reopen()
        #expect(try await disk.store!.loadActivities() == [activity])
        #expect(try await disk.store!.loadBudgets().sorted { $0.effectiveFrom < $1.effectiveFrom } == [budget, later])
    }

    @Test func entryUpdateAndDeleteAreDurable() async throws {
        let disk = try DiskFixture()
        var record = values.entry(100, nil)
        try await disk.store!.saveEntry(record, now: values.now)
        record.endedAt = Date(timeIntervalSince1970: 200)
        record.note = "Updated"
        try await disk.store!.saveEntry(record, now: values.now)
        try disk.reopen()
        #expect(try await disk.store!.loadRunningEntry() == nil)
        #expect(try await disk.store!.loadEntries(overlapping: values.interval) == [record])
        try await disk.store!.deleteEntry(record.id)
        try disk.reopen()
        #expect(try await disk.store!.loadEntries(overlapping: values.interval).isEmpty)
    }
}
