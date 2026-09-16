import Foundation
import CoreFoundation
import Week168Domain

/// Version 1 interchange codec. Import never reads or trusts `summary`.
public enum BackupJSON {
    public static func decode(_ bytes: Data, now: Date) throws -> StoreBackup {
        let root = try object(JSONSerialization.jsonObject(with: bytes))
        guard try integer(root, "schemaVersion") == 1 else { throw BackupError.unsupportedVersion }
        let app = try object(required(root, "app"))
        for key in ["name", "version", "build"] { _ = try string(app, key) }
        _ = try instant(string(root, "exportedAt"))
        let period = try object(required(root, "period"))
        let from = try parseDay(string(period, "from")), to = try parseDay(string(period, "to"))
        guard from <= to else { throw BackupError.invalidData }
        let data = try object(required(root, "data"))
        let config = try object(required(data, "settings"))
        // Must precede any TimeAxis use: malformed timezone identifiers must throw, never trap.
        let settings = try CalendarSettings.validated(timeZoneIdentifier: string(config, "timeZone"),
            dayStartHour: integer(config, "dayStartHour"), weekStartWeekday: integer(config, "weekStartWeekday"))
        let activities = try array(data, "activities").map { row in
            let mode = try string(row, "budgetMode")
            guard ["cap", "goal", "unset", "excluded"].contains(mode) else { throw BackupError.invalidData }
            return try Activity(id: ActivityID(rawValue: uuid(row, "id")), name: string(row, "name"),
                parentID: optionalUUID(row, "parentId").map { ActivityID(rawValue: $0) },
                sortOrder: integer(row, "sortOrder"), budgetMode: mode == "unset" ? .unset : mode == "excluded" ? .excluded : .managed,
                defaultPlannedMinutes: optionalInteger(row, "defaultPlannedMinutes"), colorHex: string(row, "colorHex"),
                isArchived: boolean(row, "isArchived"))
        }
        let budgets = try array(data, "budgets").map { row in
            guard let direction = try BudgetDirection(rawValue: string(row, "direction")) else { throw BackupError.invalidData }
            return try BudgetEntry(activityID: ActivityID(rawValue: uuid(row, "activityId")),
                effectiveFrom: LogicalWeek(startDay: parseDay(string(row, "effectiveFrom"))), direction: direction,
                wishMinutes: integer(row, "wishMinutes"), committedMinutes: optionalInteger(row, "committedMinutes"))
        }
        let capacities = try array(data, "capacities").map { row in
            try CapacityEntry(effectiveFrom: LogicalWeek(startDay: parseDay(string(row, "effectiveFrom"))),
                              totalMinutes: optionalInteger(row, "totalMinutes"))
        }
        let entries = try array(data, "entries").map { row in
            try TimeEntry(id: EntryID(rawValue: uuid(row, "id")), activityID: ActivityID(rawValue: uuid(row, "activityId")),
                startedAt: instant(string(row, "startedAt")), endedAt: optionalString(row, "endedAt").map { try instant($0) },
                plannedMinutes: optionalInteger(row, "plannedMinutes"), note: string(row, "note"))
        }
        let commitments = try array(data, "commitments").map { row in
            try CommitmentRecord(week: LogicalWeek(startDay: parseDay(string(row, "week"))),
                                 committedAt: instant(string(row, "committedAt")))
        }
        let backup = StoreBackup(settings: settings, activities: activities, budgets: budgets,
            capacities: capacities, entries: entries, commitments: commitments)
        try backup.validate(now: now)
        return backup
    }

    public static func rawObject(_ backup: StoreBackup) -> [String: Any] {
        let settings = backup.settings
        return [
            "settings": ["timeZone": settings.timeZoneIdentifier, "dayStartHour": settings.dayStartHour,
                         "weekStartWeekday": settings.weekStartWeekday],
            "activities": backup.activities.map { activity -> [String: Any] in
                // ASSUMPTION: Activity stores managed/unset/excluded; cap/goal lives in budget history.
                // Use its latest direction for the wire label; restore still resolves historical directions per week.
                let latest = backup.budgets.filter { $0.activityID == activity.id }.max { $0.effectiveFrom < $1.effectiveFrom }
                let mode = activity.budgetMode == .managed ? (latest?.direction.rawValue ?? "cap")
                    : activity.budgetMode == .excluded ? "excluded" : "unset"
                return ["id": activity.id.rawValue.uuidString, "name": activity.name,
                        "parentId": nullable(activity.parentID?.rawValue.uuidString), "sortOrder": activity.sortOrder,
                        "budgetMode": mode, "defaultPlannedMinutes": nullable(activity.defaultPlannedMinutes),
                        "colorHex": activity.colorHex, "isArchived": activity.isArchived]
            },
            "budgets": backup.budgets.map { ["activityId": $0.activityID.rawValue.uuidString,
                "effectiveFrom": day($0.effectiveFrom.startDay), "direction": $0.direction.rawValue,
                "wishMinutes": $0.wishMinutes, "committedMinutes": nullable($0.committedMinutes)] as [String: Any] },
            "capacities": backup.capacities.map { ["effectiveFrom": day($0.effectiveFrom.startDay),
                "totalMinutes": nullable($0.totalMinutes)] as [String: Any] },
            "entries": backup.entries.map { ["id": $0.id.rawValue.uuidString, "activityId": $0.activityID.rawValue.uuidString,
                "startedAt": timestamp($0.startedAt), "endedAt": nullable($0.endedAt.map(timestamp)),
                "plannedMinutes": nullable($0.plannedMinutes), "note": $0.note] as [String: Any] },
            "commitments": backup.commitments.map { ["week": day($0.week.startDay), "committedAt": timestamp($0.committedAt)] }
        ]
    }

    public static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        // ISO8601DateFormatter truncates to milliseconds. Preserve Date's submillisecond
        // precision so a record near a minute boundary has identical aggregates after restore.
        let seconds = date.timeIntervalSinceReferenceDate
        var whole = floor(seconds)
        var nanos = Int(((seconds - whole) * 1_000_000_000).rounded())
        if nanos == 1_000_000_000 { whole += 1; nanos = 0 }
        let base = formatter.string(from: Date(timeIntervalSinceReferenceDate: whole))
        return String(base.dropLast()) + String(format: ".%09dZ", nanos)
    }
    public static func day(_ day: LogicalDay) -> String { String(format: "%04d-%02d-%02d", day.year, day.month, day.day) }

    public static func parseDay(_ text: String) throws -> LogicalDay {
        guard text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { throw BackupError.invalidData }
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (2...9998).contains(parts[0]), (1...12).contains(parts[1]), (1...31).contains(parts[2])
        else { throw BackupError.invalidData }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components), calendar.dateComponents([.year, .month, .day], from: date) == components
        else { throw BackupError.invalidData }
        return LogicalDay(year: parts[0], month: parts[1], day: parts[2])
    }

    private static func instant(_ text: String) throws -> Date {
        let pattern = #"^(\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d)(?:\.(\d{1,18}))?(Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$"#
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let baseRange = Range(match.range(at: 1), in: text),
              let zoneRange = Range(match.range(at: 3), in: text) else { throw BackupError.invalidData }
        _ = try parseDay(String(text.prefix(10)))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let base = formatter.date(from: String(text[baseRange]) + String(text[zoneRange])) else { throw BackupError.invalidData }
        let fraction: Double
        if let range = Range(match.range(at: 2), in: text) {
            guard let value = Double("0." + text[range]) else { throw BackupError.invalidData }
            fraction = value
        } else { fraction = 0 }
        return base.addingTimeInterval(fraction)
    }
    private static func nullable<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() }
    private static func required(_ row: [String: Any], _ key: String) throws -> Any {
        guard let value = row[key] else { throw BackupError.invalidData }; return value
    }
    private static func object(_ value: Any) throws -> [String: Any] {
        guard let row = value as? [String: Any] else { throw BackupError.invalidData }; return row
    }
    private static func array(_ row: [String: Any], _ key: String) throws -> [[String: Any]] {
        guard let rows = try required(row, key) as? [[String: Any]] else { throw BackupError.invalidData }; return rows
    }
    private static func string(_ row: [String: Any], _ key: String) throws -> String {
        guard let text = try required(row, key) as? String else { throw BackupError.invalidData }; return text
    }
    private static func optionalString(_ row: [String: Any], _ key: String) throws -> String? {
        if try required(row, key) is NSNull { return nil }; return try string(row, key)
    }
    private static func integer(_ row: [String: Any], _ key: String) throws -> Int {
        guard let number = try required(row, key) as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              let value = Int(number.stringValue) else { throw BackupError.invalidData }; return value
    }
    private static func optionalInteger(_ row: [String: Any], _ key: String) throws -> Int? {
        if try required(row, key) is NSNull { return nil }; return try integer(row, key)
    }
    private static func boolean(_ row: [String: Any], _ key: String) throws -> Bool {
        guard let number = try required(row, key) as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID()
        else { throw BackupError.invalidData }; return number.boolValue
    }
    private static func uuid(_ row: [String: Any], _ key: String) throws -> UUID {
        guard let id = try UUID(uuidString: string(row, key)) else { throw BackupError.invalidData }; return id
    }
    private static func optionalUUID(_ row: [String: Any], _ key: String) throws -> UUID? {
        if try required(row, key) is NSNull { return nil }; return try uuid(row, key)
    }
}
