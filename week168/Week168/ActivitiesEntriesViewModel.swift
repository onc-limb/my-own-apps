import Foundation
import Observation
import Week168Domain
import Week168Persistence
import Week168UseCases

struct ActivityDeletion: Identifiable, Equatable {
    var id: ActivityID { activity.id }
    let activity: Activity
    let children: Int
    let entries: Int
    var message: String {
        managementText("activities.deleteImpact", activity.name, children, entries)
    }
}

struct EntryDaySection: Identifiable {
    var id: LogicalDay { day }
    let day: LogicalDay
    let entries: [TimeEntry]
}

@MainActor @Observable
final class ActivitiesEntriesViewModel {
    private let store: Week168Store
    private let service: Week168Service
    private(set) var tree: ActivityTree?
    private(set) var entries: [TimeEntry] = []
    private(set) var settings: CalendarSettings?
    private(set) var isBusy = false
    var issue: String?
    var deletion: ActivityDeletion?

    init(store: Week168Store, service: Week168Service) {
        self.store = store
        self.service = service
    }

    var activities: [Activity] {
        guard let tree else { return [] }
        return tree.topLevel().flatMap { [$0.id] + tree.descendants(of: $0.id) }.compactMap { tree.node($0) }
    }

    var daySections: [EntryDaySection] {
        guard let settings else { return [] }
        // ASSUMPTION: A boundary-spanning entry appears once, under its starting logical day.
        let groups = Dictionary(grouping: entries) { TimeAxis.logicalDay(of: $0.startedAt, settings: settings) }
        return groups.keys.sorted(by: >).map { day in
            EntryDaySection(day: day, entries: groups[day, default: []].sorted {
                if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
                return $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
            })
        }
    }

    var timeZone: TimeZone { settings.flatMap { TimeZone(identifier: $0.timeZoneIdentifier) } ?? .current }

    func path(_ activity: Activity) -> String {
        let ancestors = tree?.ancestors(of: activity.id).reversed().compactMap { tree?.node($0)?.name } ?? []
        return (ancestors + [activity.name]).joined(separator: " › ")
    }

    func name(_ id: ActivityID) -> String {
        tree?.node(id)?.name ?? String(localized: "activities.missing")
    }

    func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func dayTitle(_ day: LogicalDay) -> String {
        guard let settings else { return "" }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .full
        return formatter.string(from: TimeAxis.interval(of: day, settings: settings).start)
    }

    private func load() async throws {
        // Let the service initialize the same persisted defaults used by Home.
        if try await store.loadSettings() == nil { _ = try await service.homeSections(recentLimit: 8) }
        let activities = try await store.loadActivities()
        let loadedEntries = try await store.loadEntries(overlapping: DateInterval(start: .distantPast, end: .distantFuture))
        guard let stored = try await store.loadSettings() else { throw ManagementError.missingSettings }
        let validated = try CalendarSettings.validated(timeZoneIdentifier: stored.timeZoneIdentifier,
            dayStartHour: stored.dayStartHour, weekStartWeekday: stored.weekStartWeekday)
        tree = try ActivityTree.build(from: activities)
        entries = loadedEntries
        settings = validated
    }

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        issue = nil
        do { try await load() }
        catch { issue = errorMessage(error) }
    }

    func activityValidation(name: String, parent: ActivityID?, mode: BudgetMode,
                            minutes: String, editing: ActivityID?) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "activities.error.name")
        }
        if !minutes.isEmpty && (Int(minutes).map { $0 > 0 && $0 <= Int.max / 60 } != true) {
            return String(localized: "activities.error.minutes")
        }
        if let parent, tree?.node(parent) == nil { return String(localized: "activities.error.parentMissing") }
        if mode == .managed, let parent {
            let ancestry = [parent] + (tree?.ancestors(of: parent) ?? [])
            if ancestry.contains(where: { tree?.node($0)?.budgetMode == .excluded }) {
                return String(localized: "activities.error.excludedAncestor")
            }
        }
        if mode == .excluded, let editing,
           tree?.descendants(of: editing).contains(where: { tree?.node($0)?.budgetMode == .managed }) == true {
            return String(localized: "activities.error.managedDescendant")
        }
        return nil
    }

    func saveActivity(original: Activity?, name: String, parent: ActivityID?, mode: BudgetMode,
                      minutes: String, color: String) async -> Bool {
        await perform {
            try await self.load()
            let current = original.flatMap { self.tree?.node($0.id) }
            if original != nil && current == nil { throw ManagementError.activityMissing }
            // Keep parent, archive status, and sibling order from the latest stored version on edit.
            let savedParent = current?.parentID ?? (original == nil ? parent : nil)
            if let reason = self.activityValidation(name: name, parent: savedParent, mode: mode,
                                                     minutes: minutes, editing: original?.id) {
                throw ManagementError.validation(reason)
            }
            if var activity = current {
                activity.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                activity.budgetMode = mode
                activity.defaultPlannedMinutes = Int(minutes)
                activity.colorHex = color
                try await self.service.updateActivity(activity)
            } else {
                // ASSUMPTION: New activities are appended to their siblings, including archived siblings.
                let maximum = self.tree?.children(of: savedParent).map(\.sortOrder).max() ?? -1
                _ = try await self.service.createActivity(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    parentID: savedParent, sortOrder: maximum == Int.max ? maximum : maximum + 1,
                    budgetMode: mode, defaultPlannedMinutes: Int(minutes), colorHex: color)
            }
        }
    }

    func archive(_ activity: Activity) async {
        _ = await perform { try await self.service.archiveActivity(activity.id, archived: !activity.isArchived) }
    }

    func canMove(_ activity: Activity, offset: Int) -> Bool {
        let siblings = tree?.children(of: activity.parentID) ?? []
        guard let index = siblings.firstIndex(where: { $0.id == activity.id }) else { return false }
        return siblings.indices.contains(index + offset)
    }

    func move(_ activity: Activity, offset: Int) async {
        // ASSUMPTION: Accessible up/down actions reorder siblings without changing parents.
        _ = await perform {
            try await self.load()
            guard let current = self.tree?.node(activity.id) else { throw ManagementError.activityMissing }
            var siblings = self.tree?.children(of: current.parentID).map(\.id) ?? []
            guard let index = siblings.firstIndex(of: activity.id), siblings.indices.contains(index + offset) else { return }
            siblings.swapAt(index, index + offset)
            try await self.service.reorderActivities(siblings, under: current.parentID)
        }
    }

    private func impact(_ id: ActivityID) -> ActivityDeletion? {
        guard let activity = tree?.node(id), let children = tree?.descendants(of: id) else { return nil }
        let ids = Set(children + [id])
        return ActivityDeletion(activity: activity, children: children.count,
                                entries: entries.filter { ids.contains($0.activityID) }.count)
    }

    func prepareDeletion(_ activity: Activity) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        issue = nil
        do {
            try await load()
            guard let preview = impact(activity.id) else { throw ManagementError.activityMissing }
            deletion = preview
        } catch { issue = errorMessage(error) }
    }

    func deleteActivity(_ preview: ActivityDeletion) async {
        _ = await perform {
            try await self.load()
            guard let fresh = self.impact(preview.id) else { throw ManagementError.activityMissing }
            guard fresh == preview else {
                self.deletion = fresh
                throw ManagementError.validation(String(localized: "activities.error.impactChanged"))
            }
            _ = try await self.service.deleteActivity(preview.id)
            self.deletion = nil
        }
    }

    func saveEntry(original: TimeEntry?, activity: ActivityID?, start: Date, end: Date?, note: String) async -> Bool {
        await perform {
            guard let activity else { throw ManagementError.validation(String(localized: "entries.error.activity")) }
            try await self.load()
            if let original {
                guard var current = self.entries.first(where: { $0.id == original.id }) else {
                    throw ManagementError.validation(String(localized: "entries.error.missing"))
                }
                current.activityID = activity
                current.startedAt = start
                current.endedAt = end
                current.note = note
                try await self.service.updateEntry(current)
            } else {
                guard let end else { throw ManagementError.validation(String(localized: "entries.error.endRequired")) }
                try await self.service.addEntry(activityID: activity, startedAt: start, endedAt: end, note: note)
            }
        }
    }

    func deleteEntry(_ entry: TimeEntry) async {
        _ = await perform { try await self.service.deleteEntry(entry.id) }
    }

    private func perform(_ operation: () async throws -> Void) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        issue = nil
        var succeeded = false
        do { try await operation(); succeeded = true }
        catch {
            // Refresh conflict details even when the store rejected against newer entries.
            let originalError = error
            try? await load()
            issue = errorMessage(originalError)
        }
        do { try await load() }
        catch {
            let reload = managementText("management.error.reload", error.localizedDescription)
            issue = [issue, reload].compactMap { $0 }.joined(separator: "\n")
        }
        // A successful mutation stays successful even if refreshing its presentation fails.
        // Close the editor to prevent a second creation; keep the load error on the list.
        return succeeded
    }

    func errorMessage(_ error: Error) -> String {
        if let error = error as? EntryValidationError {
            switch error {
            case .inFuture: return String(localized: "entries.error.future")
            case .endBeforeStart: return String(localized: "entries.error.order")
            case .zeroLength: return String(localized: "entries.error.zero")
            case .overlaps(let ids): return conflictMessage(ids)
            case .anotherEntryRunning(let id): return conflictMessage([id])
            }
        }
        if let error = error as? ManagementError {
            switch error {
            case .validation(let message): return message
            case .activityMissing: return String(localized: "activities.missing")
            case .missingSettings: return String(localized: "management.error.settings")
            }
        }
        if let error = error as? ActivityTree.BuildError {
            switch error {
            case .budgetUnderExcluded: return String(localized: "activities.error.excludedAncestor")
            default: return String(localized: "activities.error.hierarchy")
            }
        }
        if let error = error as? Week168ServiceError {
            switch error {
            case .activityNotFound: return String(localized: "activities.missing")
            case .invalidMinutes: return String(localized: "activities.error.minutes")
            case .invalidOrder: return String(localized: "activities.error.order")
            default: break
            }
        }
        return managementText("management.error.storage", error.localizedDescription)
    }

    private func conflictMessage(_ ids: [EntryID]) -> String {
        ids.map { id in
            guard let other = entries.first(where: { $0.id == id }) else {
                return managementText("entries.error.conflictMissing", id.rawValue.uuidString)
            }
            let end = other.endedAt.map(timestamp) ?? String(localized: "entries.running")
            return managementText("entries.error.overlap", timestamp(other.startedAt), end, name(other.activityID))
        }.joined(separator: "\n")
    }

    private enum ManagementError: Error {
        case missingSettings, activityMissing, validation(String)
    }
}

func managementText(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: String(localized: String.LocalizationValue(key)), locale: Locale.current, arguments: arguments)
}
