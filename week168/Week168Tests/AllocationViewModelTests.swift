import Foundation
import XCTest
import Week168Domain
import Week168Persistence
import Week168UseCases
@testable import Week168

@MainActor
final class AllocationViewModelTests: XCTestCase {
    func testDraftReallocationIsAtomicAndPreservesWishes() async throws {
        let f = try Fixture()
        let parent = try await f.activity("Parent")
        let child = try await f.activity("Child", parent: parent.id)
        try await f.budget(parent.id, wish: 720, committed: 720)
        try await f.budget(child.id, wish: 720, committed: 720)
        try await f.service.setCapacity(minutes: 600, from: f.week)
        await f.model.refresh(at: f.now)
        XCTAssertFalse(f.model.canCommit)
        f.model.setDraft("600", for: parent.id)
        await f.model.validateDraft(parent: parent.id)
        XCTAssertEqual(f.model.node(parent.id)?.overflowMinutes, 120)
        XCTAssertEqual(f.model.affectedChildren[parent.id], [child.id])
        XCTAssertEqual(f.model.name(parent.id), "Parent")
        XCTAssertFalse(f.model.canCommit)
        f.model.setDraft("600", for: child.id)
        await f.model.validateDraft()
        XCTAssertEqual(f.model.node(parent.id)?.overflowMinutes, 0)
        XCTAssertTrue(f.model.canCommit)
        let before = try await f.store.loadBudgets()
        XCTAssertTrue(before.allSatisfy { $0.committedMinutes == 720 })
        await f.model.commit()
        XCTAssertTrue(f.model.isCommitted)
        let after = try await f.store.loadBudgets()
        XCTAssertTrue(after.allSatisfy { $0.committedMinutes == 600 && $0.wishMinutes == 720 })
    }

    func testWishSavesDespiteOverflowAndInvalidCommittedInput() async throws {
        let f = try Fixture()
        let parent = try await f.activity("Parent")
        let child = try await f.activity("Child", parent: parent.id)
        try await f.budget(parent.id, wish: 60, committed: 60)
        try await f.budget(child.id, wish: 120, committed: 120)
        await f.model.refresh(at: f.now)
        f.model.setDraft("invalid", for: parent.id)
        await f.model.validateDraft()
        let saved = await f.model.saveWish(2000, direction: .goal, for: parent.id)
        XCTAssertTrue(saved)
        XCTAssertEqual(f.model.node(parent.id)?.wishMinutes, 2000)
        XCTAssertEqual(f.model.input(parent.id), "invalid")
        XCTAssertFalse(f.model.canCommit)
        let entries = try await f.store.loadBudgets()
        XCTAssertEqual(entries.first { $0.activityID == parent.id }?.wishMinutes, 2000)
    }

    func testClearingCommittedPreservesExplicitNilAndWish() async throws {
        let f = try Fixture()
        let activity = try await f.activity("Activity")
        try await f.budget(activity.id, wish: 120, committed: 60)
        await f.model.refresh(at: f.now)
        f.model.setDraft("", for: activity.id)
        await f.model.validateDraft()
        XCTAssertNil(f.model.node(activity.id)?.committedMinutes)
        XCTAssertEqual(f.model.node(activity.id)?.wishMinutes, 120)
        await f.model.commit()
        let entries = try await f.store.loadBudgets()
        XCTAssertNil(entries.first?.committedMinutes)
        XCTAssertTrue(f.model.isCommitted)
    }

    func testDraftsStayWithTheirWeek() async throws {
        let f = try Fixture()
        let activity = try await f.activity("Activity")
        try await f.budget(activity.id, wish: 120, committed: 60)
        await f.model.refresh(at: f.now)
        f.model.setDraft("30", for: activity.id)
        await f.model.validateDraft()
        await f.model.selectWeek(offset: 1, at: f.now)
        XCTAssertEqual(f.model.input(activity.id), "60")
        f.model.setDraft("45", for: activity.id)
        await f.model.validateDraft()
        await f.model.selectWeek(offset: nil, at: f.now)
        XCTAssertEqual(f.model.week, f.week)
        XCTAssertEqual(f.model.input(activity.id), "30")
    }

    func testUnallocatedExcludedAndMissingCapacity() async throws {
        let f = try Fixture()
        let parent = try await f.activity("Parent")
        let child = try await f.activity("Child", parent: parent.id)
        let shared = try await f.activity("Shared", parent: parent.id, mode: .unset)
        let excluded = try await f.activity("Excluded", mode: .excluded)
        try await f.budget(parent.id, wish: 180, committed: 180)
        try await f.budget(child.id, wish: 60, committed: 60)
        await f.model.refresh(at: f.now)
        XCTAssertNil(f.model.report?.capacityMinutes)
        XCTAssertEqual(f.model.report?.capacityOverflowMinutes, 0)
        XCTAssertTrue(f.model.hasSharedChildren(parent.id))
        XCTAssertEqual(f.model.node(parent.id)?.unallocatedMinutes, 120)
        XCTAssertNotNil(f.model.node(shared.id))
        XCTAssertNil(f.model.node(excluded.id))
    }

    func testCommitRejectionUsesFreshReportAndKeepsDraft() async throws {
        let f = try Fixture()
        let activity = try await f.activity("Named activity")
        try await f.budget(activity.id, wish: 120, committed: 60)
        await f.model.refresh(at: f.now)
        f.model.setDraft("90", for: activity.id)
        await f.model.validateDraft()
        XCTAssertTrue(f.model.canCommit)
        try await f.service.setCapacity(minutes: 30, from: f.week)
        await f.model.commit()
        XCTAssertEqual(f.model.report?.capacityOverflowMinutes, 60)
        XCTAssertEqual(f.model.name(activity.id), "Named activity")
        XCTAssertEqual(f.model.input(activity.id), "90")
        XCTAssertEqual(f.model.issueKey, "allocation.error.rejected")
        XCTAssertFalse(f.model.isCommitted)
    }

    func testMissingBudgetRequiresWishAndEnablesUnsetActivity() async throws {
        let f = try Fixture()
        let activity = try await f.activity("Unset", mode: .unset)
        await f.model.refresh(at: f.now)
        XCTAssertNil(f.model.node(activity.id)?.direction)
        let saved = await f.model.saveWish(300, direction: .goal, for: activity.id)
        XCTAssertTrue(saved)
        XCTAssertEqual(f.model.node(activity.id)?.mode, .managed)
        XCTAssertEqual(f.model.node(activity.id)?.wishMinutes, 300)
        XCTAssertEqual(f.model.node(activity.id)?.direction, .goal)
        XCTAssertNil(f.model.node(activity.id)?.committedMinutes)
    }

    func testLatestPreviewWinsDuringRapidEditing() async throws {
        let f = try Fixture()
        let activity = try await f.activity("Activity")
        try await f.budget(activity.id, wish: 120, committed: 60)
        await f.model.refresh(at: f.now)
        for minutes in 0...30 { f.model.setDraft(String(minutes), for: activity.id) }
        await f.model.validateDraft()
        XCTAssertEqual(f.model.node(activity.id)?.committedMinutes, 30)
        XCTAssertFalse(f.model.isPreviewing)
    }

    func testUnrepresentableCommittedSumShowsErrorInsteadOfTrapping() async throws {
        let f = try Fixture()
        let first = try await f.activity("First")
        let second = try await f.activity("Second")
        try await f.budget(first.id, wish: 60, committed: 1)
        try await f.budget(second.id, wish: 60, committed: 1)
        await f.model.refresh(at: f.now)
        f.model.setDraft(String(Int.max), for: first.id)
        await f.model.validateDraft()
        XCTAssertEqual(f.model.issueKey, "allocation.error.numericRange")
        XCTAssertFalse(f.model.canCommit)
        XCTAssertEqual(f.model.input(first.id), String(Int.max))
    }

    func testExcludedAncestorSubtreeIsHidden() async throws {
        let f = try Fixture()
        let excluded = try await f.activity("Excluded", mode: .excluded)
        let child = try await f.activity("Child", parent: excluded.id, mode: .unset)
        await f.model.refresh(at: f.now)
        XCTAssertNil(f.model.node(excluded.id))
        XCTAssertNil(f.model.node(child.id))
        XCTAssertTrue(f.model.nodes.isEmpty)
    }

    func testHomeUsesWeeklyCommitmentRecordInsteadOfFeasibility() throws {
        let week = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 14))
        let now = ISO8601DateFormatter().date(from: "2026-09-16T12:00:00Z")!
        let settings = CalendarSettings(timeZoneIdentifier: "UTC", dayStartHour: 0, weekStartWeekday: 2)
        let id = ActivityID(rawValue: UUID())
        let activity = Activity(id: id, name: "Activity", parentID: nil, sortOrder: 0,
            budgetMode: .managed, defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
        let tree = try ActivityTree.build(from: [activity])
        let budget = BudgetEntry(activityID: id, effectiveFrom: week, direction: .goal,
                                 wishMinutes: 120, committedMinutes: 60)
        var snapshot = HomeSnapshot(tree: tree, entries: [], budgets: [budget], capacities: [], settings: settings)
        XCTAssertEqual(snapshot.presentation(at: now).commitmentState, .pending)
        XCTAssertFalse(snapshot.presentation(at: now).isCommitted)
        snapshot.committedWeek = week
        XCTAssertTrue(snapshot.presentation(at: now).isCommitted)
        snapshot.committedWeek = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 7))
        XCTAssertFalse(snapshot.presentation(at: now).isCommitted)
        let empty = HomeSnapshot(tree: try ActivityTree.build(from: []), entries: [], budgets: [], capacities: [], settings: settings)
        XCTAssertEqual(empty.presentation(at: now).commitmentState, .unused)
    }
}

@MainActor
private final class Fixture {
    let now = ISO8601DateFormatter().date(from: "2026-09-16T12:00:00Z")!
    let week = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 14))
    let store: Week168Store
    let service: Week168Service
    let model: AllocationViewModel

    init() throws {
        // Keep each fixture's disposable store in its own temporary directory.
        // Intentionally leave it on disk: CoreData may still use it while the
        // model, service, and store are being released after the test finishes.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = Week168Store(container: try Week168Store.makeContainer(at: directory.appendingPathComponent("test.store")))
        service = Week168Service(store: store, clock: FixedClock(date: now), alarms: SilentAlarms())
        model = AllocationViewModel(store: store, service: service)
    }

    func activity(_ name: String, parent: ActivityID? = nil, mode: BudgetMode = .managed) async throws -> Activity {
        try await service.createActivity(name: name, parentID: parent, budgetMode: mode)
    }

    func budget(_ id: ActivityID, wish: Int, committed: Int) async throws {
        try await store.upsertBudget(BudgetEntry(activityID: id, effectiveFrom: week,
            direction: .goal, wishMinutes: wish, committedMinutes: committed))
    }
}

private struct FixedClock: Clock {
    let date: Date
    func now() -> Date { date }
}

private struct SilentAlarms: AlarmScheduling {
    func schedulePlannedTimeAlarm(entryID: EntryID, activityName: String, fireAt: Date) async {}
    func scheduleBudgetExhaustionNotice(activityID: ActivityID, activityName: String, fireAt: Date) async {}
    func cancelAll(for entryID: EntryID) async {}
}


extension AllocationViewModelTests {
    func testAccessibilityAllocationIncludesBothValuesOverflowAndParent() async throws {
        let f = try Fixture()
        let parent = try await f.activity("Parent")
        let child = try await f.activity("Child", parent: parent.id)
        try await f.budget(parent.id, wish: 60, committed: 60)
        try await f.budget(child.id, wish: 120, committed: 120)
        await f.model.refresh(at: f.now)
        let parentNode = try XCTUnwrap(f.model.node(parent.id))
        let parentValue = allocationRowValue(model: f.model, node: parentNode)
        XCTAssertTrue(parentValue.contains("希望 1:00"))
        XCTAssertTrue(parentValue.contains("確定 1:00"))
        XCTAssertTrue(parentValue.contains("超過 −1:00"))
        XCTAssertTrue(parentValue.contains("未確定"))
        let childNode = try XCTUnwrap(f.model.node(child.id))
        let childValue = allocationRowValue(model: f.model, node: childNode)
        XCTAssertTrue(childValue.contains("親の活動：Parent"))
        XCTAssertTrue(childValue.contains("希望 2:00"))
        XCTAssertTrue(childValue.contains("確定 2:00"))
    }
}
