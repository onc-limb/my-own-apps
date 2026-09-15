import Foundation
import Testing
import Week168Domain
import Week168Persistence
import Week168UseCases

struct ReviewRegressionTests {
    @Test("F-1: 未保存の暦設定は端末タイムゾーンで保存し再読込後も使用する")
    func initialSettingsPersistAndAreReused() async throws {
        let f = try ServiceFixture()
        let expected = CalendarSettings(timeZoneIdentifier: TimeZone.current.identifier,
                                        dayStartHour: 4, weekStartWeekday: 2)
        #expect(try await f.store.loadSettings() == nil)
        _ = try await f.service.weeklyReport(for: f.week)
        #expect(try await f.store.loadSettings() == expected)
        let a = try await f.activity()
        let boundary = TimeAxis.interval(of: f.week, settings: expected).start
        try await f.service.addEntry(activityID: a.id, startedAt: boundary.addingTimeInterval(-1800),
                                     endedAt: boundary.addingTimeInterval(1800), note: "Week boundary")
        #expect(try await f.service.weeklyReport(for: f.week)[a.id]?.totalMinutes == 30)
        // A new store and service must read the persisted value, not an in-memory default.
        let reopened = Week168Store(container: try Week168Store.makeContainer(
            at: f.directory.appendingPathComponent("store.sqlite")))
        let service = Week168Service(store: reopened, clock: f.clock, alarms: f.alarms)
        #expect(try await reopened.loadSettings() == expected)
        #expect(try await service.weeklyReport(for: f.week)[a.id]?.totalMinutes == 30)
        #expect(try await reopened.loadSettings() == expected)
    }

    @Test("F-2: 解決できる予算行がなければ確定を拒否し何も保存しない")
    func commitmentWithoutBudgetDoesNotPersist() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        // Test both missing history and history that starts only in a future week.
        for futureOnly in [false, true] {
            if futureOnly {
                try await f.service.setWish(activityID: a.id, minutes: 120, direction: .goal,
                    week: LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 21)))
            }
            let before = try await f.store.loadBudgets()
            for minutes: Int? in [60, nil] {
                do {
                    try await f.service.setCommitted(activityID: a.id, minutes: minutes, week: f.week)
                    Issue.record("Expected budgetNotSet")
                } catch Week168ServiceError.budgetNotSet { }
                #expect(try await f.store.loadBudgets() == before)
            }
            let reopened = Week168Store(container: try Week168Store.makeContainer(
                at: f.directory.appendingPathComponent("store.sqlite")))
            #expect(try await reopened.loadBudgets() == before)
        }
    }

    @Test("F-2: 継承した目標の方向と希望を確定後も保持する")
    func inheritedGoalPreservesWishAndDirection() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        let previous = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 7))
        try await f.service.setWish(activityID: a.id, minutes: 120, direction: .goal, week: previous)
        try await f.service.setCommitted(activityID: a.id, minutes: 60, week: f.week)
        let current = try #require(try await f.store.loadBudgets().first { $0.effectiveFrom == f.week })
        #expect(current.direction == .goal)
        #expect(current.wishMinutes == 120)
        #expect(current.committedMinutes == 60)
    }
}
