import Foundation
import Testing
import Week168Domain
import Week168UseCases

struct NotificationTests {
    @Test func 必須15_上限300分実績270分なら30分後に通知() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.commit(a.id, 300)
        try await f.history(a.id, minutes: 270)
        _ = try await f.service.startOrSwitch(to: a.id)
        let notice = try #require(await f.alarms.budgets.last)
        #expect(notice.activityID == a.id)
        #expect(notice.name == a.name)
        #expect(notice.fireAt == f.clock.now().addingTimeInterval(1800))
        #expect(try await f.store.loadRunningEntry() != nil)
    }

    @Test func 必須16_既に超過していれば予算通知なし() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.commit(a.id, 300)
        try await f.history(a.id, minutes: 301)
        _ = try await f.service.startOrSwitch(to: a.id)
        #expect(await f.alarms.budgets.isEmpty)
    }

    @Test func 必須17_未確定は予算通知なしでも予定アラームあり() async throws {
        let f = try ServiceFixture()
        let a = try await f.overCapacity(planned: 60)
        #expect(try await f.service.allocationReport(for: f.week).report.canCommit == false)
        _ = try await f.service.startOrSwitch(to: a.id)
        #expect(await f.alarms.budgets.isEmpty)
        #expect(await f.alarms.planned.last?.fireAt == f.clock.now().addingTimeInterval(3600))
    }

    @Test func 必須18_子の残り30分より親の残り10分を優先() async throws {
        let f = try ServiceFixture()
        let parent = try await f.activity("親")
        let child = try await f.activity("子", parent: parent.id)
        try await f.commit(parent.id, 100)
        try await f.commit(child.id, 30)
        try await f.history(parent.id, minutes: 90)
        _ = try await f.service.startOrSwitch(to: child.id)
        let notice = try #require(await f.alarms.budgets.last)
        #expect(notice.activityID == parent.id)
        #expect(notice.name == parent.name)
        #expect(notice.fireAt == f.clock.now().addingTimeInterval(600))
    }

    @Test func 必須19_予算のない活動は予算通知なし() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity(mode: .unset)
        _ = try await f.service.startOrSwitch(to: a.id)
        #expect(await f.alarms.budgets.isEmpty)
    }
}
