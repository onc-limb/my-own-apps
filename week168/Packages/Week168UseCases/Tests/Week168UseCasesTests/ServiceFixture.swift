import Foundation
import Week168Domain
import Week168Persistence
import Week168UseCases

final class ServiceFixture: Sendable {
    let directory: URL
    let store: Week168Store
    let clock: FakeClock
    let alarms: RecordingAlarms
    let service: Week168Service
    let week = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 14))

    static func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    init(now: String = "2026-09-15T12:00:00Z") throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/test-stores")
        directory = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = Week168Store(container: try Week168Store.makeContainer(at: directory.appendingPathComponent("store.sqlite")))
        clock = FakeClock(Self.date(now))
        alarms = RecordingAlarms()
        service = Week168Service(store: store, clock: clock, alarms: alarms)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    func activity(_ name: String = "活動", parent: ActivityID? = nil,
                  mode: BudgetMode = .managed, planned: Int? = nil) async throws -> Activity {
        try await service.createActivity(name: name, parentID: parent, budgetMode: mode, defaultPlannedMinutes: planned)
    }

    func entries() async throws -> [TimeEntry] {
        try await store.loadEntries(overlapping: DateInterval(start: .distantPast, end: .distantFuture))
    }

    func history(_ id: ActivityID, minutes: Int) async throws {
        try await service.addEntry(activityID: id, startedAt: clock.now().addingTimeInterval(Double(-minutes - 1) * 60),
                                   endedAt: clock.now().addingTimeInterval(-60), note: "実績")
    }

    func commit(_ id: ActivityID, _ minutes: Int, week: LogicalWeek? = nil) async throws {
        let targetWeek = week ?? self.week
        let budgets = try await BudgetResolver.resolve(week: targetWeek, entries: store.loadBudgets(), capacities: [])
        if budgets.budget(for: id) == nil {
            // Model the screen flow: choose a wish and direction before allocating.
            try await service.setWish(activityID: id, minutes: minutes, direction: .cap, week: targetWeek)
        }
        try await service.setCommitted(activityID: id, minutes: minutes, week: targetWeek)
    }

    func overCapacity(planned: Int? = nil) async throws -> Activity {
        let activity = try await activity(planned: planned)
        try await service.setWish(activityID: activity.id, minutes: 300, direction: .goal, week: week)
        try await commit(activity.id, 300)
        try await service.setCapacity(minutes: 200, from: week)
        return activity
    }
}
