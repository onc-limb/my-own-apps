import Foundation
import Observation
import Week168Domain
import Week168Persistence
import Week168UseCases

struct HomeSnapshot {
    let tree: ActivityTree
    let entries: [TimeEntry]
    let budgets: [BudgetEntry]
    let capacities: [CapacityEntry]
    let settings: CalendarSettings
    var committedWeek: LogicalWeek? = nil

    var running: TimeEntry? { entries.first { $0.endedAt == nil } }

    func presentation(at now: Date) -> HomePresentation {
        let week = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: now, settings: settings), settings: settings)
        let resolved = BudgetResolver.resolve(week: week, entries: budgets, capacities: capacities)
        let allocationReport = AllocationValidator.report(tree: tree, budgets: resolved, week: week)
        let commitmentState = allocationReport.commitmentState(hasCommitmentRecord: committedWeek == week)
        let committed = commitmentState == .committed
        let summaries = Aggregator.summarize(entries: entries, tree: tree, budgets: resolved,
                                            interval: TimeAxis.interval(of: week, settings: settings), now: now)
        let recent = entries.reduce(into: [ActivityID: Date]()) { result, entry in
            result[entry.activityID] = max(result[entry.activityID] ?? .distantPast, entry.startedAt)
        }
        // ASSUMPTION: Show the eight most recently used activities.
        let sections = HomeComposer.compose(tree: tree, summaries: summaries, lastUsedAt: recent,
                                            recentLimit: 8, isCommitted: committed)
        // ASSUMPTION: S-3 includes archived activities even when this week's actual is zero.
        let weekly = tree.topLevel().flatMap { [$0.id] + tree.descendants(of: $0.id) }
        return HomePresentation(sections: sections, summaries: summaries, isCommitted: committed,
                                capacityOverflowMinutes: allocationReport.capacityOverflowMinutes, weekly: weekly, commitmentState: commitmentState)
    }
}

struct HomePresentation {
    let sections: HomeSections
    let summaries: [ActivityID: ActivitySummary]
    let isCommitted: Bool
    let capacityOverflowMinutes: Int
    let weekly: [ActivityID]
    let commitmentState: CommitmentState
}

struct HomeIssue: Identifiable {
    let id = UUID()
    let messageKey: String
}

@MainActor @Observable
final class HomeViewModel {
    private let store: Week168Store
    private let service: Week168Service
    private(set) var snapshot: HomeSnapshot?
    private(set) var serviceSections: HomeSections?
    private(set) var isBusy = false
    private(set) var lastSwitch: SwitchResult?
    private(set) var undoExpiresAt: Date?
    var issue: HomeIssue?

    init(store: Week168Store, service: Week168Service) {
        self.store = store
        self.service = service
    }

    private func load() async throws {
        let result = try await service.homeSections(recentLimit: 8)
        let activities = try await store.loadActivities()
        let entries = try await store.loadEntries(overlapping: DateInterval(start: .distantPast, end: .distantFuture))
        let budgets = try await store.loadBudgets()
        let capacities = try await store.loadCapacities()
        guard let settings = try await store.loadSettings() else { throw SnapshotError.missingSettings }
        let validSettings = try CalendarSettings.validated(timeZoneIdentifier: settings.timeZoneIdentifier,
            dayStartHour: settings.dayStartHour, weekStartWeekday: settings.weekStartWeekday)
        let tree = try ActivityTree.build(from: activities)
        let week = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: .now, settings: validSettings), settings: validSettings)
        let record = try await store.loadCommitment(for: week)
        snapshot = HomeSnapshot(tree: tree, entries: entries, budgets: budgets, capacities: capacities, settings: validSettings, committedWeek: record?.week)
        serviceSections = result.sections
    }

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        dismissUndo()
        do { try await load() }
        catch {
            snapshot = nil
            issue = HomeIssue(messageKey: "error.load")
        }
    }

    func dismissUndo() {
        lastSwitch = nil
        undoExpiresAt = nil
    }

    func start(_ activity: Activity) async {
        guard !activity.isArchived, snapshot?.running?.activityID != activity.id else { return }
        await perform(errorKey: "error.start") {
            let result = try await self.service.startOrSwitch(to: activity.id)
            if result.previousRunning != nil {
                self.lastSwitch = result
                // ASSUMPTION: Undo is available for 10 seconds, or until the next operation/navigation.
                self.undoExpiresAt = Date.now.addingTimeInterval(10)
            }
        }
    }

    func stop() async {
        await perform(errorKey: "error.stop") { try await self.service.stopRunning() }
    }

    func changePlan(_ minutes: Int?) async {
        await perform(errorKey: "error.plan") { try await self.service.changePlannedMinutes(minutes) }
    }

    func undo() async {
        guard let result = lastSwitch, let expiry = undoExpiresAt, Date.now < expiry else {
            dismissUndo()
            issue = HomeIssue(messageKey: "error.undoExpired")
            return
        }
        await perform(errorKey: "error.undo") { try await self.service.undoLastSwitch(result) }
    }

    private func perform(errorKey: String, operation: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        dismissUndo()
        issue = nil
        do {
            try await operation()
        } catch {
            dismissUndo()
            issue = HomeIssue(messageKey: errorKey)
        }
        // Reload even after a failure: a service operation may have saved before alarm refresh failed.
        do { try await load() }
        catch {
            snapshot = nil
            dismissUndo()
            issue = HomeIssue(messageKey: "error.reconcile")
        }
    }

    private enum SnapshotError: Error { case missingSettings }
}

enum HomeTime {
    static func minutes(_ minutes: Int) -> String {
        let value = minutes.magnitude
        let sign = minutes < 0 ? "−" : ""
        return sign + String(value / 60) + ":" + String(format: "%02d", Int(value % 60))
    }

    static func elapsed(since start: Date, at now: Date) -> String {
        let seconds = Int(max(0, now.timeIntervalSince(start)))
        return String(format: "%02lld:%02lld:%02lld", Int64(seconds / 3600), Int64((seconds % 3600) / 60), Int64(seconds % 60))
    }
}
