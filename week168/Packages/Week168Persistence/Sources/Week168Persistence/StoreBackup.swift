import Foundation
import Week168Domain

public enum BackupError: Error, Sendable {
    case invalidData
    case unsupportedVersion
    case staleConfirmation
}

/// Raw restore state. The JSON summary is deliberately not part of this type.
public struct StoreBackup: Sendable, Equatable {
    public let settings: CalendarSettings
    public let activities: [Activity]
    public let budgets: [BudgetEntry]
    public let capacities: [CapacityEntry]
    public let entries: [TimeEntry]
    public let commitments: [CommitmentRecord]

    public init(settings: CalendarSettings, activities: [Activity], budgets: [BudgetEntry],
                capacities: [CapacityEntry], entries: [TimeEntry], commitments: [CommitmentRecord]) {
        self.settings = settings; self.activities = activities; self.budgets = budgets
        self.capacities = capacities; self.entries = entries; self.commitments = commitments
    }

    public func validate(now: Date) throws {
        _ = try CalendarSettings.validated(timeZoneIdentifier: settings.timeZoneIdentifier,
            dayStartHour: settings.dayStartHour, weekStartWeekday: settings.weekStartWeekday)
        let tree = try ActivityTree.build(from: activities)
        var entryIDs = Set<EntryID>()
        var budgetKeys = Set<String>()
        var capacityWeeks = Set<LogicalWeek>()
        var commitmentWeeks = Set<LogicalWeek>()
        for activity in activities {
            guard !activity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw BackupError.invalidData }
            try Self.minutes(activity.defaultPlannedMinutes, positive: true)
        }
        // Reserve arithmetic headroom for monthly sums and all hierarchy roll-ups.
        var numericTotal = 0
        for budget in budgets {
            guard tree.node(budget.activityID) != nil,
                  budgetKeys.insert(budget.activityID.rawValue.uuidString + BackupJSON.day(budget.effectiveFrom.startDay)).inserted
            else { throw BackupError.invalidData }
            try Self.week(budget.effectiveFrom)
            for value in [budget.wishMinutes, budget.committedMinutes ?? 0] {
                try Self.minutes(value)
                let next = numericTotal.addingReportingOverflow(value)
                guard !next.overflow, next.partialValue <= Int.max / 64 else { throw BackupError.invalidData }
                numericTotal = next.partialValue
            }
        }
        for capacity in capacities {
            try Self.week(capacity.effectiveFrom)
            try Self.minutes(capacity.totalMinutes)
            guard capacityWeeks.insert(capacity.effectiveFrom).inserted else { throw BackupError.invalidData }
        }
        for record in commitments {
            try Self.week(record.week)
            try Self.instant(record.committedAt)
            guard commitmentWeeks.insert(record.week).inserted else { throw BackupError.invalidData }
        }
        var previous: TimeEntry?
        var runningCount = 0
        for entry in entries.sorted(by: { $0.startedAt < $1.startedAt }) {
            guard entryIDs.insert(entry.id).inserted, tree.node(entry.activityID) != nil else { throw BackupError.invalidData }
            try Self.instant(entry.startedAt)
            if let end = entry.endedAt { try Self.instant(end) }
            try Self.minutes(entry.plannedMinutes, positive: true)
            if entry.endedAt == nil { runningCount += 1 }
            guard runningCount <= 1 else { throw BackupError.invalidData }
            try EntryValidator.validate(entry, against: previous.map { [$0] } ?? [], now: now)
            previous = entry
        }
    }

    private static func minutes(_ value: Int?, positive: Bool = false) throws {
        if let value, value < (positive ? 1 : 0) || value > Int.max / 64 { throw BackupError.invalidData }
    }
    private static func week(_ value: LogicalWeek) throws {
        _ = try BackupJSON.parseDay(BackupJSON.day(value.startDay))
    }
    private static func instant(_ value: Date) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard value.timeIntervalSince1970.isFinite,
              (2...9998).contains(calendar.component(.year, from: value)) else { throw BackupError.invalidData }
    }
}
