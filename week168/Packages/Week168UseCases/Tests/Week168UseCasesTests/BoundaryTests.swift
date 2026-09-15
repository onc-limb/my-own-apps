import Foundation
import Testing
import Week168Domain
import Week168UseCases

struct BoundaryTests {
    @Test func 対象外祖先の下では予算通知なしでも予定予約あり() async throws {
        let f = try ServiceFixture()
        let grandparent = try await f.activity("祖父")
        let parent = try await f.activity("対象外", parent: grandparent.id, mode: .excluded)
        let child = try await f.activity("子", parent: parent.id, mode: .unset, planned: 20)
        try await f.commit(grandparent.id, 60)
        _ = try await f.service.startOrSwitch(to: child.id)
        #expect(await f.alarms.budgets.isEmpty)
        #expect(await f.alarms.planned.last?.fireAt == f.clock.now().addingTimeInterval(1200))
    }

    @Test func 予算未設定の子は祖父まで通知候補を探す() async throws {
        let f = try ServiceFixture()
        let grandparent = try await f.activity("祖父")
        let parent = try await f.activity("親", parent: grandparent.id, mode: .unset)
        let child = try await f.activity("子", parent: parent.id, mode: .unset)
        try await f.commit(grandparent.id, 60)
        _ = try await f.service.startOrSwitch(to: child.id)
        #expect(await f.alarms.budgets.last?.activityID == grandparent.id)
        #expect(await f.alarms.budgets.last?.fireAt == f.clock.now().addingTimeInterval(3600))
    }

    @Test func 再予約では進行中の経過時間も予算から引く() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.commit(a.id, 60)
        let started = try await f.service.startOrSwitch(to: a.id)
        f.clock.advance(minutes: 10)
        await f.alarms.reset()
        try await f.service.changePlannedMinutes(30)
        #expect(await f.alarms.budgets.last?.fireAt == started.started.startedAt.addingTimeInterval(3600))
    }

    @Test func 予算変更のない週には行を増やさない() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.service.setWish(activityID: a.id, minutes: 60, direction: .cap, week: f.week)
        try await f.commit(a.id, 60)
        try await f.service.setCapacity(minutes: 120, from: f.week)
        let next = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 21))
        try await f.service.setWish(activityID: a.id, minutes: 60, direction: .cap, week: next)
        try await f.commit(a.id, 60, week: next)
        try await f.service.setCapacity(minutes: 120, from: next)
        #expect(try await f.store.loadBudgets().count == 1)
        #expect(try await f.store.loadCapacities().count == 1)
    }

    @Test func 無関係の親の超過も確定時に検証する() async throws {
        let f = try ServiceFixture()
        let parent = try await f.activity("親")
        let child = try await f.activity("子", parent: parent.id)
        let other = try await f.activity("別")
        try await f.commit(parent.id, 60)
        try await f.commit(child.id, 60)
        // Simulate previously imported allocation through the persistence public API.
        try await f.store.upsertBudget(BudgetEntry(activityID: parent.id, effectiveFrom: f.week,
                                                   direction: .cap, wishMinutes: 30, committedMinutes: 30))
        do {
            try await f.commit(other.id, 10)
            Issue.record("別の枝の超過を見逃した")
        } catch Week168ServiceError.allocationRejected(let report) {
            #expect(report.offendingActivities == [parent.id])
        }
        let otherBudget = try #require(try await f.store.loadBudgets().first { $0.activityID == other.id })
        #expect(otherBudget.wishMinutes == 10)
        #expect(otherBudget.committedMinutes == nil)
    }

    @Test func 記録の追加編集削除は検証して保存() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.history(a.id, minutes: 10)
        var entry = try #require(try await f.entries().first)
        entry.note = "修正"
        try await f.service.updateEntry(entry)
        #expect(try await f.entries().first?.note == "修正")
        await #expect(throws: EntryValidationError.self) {
            try await f.service.addEntry(activityID: a.id, startedAt: f.clock.now(),
                                         endedAt: f.clock.now().addingTimeInterval(60), note: "未来")
        }
        await #expect(throws: EntryValidationError.self) {
            try await f.service.addEntry(activityID: a.id, startedAt: entry.startedAt,
                                         endedAt: entry.endedAt!, note: "重複")
        }
        #expect(try await f.entries().count == 1)
        try await f.service.deleteEntry(entry.id)
        #expect(try await f.entries().isEmpty)
    }

    @Test func 暦設定を検証してホームの週に反映() async throws {
        let f = try ServiceFixture(now: "2026-09-14T01:00:00Z")
        let settings = CalendarSettings(timeZoneIdentifier: "UTC", dayStartHour: 4, weekStartWeekday: 2)
        try await f.service.updateCalendarSettings(settings)
        #expect(try await f.store.loadSettings() == settings)
        let a = try await f.activity()
        let earlier = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 7))
        try await f.commit(a.id, 60, week: earlier)
        try await f.commit(a.id, 120)
        #expect(try await f.service.homeSections(recentLimit: 5).summaries[a.id]?.budgetMinutes == 60)
        await #expect(throws: CalendarSettings.ValidationError.self) {
            try await f.service.updateCalendarSettings(CalendarSettings(timeZoneIdentifier: "invalid", dayStartHour: 0, weekStartWeekday: 2))
        }
        #expect(try await f.store.loadSettings() == settings)
    }

    @Test func 活動の循環変更と不正な並替は保存しない() async throws {
        let f = try ServiceFixture()
        var parent = try await f.activity("親")
        let child = try await f.activity("子", parent: parent.id)
        let before = try await f.store.loadActivities()
        parent.parentID = child.id
        await #expect(throws: ActivityTree.BuildError.self) { try await f.service.updateActivity(parent) }
        await #expect(throws: Week168ServiceError.self) {
            try await f.service.reorderActivities([child.id], under: nil)
        }
        #expect(try await f.store.loadActivities() == before)
    }

    @Test func 古い切替取消は新しい計測を壊さない() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        let first = try await f.service.startOrSwitch(to: a.id)
        f.clock.advance(minutes: 1)
        let second = try await f.service.startOrSwitch(to: a.id)
        await #expect(throws: Week168ServiceError.self) { try await f.service.undoLastSwitch(first) }
        #expect(try await f.store.loadRunningEntry() == second.started)
    }

    @Test func 同時開始要求でも進行中は一つ() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        let b = try await f.activity()
        async let first = f.service.startOrSwitch(to: a.id)
        async let second = f.service.startOrSwitch(to: b.id)
        _ = try await (first, second)
        #expect(try await f.entries().count == 1)
        #expect(try await f.store.loadRunningEntry() != nil)
    }
}
