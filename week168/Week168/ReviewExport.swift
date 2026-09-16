import Foundation
import Week168Domain
import Week168Persistence

/// The same week-by-week calculations power the Review UI and the exported report.
enum ReviewExport {
    static func encode(backup: StoreBackup, from: LogicalDay?, to: LogicalDay?, now: Date) throws -> Data {
        try backup.validate(now: now)
        let settings = backup.settings
        let snapshot = ReviewSnapshot(settings: settings, activities: backup.activities, budgets: backup.budgets,
            capacities: backup.capacities, entries: backup.entries)
        let today = TimeAxis.logicalDay(of: now, settings: settings)
        var days = backup.entries.flatMap { [TimeAxis.logicalDay(of: $0.startedAt, settings: settings),
            TimeAxis.logicalDay(of: ($0.endedAt ?? now).addingTimeInterval(-0.001), settings: settings)] }
        days += backup.budgets.map { $0.effectiveFrom.startDay }
        days += backup.capacities.map { $0.effectiveFrom.startDay }
        days += backup.commitments.map { $0.week.startDay }
        let first = from ?? days.min() ?? today
        let last = to ?? max(days.max() ?? today, today)
        guard first <= last else { throw ReviewError.invalidPeriod }
        let clip = DateInterval(start: TimeAxis.interval(of: first, settings: settings).start,
                                end: TimeAxis.interval(of: last, settings: settings).end)
        let committed = Set(backup.commitments.map(\.week))
        var weeks: [ReviewWeek] = []
        var week = TimeAxis.logicalWeek(of: first, settings: settings)
        while week.startDay <= last {
            weeks.append(try snapshot.report(week: week, hasCommitment: committed.contains(week), now: now, clipping: clip))
            let end = TimeAxis.interval(of: week, settings: settings).end
            week = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: end, settings: settings), settings: settings)
        }
        let weekObjects: [[String: Any]] = weeks.map { report in
            let end = TimeAxis.interval(of: report.week, settings: settings).end.addingTimeInterval(-0.001)
            return ["start": reviewDay(report.week.startDay), "end": reviewDay(TimeAxis.logicalDay(of: end, settings: settings)),
                "capacityMinutes": report.capacityMinutes.map { $0 as Any } ?? NSNull(),
                "committedTotalMinutes": report.committedTotalMinutes, "wishTotalMinutes": report.wishTotalMinutes,
                "isCommitted": report.isCommitted, "activities": report.activities.map(activityObject)]
        }
        // D-082: A month owns only weeks whose start label lies in that month.
        let groups = Dictionary(grouping: weeks) { $0.week.startDay.year * 100 + $0.week.startDay.month }
        let months: [[String: Any]] = try groups.keys.sorted().map { key in
            let reports = try TimeAxis.weeks(inYear: key / 100, month: key % 100, settings: settings).map { week in
                try snapshot.report(week: week, hasCommitment: committed.contains(week), now: now, clipping: clip)
            }
            return ["year": key / 100, "month": key % 100, "weekCount": reports.count,
                    "activities": try ReviewSnapshot.combine(reports).map(activityObject)]
        }
        // ASSUMPTION: A selected period limits summary only. Always include all raw data so
        // a full-replacement restore cannot silently discard records outside the report period.
        let root: [String: Any] = ["schemaVersion": 1,
            "app": ["name": "Week168", "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"],
            "exportedAt": BackupJSON.timestamp(now), "period": ["from": reviewDay(first), "to": reviewDay(last)],
            "summary": ["weeks": weekObjects, "months": months], "data": BackupJSON.rawObject(backup)]
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private static func activityObject(_ row: ReviewActivity) -> [String: Any] {
        let mode = row.activity.budgetMode == .managed ? (row.direction?.rawValue ?? "unset")
            : row.activity.budgetMode == .excluded ? "excluded" : "unset"
        return ["activityId": row.id.rawValue.uuidString, "name": row.activity.name, "path": row.path,
            "budgetMode": mode, "committedMinutes": row.committedMinutes.map { $0 as Any } ?? NSNull(),
            "wishMinutes": row.wishMinutes.map { $0 as Any } ?? NSNull(), "ownMinutes": row.ownMinutes,
            "totalMinutes": row.totalMinutes, "status": row.status, "deviationMinutes": row.deviationMinutes]
    }
}
