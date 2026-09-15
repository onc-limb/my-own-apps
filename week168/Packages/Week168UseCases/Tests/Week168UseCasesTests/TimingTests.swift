import Foundation
import Testing
import Week168Domain
import Week168UseCases

struct TimingTests {
    @Test func 必須01_既定60分を適用し開始60分後に予約() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity(planned: 60)
        let result = try await f.service.startOrSwitch(to: a.id)
        #expect(result.started.plannedMinutes == 60)
        #expect(try await f.store.loadRunningEntry() == result.started)
        let alarm = try #require(await f.alarms.planned.last)
        #expect(alarm.entryID == result.started.id)
        #expect(alarm.name == a.name)
        #expect(alarm.fireAt == f.clock.now().addingTimeInterval(3600))
    }

    @Test func 必須02_既定なしは予定もアラームもなし() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        let result = try await f.service.startOrSwitch(to: a.id)
        #expect(result.started.plannedMinutes == nil)
        #expect(await f.alarms.planned.isEmpty)
        #expect(await f.alarms.budgets.isEmpty)
    }

    @Test func 必須03_切替は同時刻に終了開始し古い予約を取消() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity("前", planned: 60)
        let b = try await f.activity("後", planned: 30)
        let first = try await f.service.startOrSwitch(to: a.id)
        f.clock.advance(minutes: 10)
        await f.alarms.reset()
        let result = try await f.service.startOrSwitch(to: b.id)
        #expect(result.closed?.endedAt == result.started.startedAt)
        #expect(result.previousRunning == first.started)
        #expect(try await f.entries().count == 2)
        #expect(try await f.store.loadRunningEntry()?.activityID == b.id)
        #expect(await f.alarms.cancelled.contains(first.started.id))
        #expect(await f.alarms.planned.last?.fireAt == f.clock.now().addingTimeInterval(1800))
    }

    @Test func 必須04_同じ瞬間の切替は前の記録を破棄() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        let b = try await f.activity()
        _ = try await f.service.startOrSwitch(to: a.id)
        let result = try await f.service.startOrSwitch(to: b.id)
        #expect(result.closed == nil)
        #expect(try await f.entries() == [result.started])
    }

    @Test func 必須05_切替取消で元の進行中と予定アラームが戻る() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity(planned: 60)
        let b = try await f.activity(planned: 30)
        let first = try await f.service.startOrSwitch(to: a.id)
        f.clock.advance(minutes: 10)
        let result = try await f.service.startOrSwitch(to: b.id)
        await f.alarms.reset()
        try await f.service.undoLastSwitch(result)
        #expect(try await f.entries() == [first.started])
        #expect(await f.alarms.cancelled.contains(result.started.id))
        #expect(await f.alarms.planned.last?.entryID == first.started.id)
        #expect(await f.alarms.planned.last?.fireAt == first.started.startedAt.addingTimeInterval(3600))
    }

    @Test func 必須06_予定変更は変更時刻でなく開始30分後() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity(planned: 60)
        let result = try await f.service.startOrSwitch(to: a.id)
        f.clock.advance(minutes: 5)
        await f.alarms.reset()
        try await f.service.changePlannedMinutes(30)
        #expect(await f.alarms.cancelled == [result.started.id])
        #expect(await f.alarms.planned.last?.fireAt == result.started.startedAt.addingTimeInterval(1800))
        #expect(try await f.store.loadRunningEntry()?.plannedMinutes == 30)
    }

    @Test func 必須07_予定解除はアラーム取消() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity(planned: 60)
        let result = try await f.service.startOrSwitch(to: a.id)
        await f.alarms.reset()
        try await f.service.changePlannedMinutes(nil)
        #expect(await f.alarms.cancelled == [result.started.id])
        #expect(await f.alarms.planned.isEmpty)
        #expect(try await f.store.loadRunningEntry()?.plannedMinutes == nil)
    }

    @Test func 必須08_停止で記録を閉じ全予約取消() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity(planned: 60)
        try await f.commit(a.id, 300)
        let result = try await f.service.startOrSwitch(to: a.id)
        f.clock.advance(minutes: 5)
        await f.alarms.reset()
        try await f.service.stopRunning()
        #expect(try await f.store.loadRunningEntry() == nil)
        #expect(try await f.entries().first?.endedAt == f.clock.now())
        #expect(await f.alarms.cancelled == [result.started.id])
        #expect(await f.alarms.planned.isEmpty)
        #expect(await f.alarms.budgets.isEmpty)
    }
}
