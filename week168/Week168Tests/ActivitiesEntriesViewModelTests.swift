import Foundation
import XCTest
import Week168Domain
import Week168Persistence
import Week168UseCases
@testable import Week168

@MainActor
final class ActivitiesEntriesViewModelTests: XCTestCase {
    func testCreateEditReorderArchiveAndPreserveParent() async throws {
        let f = try ManagementFixture()
        let parent = try await f.activity("Parent")
        let otherParent = try await f.activity("Other parent")
        let first = try await f.activity("First", parent: parent.id)
        let second = try await f.activity("Second", parent: parent.id)
        await f.model.refresh()
        await f.model.move(second, offset: -1)
        XCTAssertEqual(f.model.tree?.children(of: parent.id).map(\.id), [second.id, first.id])
        let saved = await f.model.saveActivity(original: first, name: "Renamed", parent: otherParent.id,
                                               mode: .unset, minutes: "45", color: "#3478F6")
        XCTAssertTrue(saved)
        let edited = try XCTUnwrap(f.model.tree?.node(first.id))
        XCTAssertEqual(edited.parentID, parent.id)
        XCTAssertEqual(edited.name, "Renamed")
        XCTAssertEqual(edited.defaultPlannedMinutes, 45)
        XCTAssertEqual(edited.colorHex, "#3478F6")
        XCTAssertEqual(f.model.tree?.children(of: parent.id).map(\.id), [second.id, first.id])
        await f.model.archive(edited)
        XCTAssertEqual(f.model.tree?.node(first.id)?.isArchived, true)
        XCTAssertTrue(f.model.activities.contains { $0.id == first.id })
        await f.model.archive(try XCTUnwrap(f.model.tree?.node(first.id)))
        XCTAssertEqual(f.model.tree?.node(first.id)?.isArchived, false)
        let created = await f.model.saveActivity(original: nil, name: "Third", parent: parent.id,
                                                 mode: .excluded, minutes: "20", color: "")
        XCTAssertTrue(created)
        XCTAssertEqual(f.model.tree?.children(of: parent.id).last?.name, "Third")
        XCTAssertEqual(f.model.tree?.children(of: parent.id).last?.defaultPlannedMinutes, 20)
    }

    func testExcludedAncestorAndManagedDescendantRejections() async throws {
        let f = try ManagementFixture()
        let excluded = try await f.activity("Excluded", mode: .excluded)
        let middle = try await f.activity("Middle", parent: excluded.id)
        let parent = try await f.activity("Parent")
        _ = try await f.activity("Managed", parent: parent.id, mode: .managed)
        await f.model.refresh()
        XCTAssertNotNil(f.model.activityValidation(name: "Invalid", parent: middle.id,
                                                   mode: .managed, minutes: "", editing: nil))
        let saved = await f.model.saveActivity(original: nil, name: "Invalid", parent: middle.id,
                                               mode: .managed, minutes: "", color: "")
        XCTAssertFalse(saved)
        XCTAssertEqual(f.model.issue, String(localized: "activities.error.excludedAncestor"))
        XCTAssertNotNil(f.model.activityValidation(name: parent.name, parent: nil,
                                                   mode: .excluded, minutes: "", editing: parent.id))
        let unset = await f.model.saveActivity(original: nil, name: "Shared", parent: middle.id,
                                               mode: .unset, minutes: "", color: "")
        XCTAssertTrue(unset)
        XCTAssertEqual(ActivityBudgetChoice.allCases.count, 3)
        XCTAssertNotEqual(ActivityBudgetChoice.unset.symbol, ActivityBudgetChoice.excluded.symbol)
    }

    func testDeletePreviewCountsAllDescendantsAndTheirEntries() async throws {
        let f = try ManagementFixture()
        let parent = try await f.activity("Parent")
        let child = try await f.activity("Child", parent: parent.id)
        let grandchild = try await f.activity("Grandchild", parent: child.id)
        let unrelated = try await f.activity("Unrelated")
        try await f.entry(parent.id, start: "2026-09-15T10:00:00Z", end: "2026-09-15T11:00:00Z")
        try await f.entry(grandchild.id, start: "2026-09-15T11:00:00Z", end: "2026-09-15T12:00:00Z")
        try await f.entry(unrelated.id, start: "2026-09-15T12:00:00Z", end: "2026-09-15T13:00:00Z")
        await f.model.prepareDeletion(parent)
        let preview = try XCTUnwrap(f.model.deletion)
        XCTAssertEqual(preview.children, 2)
        XCTAssertEqual(preview.entries, 2)
        XCTAssertEqual(f.model.activities.count, 4)
        await f.model.deleteActivity(preview)
        XCTAssertEqual(f.model.activities.map(\.id), [unrelated.id])
        XCTAssertEqual(f.model.entries.count, 1)
    }

    func testDeletionRequiresNewConfirmationWhenImpactChanges() async throws {
        let f = try ManagementFixture()
        let parent = try await f.activity("Parent")
        await f.model.prepareDeletion(parent)
        let preview = try XCTUnwrap(f.model.deletion)
        _ = try await f.activity("New child", parent: parent.id)
        await f.model.deleteActivity(preview)
        XCTAssertNotNil(f.model.tree?.node(parent.id))
        XCTAssertEqual(f.model.deletion?.children, 1)
        XCTAssertEqual(f.model.issue, String(localized: "activities.error.impactChanged"))
    }

    func testLogicalDayUsesStoredTimezoneAndDayStartAndSortsNewestFirst() async throws {
        let f = try ManagementFixture()
        try await f.service.updateCalendarSettings(CalendarSettings(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 4, weekStartWeekday: 2))
        let activity = try await f.activity("Activity")
        try await f.entry(activity.id, start: "2026-09-15T18:00:00Z", end: "2026-09-15T18:30:00Z")
        // 03:30 JST crosses the boundary, but belongs once to its starting logical day.
        try await f.entry(activity.id, start: "2026-09-15T18:30:00Z", end: "2026-09-15T19:15:00Z")
        try await f.entry(activity.id, start: "2026-09-15T19:15:00Z", end: "2026-09-15T19:30:00Z")
        await f.model.refresh()
        XCTAssertEqual(f.model.daySections.map(\.day), [LogicalDay(year: 2026, month: 9, day: 16), LogicalDay(year: 2026, month: 9, day: 15)])
        XCTAssertEqual(f.model.daySections[1].entries.map(\.startedAt), [f.date("2026-09-15T18:30:00Z"), f.date("2026-09-15T18:00:00Z")])
        try await f.service.updateCalendarSettings(CalendarSettings(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 0, weekStartWeekday: 2))
        await f.model.refresh()
        XCTAssertEqual(f.model.daySections.count, 1)
        XCTAssertEqual(f.model.daySections.first?.day, LogicalDay(year: 2026, month: 9, day: 16))
    }

    func testOverlapReportsConflictingActivityAndTimesAndPreservesData() async throws {
        let f = try ManagementFixture()
        let activity = try await f.activity("Deep work")
        try await f.entry(activity.id, start: "2026-09-16T10:00:00Z", end: "2026-09-16T11:00:00Z")
        await f.model.refresh()
        let saved = await f.model.saveEntry(original: nil, activity: activity.id,
            start: f.date("2026-09-16T10:30:00Z"), end: f.date("2026-09-16T11:30:00Z"), note: "Conflict")
        XCTAssertFalse(saved)
        let issue = try XCTUnwrap(f.model.issue)
        XCTAssertTrue(issue.contains("Deep work"))
        XCTAssertTrue(issue.contains(f.model.timestamp(f.date("2026-09-16T10:00:00Z"))))
        XCTAssertTrue(issue.contains(f.model.timestamp(f.date("2026-09-16T11:00:00Z"))))
        XCTAssertEqual(f.model.entries.count, 1)
    }

    func testFutureReverseAndZeroLengthHaveDistinctReasons() async throws {
        let f = try ManagementFixture()
        let activity = try await f.activity("Activity")
        let cases: [(Date, Date, String)] = [
            (f.now, f.now.addingTimeInterval(60), "entries.error.future"),
            (f.now.addingTimeInterval(-60), f.now.addingTimeInterval(-120), "entries.error.order"),
            (f.now, f.now, "entries.error.zero")
        ]
        for (start, end, key) in cases {
            let saved = await f.model.saveEntry(original: nil, activity: activity.id, start: start, end: end, note: "")
            XCTAssertFalse(saved)
            XCTAssertEqual(f.model.issue, String(localized: String.LocalizationValue(key)))
        }
    }

    func testManualEntryEditDeleteAndArchivedHistory() async throws {
        let f = try ManagementFixture()
        let activity = try await f.activity("Activity")
        let added = await f.model.saveEntry(original: nil, activity: activity.id,
            start: f.now.addingTimeInterval(-7200), end: f.now.addingTimeInterval(-3600), note: "First")
        XCTAssertTrue(added)
        let entry = try XCTUnwrap(f.model.entries.first)
        let edited = await f.model.saveEntry(original: entry, activity: activity.id,
            start: entry.startedAt, end: entry.endedAt, note: "Edited")
        XCTAssertTrue(edited) // Same-ID edit must not overlap itself.
        XCTAssertEqual(f.model.entries.first?.note, "Edited")
        await f.model.archive(activity)
        XCTAssertEqual(f.model.entries.count, 1)
        await f.model.deleteEntry(entry)
        XCTAssertTrue(f.model.entries.isEmpty)
    }

    func testRunningEntryCanReceiveEndAndPreservesPlannedMinutes() async throws {
        let f = try ManagementFixture()
        let activity = try await f.activity("Running")
        let entry = TimeEntry(id: EntryID(rawValue: UUID()), activityID: activity.id,
            startedAt: f.now.addingTimeInterval(-3600), endedAt: nil, plannedMinutes: 90, note: "")
        try await f.store.saveEntry(entry, now: f.now)
        await f.model.refresh()
        XCTAssertNil(f.model.daySections.first?.entries.first?.endedAt)
        let saved = await f.model.saveEntry(original: entry, activity: activity.id,
            start: entry.startedAt, end: f.now, note: "Finished")
        XCTAssertTrue(saved)
        XCTAssertEqual(f.model.entries.first?.endedAt, f.now)
        XCTAssertEqual(f.model.entries.first?.plannedMinutes, 90)
        let running = try await f.store.loadRunningEntry()
        XCTAssertNil(running)
    }
}

@MainActor
private final class ManagementFixture {
    let now = ISO8601DateFormatter().date(from: "2026-09-16T12:00:00Z")!
    let store: Week168Store
    let service: Week168Service
    let model: ActivitiesEntriesViewModel

    init() throws {
        // Match AllocationViewModelTests: do not delete this directory while the
        // model, service, or ModelContainer can still use the backing store.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = Week168Store(container: try Week168Store.makeContainer(at: directory.appendingPathComponent("test.store")))
        service = Week168Service(store: store, clock: ManagementClock(date: now), alarms: ManagementAlarms())
        model = ActivitiesEntriesViewModel(store: store, service: service)
    }

    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    func activity(_ name: String, parent: ActivityID? = nil, mode: BudgetMode = .unset) async throws -> Activity {
        try await service.createActivity(name: name, parentID: parent, budgetMode: mode)
    }

    func entry(_ id: ActivityID, start: String, end: String) async throws {
        try await service.addEntry(activityID: id, startedAt: date(start), endedAt: date(end), note: "")
    }
}

private struct ManagementClock: Clock {
    let date: Date
    func now() -> Date { date }
}

private struct ManagementAlarms: AlarmScheduling {
    func schedulePlannedTimeAlarm(entryID: EntryID, activityName: String, fireAt: Date) async {}
    func scheduleBudgetExhaustionNotice(activityID: ActivityID, activityName: String, fireAt: Date) async {}
    func cancelAll(for entryID: EntryID) async {}
}
