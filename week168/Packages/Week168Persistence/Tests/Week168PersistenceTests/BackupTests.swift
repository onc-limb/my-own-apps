import Foundation
import SwiftData
import Testing
import Week168Domain
@testable import Week168Persistence

struct BackupTests {
    let now = ISO8601DateFormatter().date(from: "2026-09-16T12:00:00Z")!
    let settings = CalendarSettings(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 4, weekStartWeekday: 2)
    let week = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 14))

    func value(name: String = "Work") -> StoreBackup {
        let id = ActivityID(rawValue: UUID())
        return StoreBackup(settings: settings,
            activities: [Activity(id: id, name: name, parentID: nil, sortOrder: 0, budgetMode: .managed,
                                  defaultPlannedMinutes: nil, colorHex: "", isArchived: false)],
            budgets: [BudgetEntry(activityID: id, effectiveFrom: week, direction: .goal, wishMinutes: 120, committedMinutes: 90)],
            capacities: [CapacityEntry(effectiveFrom: week, totalMinutes: 100)],
            entries: [TimeEntry(id: EntryID(rawValue: UUID()), activityID: id, startedAt: now.addingTimeInterval(-3600),
                                endedAt: nil, plannedMinutes: 60, note: "Running")],
            commitments: [CommitmentRecord(week: week, committedAt: now.addingTimeInterval(-7200))])
    }

    func document(_ value: StoreBackup) -> [String: Any] {
        ["schemaVersion": 1, "app": ["name": "Week168", "version": "1", "build": "1"],
         "exportedAt": BackupJSON.timestamp(now), "period": ["from": "2026-09-14", "to": "2026-09-20"],
         "summary": "Deliberately untrusted and not parsed", "data": BackupJSON.rawObject(value)]
    }
    func decode(_ object: [String: Any]) throws -> StoreBackup {
        try BackupJSON.decode(JSONSerialization.data(withJSONObject: object), now: now)
    }

    @Test func committedWeekJSONRoundTripPreservesJudgmentAndRunningEntry() async throws {
        let f = try BackupFixture()
        try await f.store.saveSettings(settings)
        let old = try await f.store.backup()
        let original = value()
        try await f.store.replaceAll(with: original, expected: old, now: now)
        let exported = try await f.store.backup()
        let restored = try decode(document(exported))
        #expect(restored == exported)
        try await f.store.replaceAll(with: restored, expected: exported, now: now)
        let result = try await f.store.backup()
        #expect(result == exported)
        let tree = try ActivityTree.build(from: result.activities)
        let budgets = BudgetResolver.resolve(week: week, entries: result.budgets, capacities: result.capacities)
        let report = AllocationValidator.report(tree: tree, budgets: budgets, week: week)
        #expect(report.commitmentState(hasCommitmentRecord: result.commitments.contains { $0.week == week }) == .committed)
        let interval = TimeAxis.interval(of: week, settings: settings)
        let summary = Aggregator.summarize(entries: result.entries, tree: tree, budgets: budgets, interval: interval, now: now)
        #expect(summary[result.activities[0].id]?.totalMinutes == 60)
        #expect(summary[result.activities[0].id]?.deviationMinutes == 30)
        #expect(result.entries[0].endedAt == nil)
    }

    @Test func failureAfterAllDeletesAndInsertsRestoresEveryEntityAndSurvivesReopen() async throws {
        let f = try BackupFixture()
        try await f.store.saveSettings(settings)
        try await f.store.replaceAll(with: value(), expected: f.store.backup(), now: now)
        let original = try await f.store.backup()
        await f.store.failNextSaves(3)
        await #expect(throws: PersistenceError.self) {
            try await f.store.replaceAll(with: value(name: "Replacement"), expected: original, now: now)
        }
        #expect(try await f.store.backup() == original)
        // A fresh context confirms that neither deletes nor inserts reached the disk.
        let reopened = Week168Store(container: try Week168Store.makeContainer(at: f.url))
        #expect(try await reopened.backup() == original)
        // A subsequent valid save must not leak previously rolled-back replacement rows.
        try await f.store.saveSettings(settings)
        #expect(try await f.store.backup() == original)
    }

    @Test func submillisecondDatesPreserveMinuteBoundaryAndRawTimestamps() throws {
        let base = value()
        let start = Date(timeIntervalSince1970: 1770000000.0001)
        let end = Date(timeIntervalSince1970: 1770000059.9999)
        let entry = TimeEntry(id: EntryID(rawValue: UUID()), activityID: base.activities[0].id,
            startedAt: start, endedAt: end, plannedMinutes: nil, note: "Precision")
        let backup = StoreBackup(settings: settings, activities: base.activities, budgets: base.budgets,
            capacities: base.capacities, entries: [entry], commitments: base.commitments)
        let restored = try decode(document(backup))
        #expect(restored.entries == [entry])
        #expect(Int(restored.entries[0].endedAt!.timeIntervalSince(restored.entries[0].startedAt) / 60) == 0)
    }

    @Test func staleConfirmationCannotDeleteNewRecords() async throws {
        let f = try BackupFixture()
        try await f.store.saveSettings(settings)
        let previous = try await f.store.backup()
        try await f.store.upsertActivity(value().activities[0])
        let fresh = try await f.store.backup()
        await #expect(throws: BackupError.staleConfirmation) {
            try await f.store.replaceAll(with: value(), expected: previous, now: now)
        }
        #expect(try await f.store.backup() == fresh)
    }

    @Test func corruptedFilesAreRejectedBeforeMutation() async throws {
        let f = try BackupFixture()
        try await f.store.saveSettings(settings)
        let before = try await f.store.backup()
        let original = document(value())
        var variants: [[String: Any]] = []
        var version = original; version["schemaVersion"] = 999; variants.append(version)
        var missing = original; missing.removeValue(forKey: "data"); variants.append(missing)
        for alteration in 0..<13 {
            var changed = original
            var raw = changed["data"] as! [String: Any]
            var config = raw["settings"] as! [String: Any]
            var activities = raw["activities"] as! [[String: Any]]
            var budgets = raw["budgets"] as! [[String: Any]]
            var entries = raw["entries"] as! [[String: Any]]
            switch alteration {
            case 0: config["timeZone"] = "Not/A_Timezone"
            case 1: config["dayStartHour"] = 24
            case 2: config["weekStartWeekday"] = 0
            case 3: budgets.append(budgets[0])
            case 4: budgets[0]["effectiveFrom"] = "2026-02-30"
            case 5: budgets[0]["wishMinutes"] = Int.max
            case 6: entries[0]["activityId"] = UUID().uuidString
            case 7: activities[0]["parentId"] = activities[0]["id"]
            case 8: entries.append(entries[0].merging(["id": UUID().uuidString]) { _, new in new })
            case 9: entries[0]["endedAt"] = "2026-09-16T10:00:00Z"
            case 10: activities[0].removeValue(forKey: "parentId")
            case 11: budgets[0]["wishMinutes"] = true
            default: budgets[0]["wishMinutes"] = 1.5
            }
            raw["settings"] = config; raw["activities"] = activities; raw["budgets"] = budgets; raw["entries"] = entries
            changed["data"] = raw; variants.append(changed)
        }
        for variant in variants {
            #expect(throws: (any Error).self) { try decode(variant) }
            #expect(try await f.store.backup() == before)
        }
        for text in ["{", "null", "[]", "not json"] {
            #expect(throws: (any Error).self) { try BackupJSON.decode(Data(text.utf8), now: now) }
        }
    }

    @Test func duplicateCapacityCommitmentAndOverlappingClosedEntriesAreRejected() throws {
        let base = value()
        for key in ["capacities", "commitments"] {
            var root = document(base)
            var raw = root["data"] as! [String: Any]
            var rows = raw[key] as! [[String: Any]]; rows.append(rows[0]); raw[key] = rows; root["data"] = raw
            #expect(throws: BackupError.self) { try decode(root) }
        }
        let id = base.activities[0].id
        let one = TimeEntry(id: EntryID(rawValue: UUID()), activityID: id, startedAt: now.addingTimeInterval(-3600),
                            endedAt: now, plannedMinutes: nil, note: "")
        let two = TimeEntry(id: EntryID(rawValue: UUID()), activityID: id, startedAt: now.addingTimeInterval(-1800),
                            endedAt: now, plannedMinutes: nil, note: "")
        let invalid = StoreBackup(settings: settings, activities: base.activities, budgets: base.budgets,
            capacities: base.capacities, entries: [one, two], commitments: [])
        #expect(throws: EntryValidationError.self) { try invalid.validate(now: now) }
    }
}

private final class BackupFixture {
    let url: URL
    let store: Week168Store
    init() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("backup.store")
        store = Week168Store(container: try Week168Store.makeContainer(at: url))
        // Do not remove the directory while any actor/container/context may retain the store.
    }
}
