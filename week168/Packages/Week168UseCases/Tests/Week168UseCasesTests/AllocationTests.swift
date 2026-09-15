import Testing
import Week168Domain
import Week168UseCases

struct AllocationTests {
    @Test func 必須09_総枠を超える希望も両方保存() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity("開発")
        let b = try await f.activity("勉強")
        try await f.service.setCapacity(minutes: 1200, from: f.week)
        try await f.service.setWish(activityID: a.id, minutes: 540, direction: .goal, week: f.week)
        try await f.service.setWish(activityID: b.id, minutes: 780, direction: .goal, week: f.week)
        let report = try await f.service.allocationReport(for: f.week)
        #expect(report.totalWishMinutes == 1320)
        #expect(report.wishOverflowMinutes == 120)
        #expect(try await f.store.loadBudgets().count == 2)
    }

    @Test func 必須10_確定の総枠超過は120分のレポート付きで失敗() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity("開発")
        let b = try await f.activity("勉強")
        try await f.service.setCapacity(minutes: 1200, from: f.week)
        try await f.commit(a.id, 540)
        do {
            try await f.commit(b.id, 780)
            Issue.record("超過配分が保存された")
        } catch Week168ServiceError.allocationRejected(let report) {
            #expect(report.capacityOverflowMinutes == 120)
            #expect(!report.canCommit)
        }
    }

    @Test func 必須11_勉強660分なら確定可能() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity("開発")
        let b = try await f.activity("勉強")
        try await f.service.setCapacity(minutes: 1200, from: f.week)
        try await f.commit(a.id, 540)
        await #expect(throws: Week168ServiceError.self) { try await f.commit(b.id, 780) }
        try await f.commit(b.id, 660)
        let report = try await f.service.allocationReport(for: f.week)
        #expect(report.canCommit)
        #expect(report.totalCommittedMinutes == 1200)
    }

    @Test func 必須12_子の超過は親を含むレポート付きで失敗() async throws {
        let f = try ServiceFixture()
        let parent = try await f.activity("親")
        let child = try await f.activity("子", parent: parent.id)
        try await f.commit(parent.id, 60)
        do {
            try await f.commit(child.id, 90)
            Issue.record("子の超過配分が保存された")
        } catch Week168ServiceError.allocationRejected(let report) {
            #expect(report.offendingActivities == [parent.id])
            #expect(report.nodes.first { $0.activityID == parent.id }?.overflowMinutes == 30)
        }
    }

    @Test func 必須13_親360分への縮小は180分不足し子3件に影響() async throws {
        let f = try ServiceFixture()
        let parent = try await f.activity("開発")
        try await f.commit(parent.id, 540)
        var children: [ActivityID] = []
        for name in ["一", "二", "三"] {
            let child = try await f.activity(name, parent: parent.id)
            children.append(child.id)
            try await f.commit(child.id, 180)
        }
        let reduction = try await f.service.requiredReductionForParent(parent.id, newCommitted: 360, week: f.week)
        #expect(reduction.excess == 180)
        #expect(Set(reduction.children) == Set(children))
    }

    @Test func 必須14_確定失敗後の再読込は元の予算のまま() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.service.setCapacity(minutes: 100, from: f.week)
        try await f.commit(a.id, 60)
        let before = try await f.store.loadBudgets()
        await #expect(throws: Week168ServiceError.self) { try await f.commit(a.id, 120) }
        #expect(try await f.store.loadBudgets() == before)
        #expect(try await f.service.allocationReport(for: f.week).totalCommittedMinutes == 60)
    }
}
