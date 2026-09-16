import Foundation
import XCTest
import Week168Domain
@testable import Week168

final class AccessibilityPresentationTests: XCTestCase {
    private let id = ActivityID(rawValue: UUID())
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func summary(_ direction: BudgetDirection, actual: Int, budget: Int) -> ActivitySummary {
        ActivitySummary(activityID: id, ownMinutes: actual, totalMinutes: actual,
                        budgetMinutes: budget, direction: direction)
    }

    func testCapExceededIncludesWordAndExcessAmount() {
        let value = AccessibilityPresentation.status(summary(.cap, actual: 420, budget: 300), outside: false, pending: false)
        XCTAssertTrue(value.contains("超過"))
        XCTAssertTrue(value.contains("2:00"))
        XCTAssertFalse(value.contains("未達"))
    }

    func testGoalUnmetIncludesWordAndShortfallAmount() {
        let value = AccessibilityPresentation.status(summary(.goal, actual: 180, budget: 600), outside: false, pending: false)
        XCTAssertTrue(value.contains("未達"))
        XCTAssertTrue(value.contains("7:00"))
        XCTAssertFalse(value.contains("超過"))
    }

    func testOutsideSuppressesJudgmentEvenWhenWeekIsPending() {
        for pending in [false, true] {
            for direction in [BudgetDirection.cap, .goal] {
                let value = AccessibilityPresentation.status(summary(direction, actual: 180, budget: 60), outside: true, pending: pending)
                XCTAssertEqual(value, "枠外")
                XCTAssertFalse(value.contains("超過"))
                XCTAssertFalse(value.contains("未達"))
            }
        }
    }

    func testPendingHasNoRemainingOrActualJudgment() {
        let value = AccessibilityPresentation.status(summary(.cap, actual: 420, budget: 300), outside: false, pending: true)
        XCTAssertEqual(value, "未確定")
        XCTAssertFalse(value.contains("残り"))
        XCTAssertFalse(value.contains("超過"))
    }

    func testWithinBudgetShowsRemainingAndExactGoalIsNotUnmet() {
        XCTAssertEqual(AccessibilityPresentation.status(summary(.cap, actual: 60, budget: 180), outside: false, pending: false), "残り 2:00")
        XCTAssertEqual(AccessibilityPresentation.status(summary(.goal, actual: 180, budget: 180), outside: false, pending: false), "残り 0:00")
    }

    func testRunningReadingIncludesNameElapsedAndCommittedRemaining() throws {
        let snapshot = try runningSnapshot(committed: true)
        let running = try XCTUnwrap(snapshot.running)
        let label = AccessibilityPresentation.text("a11y.running", "English")
        let value = AccessibilityPresentation.runningValue(running, snapshot: snapshot, at: now)
        XCTAssertTrue(label.contains("English"))
        XCTAssertTrue(value.contains("今回の経過 00:03:00"))
        XCTAssertTrue(value.contains("残り 0:57"))
        XCTAssertTrue(value.contains("上限 1:00"))
        // A reading captured at one instant stays the same when evaluated again.
        XCTAssertEqual(value, AccessibilityPresentation.runningValue(running, snapshot: snapshot, at: now))
    }

    func testPendingRunningReadingOmitsWeeklyRemainingAndBudget() throws {
        let snapshot = try runningSnapshot(committed: false)
        let value = AccessibilityPresentation.runningValue(try XCTUnwrap(snapshot.running), snapshot: snapshot, at: now)
        XCTAssertTrue(value.contains("未確定"))
        XCTAssertTrue(value.contains("00:03:00"))
        XCTAssertFalse(value.contains("残り"))
        XCTAssertFalse(value.contains("上限"))
        XCTAssertFalse(value.contains("未達"))
    }

    func testReviewLabelsDistinguishOppositeJudgmentsAndOutside() throws {
        let activity = try XCTUnwrap(runningSnapshot(committed: true).tree.node(id))
        for (direction, actual, budget, expected) in [(BudgetDirection.cap, 420, 300, "上限を120分超過"), (.goal, 180, 600, "目標まで420分未達")] {
            let row = ReviewActivity(activity: activity, path: ["Study", activity.name], isOutside: false,
                ownMinutes: actual, totalMinutes: actual, committedMinutes: budget, wishMinutes: budget,
                direction: direction, isJudged: true)
            let value = AccessibilityPresentation.reviewValue(row, pending: false)
            XCTAssertTrue(value.contains(expected))
            XCTAssertTrue(value.contains("Study"))
            XCTAssertTrue(value.contains("実績"))
            XCTAssertTrue(value.contains("確定予算"))
        }
        let outside = ReviewActivity(activity: activity, path: [activity.name], isOutside: true,
            ownMinutes: 420, totalMinutes: 420, committedMinutes: nil, wishMinutes: nil, direction: nil, isJudged: false)
        let value = AccessibilityPresentation.reviewValue(outside, pending: true)
        XCTAssertTrue(value.contains("枠外"))
        XCTAssertFalse(value.contains("超過"))
        XCTAssertFalse(value.contains("未達"))
    }

    func testReviewPendingWithoutIndividualBudgetIsStillExplicit() throws {
        let activity = try XCTUnwrap(runningSnapshot(committed: false).tree.node(id))
        let row = ReviewActivity(activity: activity, path: [activity.name], isOutside: false,
            ownMinutes: 0, totalMinutes: 0, committedMinutes: nil, wishMinutes: nil, direction: nil, isJudged: false)
        let value = AccessibilityPresentation.reviewValue(row, pending: true)
        XCTAssertTrue(value.contains("未確定"))
        XCTAssertFalse(value.contains("残り"))
    }

    func testExcludedAncestorIsRecognizedWithoutChangingChildMode() throws {
        let parent = Activity(id: id, name: "Work", parentID: nil, sortOrder: 0, budgetMode: .excluded,
            defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
        let child = Activity(id: ActivityID(rawValue: UUID()), name: "Client", parentID: id, sortOrder: 0,
            budgetMode: .unset, defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
        let tree = try ActivityTree.build(from: [parent, child])
        XCTAssertTrue(AccessibilityPresentation.outside(child, tree: tree))
        XCTAssertEqual(child.budgetMode, .unset)
    }

    func testOutsideRunningActivityDoesNotInheritParentJudgment() throws {
        let base = try runningSnapshot(committed: true)
        let outsideID = ActivityID(rawValue: UUID())
        let outside = Activity(id: outsideID, name: "Outside", parentID: id, sortOrder: 0, budgetMode: .excluded,
            defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
        let parent = try XCTUnwrap(base.tree.node(id))
        let parentEntry = TimeEntry(id: EntryID(rawValue: UUID()), activityID: id,
            startedAt: now.addingTimeInterval(-9000), endedAt: now.addingTimeInterval(-1800), plannedMinutes: nil, note: "")
        let running = TimeEntry(id: EntryID(rawValue: UUID()), activityID: outsideID,
            startedAt: now.addingTimeInterval(-1800), endedAt: nil, plannedMinutes: nil, note: "")
        let snapshot = try HomeSnapshot(tree: ActivityTree.build(from: [parent, outside]), entries: [parentEntry, running],
            budgets: base.budgets, capacities: [], settings: base.settings, committedWeek: base.committedWeek)
        let value = AccessibilityPresentation.runningValue(running, snapshot: snapshot, at: now)
        XCTAssertTrue(value.contains("枠外"))
        XCTAssertFalse(value.contains("超過"))
        XCTAssertFalse(value.contains("未達"))
        XCTAssertFalse(value.contains("残り"))
    }

    private func runningSnapshot(committed: Bool) throws -> HomeSnapshot {
        let settings = CalendarSettings(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 4, weekStartWeekday: 2)
        let week = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: now, settings: settings), settings: settings)
        let activity = Activity(id: id, name: "English", parentID: nil, sortOrder: 0, budgetMode: .managed,
            defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
        let entry = TimeEntry(id: EntryID(rawValue: UUID()), activityID: id, startedAt: now.addingTimeInterval(-180),
            endedAt: nil, plannedMinutes: nil, note: "")
        return try HomeSnapshot(tree: ActivityTree.build(from: [activity]), entries: [entry],
            budgets: [BudgetEntry(activityID: id, effectiveFrom: week, direction: .cap, wishMinutes: 60, committedMinutes: 60)],
            capacities: [], settings: settings, committedWeek: committed ? week : nil)
    }
}
