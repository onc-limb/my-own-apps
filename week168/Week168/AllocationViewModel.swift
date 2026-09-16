import Foundation
import Observation
import Week168Domain
import Week168Persistence
import Week168UseCases

@MainActor @Observable
final class AllocationViewModel {
    private let store: Week168Store
    private let service: Week168Service
    private(set) var tree: ActivityTree?
    private(set) var week: LogicalWeek?
    private(set) var settings: CalendarSettings?
    private(set) var report: AllocationReport?
    private(set) var state: CommitmentState = .unused
    private(set) var isBusy = false
    private(set) var isPreviewing = false
    private(set) var issueKey: String?
    private(set) var affectedChildren: [ActivityID: [ActivityID]] = [:]
    private var drafts: [LogicalWeek: [ActivityID: String]] = [:]
    private var revision = 0

    init(store: Week168Store, service: Week168Service) {
        self.store = store
        self.service = service
    }

    var nodes: [AllocationNode] {
        report?.nodes.filter { node in
            guard node.mode != .excluded else { return false }
            var parent = tree?.node(node.activityID)?.parentID
            while let id = parent {
                if tree?.node(id)?.budgetMode == .excluded { return false }
                parent = tree?.node(id)?.parentID
            }
            return true
        } ?? []
    }
    var hasDraft: Bool { week.map { !(drafts[$0] ?? [:]).isEmpty } ?? false }
    var isCommitted: Bool { state == .committed && !hasDraft }
    var invalidIDs: [ActivityID] {
        guard let week else { return [] }
        return (drafts[week] ?? [:]).compactMap { id, text in
            Self.validInput(text) ? nil : id
        }
    }
    var canCommit: Bool {
        !isBusy && !isPreviewing && issueKey == nil && invalidIDs.isEmpty &&
        report?.canCommit == true && state != .unused
    }

    static func validInput(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || Int(value).map { $0 >= 0 } == true
    }

    func node(_ id: ActivityID) -> AllocationNode? { nodes.first { $0.activityID == id } }
    func name(_ id: ActivityID) -> String { tree?.node(id)?.name ?? String(localized: "activity.unknown") }
    func input(_ id: ActivityID) -> String {
        if let week, let text = drafts[week]?[id] { return text }
        return node(id)?.committedMinutes.map(String.init) ?? ""
    }
    func children(_ id: ActivityID) -> [ActivityID] {
        tree?.children(of: id).filter { $0.budgetMode == .managed }.map(\.id) ?? []
    }
    func hasSharedChildren(_ id: ActivityID) -> Bool {
        tree?.children(of: id).contains { $0.budgetMode == .unset } == true
    }
    func descendants(_ id: ActivityID) -> [ActivityID] {
        tree?.descendants(of: id).filter { node($0) != nil } ?? []
    }

    private func proposals() -> [ActivityID: Int?] {
        guard let week else { return [:] }
        var result: [ActivityID: Int?] = [:]
        for (id, text) in drafts[week] ?? [:] where Self.validInput(text) {
            // updateValue preserves an explicit nil (clear); subscript assignment would remove the key.
            result.updateValue(Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), forKey: id)
        }
        return result
    }

    func setDraft(_ text: String, for id: ActivityID) {
        guard !isBusy, let week else { return }
        drafts[week, default: [:]][id] = text
        revision += 1
        isPreviewing = true
        let requestedRevision = revision
        Task {
            guard requestedRevision == revision, !isBusy else { return }
            await validateDraft(parent: id)
        }
    }

    func validateDraft(parent: ActivityID? = nil) async {
        guard let week else { return }
        let token = revision
        let values = proposals()
        isPreviewing = true
        // Guard machine-integer arithmetic before entering the package's non-throwing validator.
        if let report, !Self.canSum(report.nodes.filter { $0.mode == .managed }.map {
            if let proposed = values[$0.activityID] { return proposed ?? 0 }
            return $0.committedMinutes ?? 0
        }) {
            issueKey = "allocation.error.numericRange"
            isPreviewing = false
            return
        }
        do {
            if let parent, Self.validInput(input(parent)) {
                let reduction = try await service.requiredReductionForParent(parent,
                    newCommitted: Int(input(parent).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0, week: week)
                guard token == revision, self.week == week else { return }
                affectedChildren[parent] = reduction.children
            }
            let result = try await service.previewAllocation(week: week, committed: values)
            guard token == revision, self.week == week else { return }
            report = result
            issueKey = nil
            isPreviewing = false
        } catch {
            guard token == revision, self.week == week else { return }
            issueKey = AppErrorMessage.key(for: error, fallback: "allocation.error.preview")
            isPreviewing = false
        }
    }

    func refresh(at now: Date = .now) async {
        guard !isBusy else { return }
        isBusy = true
        revision += 1
        defer { isBusy = false }
        do {
            // Let the service initialize calendar settings on the first launch.
            _ = try await service.homeSections(recentLimit: 8)
            guard let saved = try await store.loadSettings() else { throw LoadError.missingSettings }
            settings = try CalendarSettings.validated(timeZoneIdentifier: saved.timeZoneIdentifier,
                dayStartHour: saved.dayStartHour, weekStartWeekday: saved.weekStartWeekday)
            if week == nil { week = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: now, settings: saved), settings: saved) }
            try await load()
        } catch {
            report = nil
            issueKey = AppErrorMessage.key(for: error, fallback: "allocation.error.load")
            isPreviewing = false
        }
    }

    private func load() async throws {
        guard let week else { return }
        tree = try ActivityTree.build(from: await store.loadActivities())
        let result = try await service.allocationReport(for: week)
        state = result.state
        report = result.report
        // Drop edits only for activities that can no longer accept a budget.
        drafts[week] = drafts[week]?.filter { id, _ in
            result.report.nodes.contains { $0.activityID == id && $0.mode == .managed && $0.direction != nil }
        }
        await validateDraft()
    }

    func selectWeek(offset: Int?, at now: Date = .now) async {
        guard !isBusy, let settings, let week else { return }
        let next: LogicalWeek
        if let offset {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: settings.timeZoneIdentifier)!
            let start = TimeAxis.interval(of: week, settings: settings).start
            guard let date = calendar.date(byAdding: .day, value: offset * 7, to: start) else { return }
            next = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: date, settings: settings), settings: settings)
        } else {
            next = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: now, settings: settings), settings: settings)
        }
        self.week = next
        report = nil
        affectedChildren = [:]
        await refresh(at: now)
    }

    func saveWish(_ minutes: Int, direction: BudgetDirection, for id: ActivityID) async -> Bool {
        guard !isBusy, let week else { return false }
        // This checks numeric representation only; it imposes no weekly or parent allocation limit.
        guard minutes >= 0, Self.canSum(nodes.map {
            $0.activityID == id ? minutes : ($0.wishMinutes ?? 0)
        }) else {
            issueKey = "allocation.error.numericRange"
            return false
        }
        isBusy = true
        revision += 1
        defer { isBusy = false }
        do {
            // Wishes never depend on canCommit, parent reduction, or the validity of committed input.
            try await service.setWish(activityID: id, minutes: minutes, direction: direction, week: week)
            if var activity = tree?.node(id), activity.budgetMode == .unset {
                // ASSUMPTION: Creating a budget from this screen opts an unset activity into managed mode.
                // The editor explains that this activity mode applies across weeks.
                activity.budgetMode = .managed
                try await service.updateActivity(activity)
            }
            try await load()
            return true
        } catch {
            // setWish may have saved before a later refresh failed. Keep the draft and reconcile on retry.
            do { try await load() }
            catch { report = nil }
            state = .pending
            issueKey = AppErrorMessage.key(for: error, fallback: "allocation.error.wish")
            isPreviewing = false
            return false
        }
    }

    func commit() async {
        guard canCommit, let week else { return }
        let values = proposals()
        isBusy = true
        revision += 1
        defer { isBusy = false }
        do {
            try await service.commitAllocation(week: week, committed: values)
            drafts[week] = nil
            try await load()
        } catch Week168ServiceError.allocationRejected(let rejected) {
            report = rejected
            state = .pending
            issueKey = "allocation.error.rejected"
            isPreviewing = false
        } catch {
            issueKey = AppErrorMessage.key(for: error, fallback: "allocation.error.commit")
            isPreviewing = false
        }
    }

    private static func canSum(_ values: [Int]) -> Bool {
        var total = 0
        for value in values {
            guard value >= 0 else { return false }
            let next = total.addingReportingOverflow(value)
            guard !next.overflow else { return false }
            total = next.partialValue
        }
        return true
    }

    private enum LoadError: Error { case missingSettings }
}
