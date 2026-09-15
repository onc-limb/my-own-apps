import Foundation
import Testing
import Week168Domain
import Week168UseCases

struct ReportTests {
    @Test func 必須20_2026年9月は開始日が月内の4週() async throws {
        let f = try ServiceFixture()
        let report = try await f.service.monthlyReport(year: 2026, month: 9)
        #expect(report.weekCount == 4)
        let settings = CalendarSettings(timeZoneIdentifier: "UTC", dayStartHour: 0, weekStartWeekday: 2)
        #expect(TimeAxis.weeks(inYear: 2026, month: 9, settings: settings).map { $0.startDay.day } == [7, 14, 21, 28])
    }

    @Test func 必須21_月次は週またぎ記録を各週に按分して合算() async throws {
        let f = try ServiceFixture(now: "2026-10-06T12:00:00Z")
        try await f.service.updateCalendarSettings(
            CalendarSettings(timeZoneIdentifier: "UTC", dayStartHour: 0, weekStartWeekday: 2))
        let a = try await f.activity()
        try await f.service.addEntry(activityID: a.id,
            startedAt: ServiceFixture.date("2026-09-13T23:30:00Z"),
            endedAt: ServiceFixture.date("2026-09-14T00:30:00Z"), note: "週境界")
        try await f.service.addEntry(activityID: a.id,
            startedAt: ServiceFixture.date("2026-09-06T23:30:00Z"),
            endedAt: ServiceFixture.date("2026-09-07T00:30:00Z"), note: "月の対象週開始")
        try await f.service.addEntry(activityID: a.id,
            startedAt: ServiceFixture.date("2026-10-04T23:30:00Z"),
            endedAt: ServiceFixture.date("2026-10-05T00:30:00Z"), note: "月の対象週終了")
        let first = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 7))
        #expect(try await f.service.weeklyReport(for: first)[a.id]?.ownMinutes == 60)
        #expect(try await f.service.weeklyReport(for: f.week)[a.id]?.ownMinutes == 30)
        let month = try await f.service.monthlyReport(year: 2026, month: 9)
        #expect(month.perActivity[a.id]?.ownMinutes == 120)
        #expect(month.perActivity[a.id]?.totalMinutes == 120)
    }

    @Test func 必須22_週ごとに異なる予算で判定して月次合算() async throws {
        let f = try ServiceFixture(now: "2026-10-06T12:00:00Z")
        let a = try await f.activity()
        let weeks = [7, 14, 21, 28].map { LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: $0)) }
        let budgets = [60, 120, 180, 240]
        for (week, budget) in zip(weeks, budgets) { try await f.commit(a.id, budget, week: week) }
        for day in [8, 15, 22, 29] {
            let start = ServiceFixture.date(String(format: "2026-09-%02dT10:00:00Z", day))
            try await f.service.addEntry(activityID: a.id, startedAt: start,
                                         endedAt: start.addingTimeInterval(5400), note: "90分")
        }
        for (week, budget) in zip(weeks, budgets) {
            let value = try #require(try await f.service.weeklyReport(for: week)[a.id])
            #expect(value.budgetMinutes == budget)
            #expect(value.deviationMinutes == max(0, 90 - budget))
        }
        let value = try #require(try await f.service.monthlyReport(year: 2026, month: 9).perActivity[a.id])
        #expect(value.totalMinutes == 360)
        #expect(value.budgetMinutes == 600)
        #expect(value.direction == .cap)
    }

    @Test func 必須23_ホームは未達目標と最近と今週消化の3ブロック() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity("目標")
        try await f.service.setWish(activityID: a.id, minutes: 60, direction: .goal, week: f.week)
        try await f.commit(a.id, 60)
        try await f.history(a.id, minutes: 10)
        let home = try await f.service.homeSections(recentLimit: 5)
        #expect(home.isCommitted)
        #expect(home.sections.unmetGoals == [a.id])
        #expect(home.sections.recentlyUsed == [a.id])
        #expect(home.sections.weeklyProgress == [a.id])
        #expect(home.summaries[a.id]?.totalMinutes == 10)
    }

    @Test func 必須24_未確定ホームは未達目標が空() async throws {
        let f = try ServiceFixture()
        let a = try await f.overCapacity()
        let home = try await f.service.homeSections(recentLimit: 5)
        #expect(!home.isCommitted)
        #expect(home.sections.unmetGoals.isEmpty)
        #expect(home.sections.weeklyProgress == [a.id])
    }
}
