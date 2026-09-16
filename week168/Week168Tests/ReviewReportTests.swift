import Foundation
import XCTest
import Week168Domain
import Week168Persistence
@testable import Week168

final class ReviewReportTests: XCTestCase {
    private let settings = CalendarSettings(timeZoneIdentifier: "Asia/Tokyo", dayStartHour: 4, weekStartWeekday: 2)
    private let now = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")!

    private func fixture() -> StoreBackup {
        let root = Activity(id: ActivityID(rawValue: UUID()), name: "Goal", parentID: nil, sortOrder: 0,
            budgetMode: .managed, defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
        let child = Activity(id: ActivityID(rawValue: UUID()), name: "Shared", parentID: root.id, sortOrder: 0,
            budgetMode: .unset, defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
        let outside = Activity(id: ActivityID(rawValue: UUID()), name: "Outside", parentID: nil, sortOrder: 1,
            budgetMode: .excluded, defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
        let weeks = TimeAxis.weeks(inYear: 2026, month: 9, settings: settings)
        let budgets = [BudgetEntry(activityID: root.id, effectiveFrom: weeks[0], direction: .goal,
                                   wishMinutes: 120, committedMinutes: 120),
                       BudgetEntry(activityID: root.id, effectiveFrom: weeks[2], direction: .goal,
                                   wishMinutes: 240, committedMinutes: 240)]
        let entries = weeks.flatMap { week -> [TimeEntry] in
            let start = TimeAxis.interval(of: week, settings: settings).start
            return [TimeEntry(id: EntryID(rawValue: UUID()), activityID: child.id, startedAt: start,
                              endedAt: start.addingTimeInterval(3600), plannedMinutes: nil, note: ""),
                    TimeEntry(id: EntryID(rawValue: UUID()), activityID: outside.id, startedAt: start.addingTimeInterval(3600),
                              endedAt: start.addingTimeInterval(5400), plannedMinutes: nil, note: "")]
        }
        return StoreBackup(settings: settings, activities: [root, child, outside], budgets: budgets, capacities: [],
            entries: entries, commitments: weeks.map { CommitmentRecord(week: $0, committedAt: now) })
    }
    private func snapshot(_ backup: StoreBackup) -> ReviewSnapshot {
        ReviewSnapshot(settings: backup.settings, activities: backup.activities, budgets: backup.budgets,
                       capacities: backup.capacities, entries: backup.entries)
    }

    func testMonthSumsHistoricalWeeklyBudgetsAndActuals() throws {
        let backup = fixture()
        let weeks = TimeAxis.weeks(inYear: 2026, month: 9, settings: settings)
        XCTAssertEqual(weeks.count, 4)
        let reports = try weeks.map { try snapshot(backup).report(week: $0, hasCommitment: true, now: now) }
        XCTAssertEqual(reports.map { $0.activities[0].committedMinutes }, [120, 120, 240, 240])
        let monthly = try ReviewSnapshot.combine(reports)
        XCTAssertEqual(monthly[0].committedMinutes, 720)
        XCTAssertEqual(monthly[0].totalMinutes, 240)
        XCTAssertEqual(monthly[0].ownMinutes, 0)
        XCTAssertEqual(monthly[0].status, "unmet")
        XCTAssertEqual(monthly[0].deviationMinutes, 480)
        XCTAssertFalse(monthly[1].isOutside)
        XCTAssertNil(monthly[1].committedMinutes)
        XCTAssertTrue(monthly[2].isOutside)
        XCTAssertNil(monthly[2].committedMinutes)
        XCTAssertEqual(monthly[2].status, "not_judged")
    }

    func testNewCurrentBudgetDoesNotChangePastWeekAndPendingIsNotJudged() throws {
        let backup = fixture()
        let week = backup.commitments[0].week
        let old = try snapshot(backup).report(week: week, hasCommitment: true, now: now)
        let later = BudgetEntry(activityID: backup.activities[0].id,
            effectiveFrom: LogicalWeek(startDay: LogicalDay(year: 2026, month: 10, day: 12)),
            direction: .cap, wishMinutes: 999, committedMinutes: 999)
        let changed = ReviewSnapshot(settings: settings, activities: backup.activities, budgets: backup.budgets + [later],
            capacities: [], entries: backup.entries)
        let result = try changed.report(week: week, hasCommitment: true, now: now)
        XCTAssertEqual(result.activities[0].committedMinutes, old.activities[0].committedMinutes)
        XCTAssertEqual(result.activities[0].status, old.activities[0].status)
        let pending = try changed.report(week: week, hasCommitment: false, now: now)
        XCTAssertEqual(pending.activities[0].status, "not_judged")
        XCTAssertEqual(pending.activities[0].deviationMinutes, 0)
    }

    func testExportClipsLogicalBoundaryKeepsRawAndRecomputesMonthByWeek() throws {
        let base = fixture()
        let week = base.commitments[0].week
        let boundary = TimeAxis.interval(of: week, settings: settings).start
        let entry = TimeEntry(id: EntryID(rawValue: UUID()), activityID: base.activities[0].id,
            startedAt: boundary.addingTimeInterval(-1800), endedAt: boundary.addingTimeInterval(1800),
            plannedMinutes: nil, note: "Crosses 04:00 JST")
        let backup = StoreBackup(settings: settings, activities: base.activities, budgets: base.budgets,
            capacities: [], entries: [entry], commitments: base.commitments)
        let bytes = try ReviewExport.encode(backup: backup, from: week.startDay, to: week.startDay, now: now)
        let decoded = try BackupJSON.decode(bytes, now: now)
        XCTAssertEqual(decoded, backup)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let summary = try XCTUnwrap(root["summary"] as? [String: Any])
        let weeks = try XCTUnwrap(summary["weeks"] as? [[String: Any]])
        let activities = try XCTUnwrap(weeks[0]["activities"] as? [[String: Any]])
        XCTAssertEqual(activities[0]["totalMinutes"] as? Int, 30)
        let months = try XCTUnwrap(summary["months"] as? [[String: Any]])
        XCTAssertEqual(months[0]["weekCount"] as? Int, 4)
        let monthly = try XCTUnwrap(months[0]["activities"] as? [[String: Any]])
        XCTAssertEqual(monthly[0]["committedMinutes"] as? Int, 720)
    }

    func testExportImportPreservesCommittedWeekReportAndIgnoresSummary() throws {
        let backup = fixture()
        let bytes = try ReviewExport.encode(backup: backup, from: nil, to: nil, now: now)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        root["summary"] = ["corrupt": true]
        let restored = try BackupJSON.decode(JSONSerialization.data(withJSONObject: root), now: now)
        for commitment in backup.commitments {
            let before = try snapshot(backup).report(week: commitment.week, hasCommitment: true, now: now)
            let after = try snapshot(restored).report(week: commitment.week,
                hasCommitment: restored.commitments.contains { $0.week == commitment.week }, now: now)
            XCTAssertTrue(after.isCommitted)
            XCTAssertEqual(after.activities.map(\.totalMinutes), before.activities.map(\.totalMinutes))
            XCTAssertEqual(after.activities.map(\.status), before.activities.map(\.status))
        }
    }
}
