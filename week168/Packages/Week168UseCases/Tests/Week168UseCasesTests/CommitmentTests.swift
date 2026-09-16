import Testing
import Week168Domain
import Week168Persistence
import Week168UseCases

struct CommitmentTests {
    private func overloaded() async throws -> (ServiceFixture, [ActivityID], [ActivityID]) {
        let f = try ServiceFixture()
        var parents: [ActivityID] = []
        var children: [ActivityID] = []
        for name in ["A", "B"] {
            let parent = try await f.activity(name)
            let child = try await f.activity(name + "の子", parent: parent.id)
            parents.append(parent.id)
            children.append(child.id)
            for id in [parent.id, child.id] {
                try await f.store.upsertBudget(BudgetEntry(activityID: id, effectiveFrom: f.week,
                    direction: .goal, wishMinutes: 720, committedMinutes: 720))
            }
        }
        try await f.service.setCapacity(minutes: 1200, from: f.week)
        return (f, parents, children)
    }

    private func proposed(_ ids: [ActivityID]) -> [ActivityID: Int?] {
        Dictionary(uniqueKeysWithValues: ids.map { ($0, Optional(600)) })
    }

    @Test func T10a必須04_総枠縮小で当週以降の記録を消して未確定() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        let previous = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 7))
        let next = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 21))
        for week in [previous, f.week, next] { try await f.commit(a.id, 720, week: week) }
        try await f.service.setCapacity(minutes: 600, from: f.week)
        for week in [f.week, next] {
            #expect(try await f.store.loadCommitment(for: week) == nil)
            let result = try await f.service.allocationReport(for: week)
            #expect(result.state == .pending)
            #expect(result.report.capacityOverflowMinutes == 120)
        }
        #expect(try await f.store.loadCommitment(for: previous) != nil)
    }

    @Test func T10a必須05_希望変更で記録を消して未確定() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.commit(a.id, 600)
        try await f.service.setWish(activityID: a.id, minutes: 720, direction: .goal, week: f.week)
        #expect(try await f.store.loadCommitment(for: f.week) == nil)
        #expect(try await f.service.allocationReport(for: f.week).state == .pending)
    }

    @Test func T10a必須06_予算モード変更で記録を削除() async throws {
        let f = try ServiceFixture()
        var a = try await f.activity()
        try await f.commit(a.id, 600)
        a.budgetMode = .excluded
        try await f.service.updateActivity(a)
        #expect(try await f.store.loadCommitment(for: f.week) == nil)
        #expect(try await f.service.allocationReport(for: f.week).state == .unused)
    }

    @Test func T10a必須07_確定取消は予算値を維持して未確定() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.commit(a.id, 600)
        let before = try await f.store.loadBudgets()
        try await f.service.uncommitAllocation(week: f.week)
        #expect(try await f.store.loadCommitment(for: f.week) == nil)
        #expect(try await f.store.loadBudgets() == before)
        #expect(try await f.service.allocationReport(for: f.week).state == .pending)
    }

    @Test func T10a必須08_総枠1200で親二件と各子720を同時に600へ下げ成功() async throws {
        let (f, parents, children) = try await overloaded()
        try await f.service.commitAllocation(week: f.week, committed: proposed(parents + children))
        let result = try await f.service.allocationReport(for: f.week)
        #expect(result.state == .committed)
        #expect(result.report.totalCommittedMinutes == 1200)
        #expect(result.report.nodes.count == 4)
        #expect(result.report.nodes.allSatisfy { $0.committedMinutes == 600 && $0.overflowMinutes == 0 })
    }

    @Test func T10a必須09_子だけ縮小は総枠超過240のレポート付きで失敗() async throws {
        let (f, _, children) = try await overloaded()
        do {
            try await f.service.commitAllocation(week: f.week, committed: proposed(children))
            Issue.record("総枠超過を保存した")
        } catch Week168ServiceError.allocationRejected(let report) {
            #expect(report.capacityOverflowMinutes == 240)
        }
    }

    @Test func T10a必須10_親だけ縮小は超過した親二件のレポート付きで失敗() async throws {
        let (f, parents, _) = try await overloaded()
        do {
            try await f.service.commitAllocation(week: f.week, committed: proposed(parents))
            Issue.record("親子超過を保存した")
        } catch Week168ServiceError.allocationRejected(let report) {
            #expect(Set(report.offendingActivities) == Set(parents))
            #expect(report.nodes.filter { parents.contains($0.activityID) }.allSatisfy { $0.overflowMinutes == 120 })
        }
    }

    @Test func T10a必須11_一括検証失敗後の再読込で何も保存されない() async throws {
        let (f, parents, _) = try await overloaded()
        let before = try await f.store.loadBudgets()
        await #expect(throws: Week168ServiceError.self) {
            try await f.service.commitAllocation(week: f.week, committed: proposed(parents))
        }
        let reopened = Week168Store(container: try Week168Store.makeContainer(at: f.directory.appendingPathComponent("store.sqlite")))
        #expect(Set(try await reopened.loadBudgets().map { $0.activityID }) == Set(before.map { $0.activityID }))
        for entry in try await reopened.loadBudgets() { #expect(before.contains(entry)) }
        #expect(try await reopened.loadCommitment(for: f.week) == nil)
    }

    @Test func T10a必須12_予算行なしを含む一括確定は何も保存しない() async throws {
        let (f, parents, children) = try await overloaded()
        let missing = try await f.activity("予算なし")
        let before = try await f.store.loadBudgets()
        var values = proposed(parents + children)
        values[missing.id] = 0
        await #expect(throws: Week168ServiceError.self) {
            try await f.service.commitAllocation(week: f.week, committed: values)
        }
        #expect(try await f.store.loadBudgets() == before)
        #expect(try await f.store.loadCommitment(for: f.week) == nil)
    }

    @Test func T10a必須13_一括成功で全確定値と日時付き記録を永続化() async throws {
        let (f, parents, children) = try await overloaded()
        try await f.service.commitAllocation(week: f.week, committed: proposed(parents + children))
        let reopened = Week168Store(container: try Week168Store.makeContainer(at: f.directory.appendingPathComponent("store.sqlite")))
        let entries = try await reopened.loadBudgets()
        #expect(entries.count == 4)
        #expect(entries.allSatisfy { $0.committedMinutes == 600 && $0.wishMinutes == 720 && $0.direction == .goal })
        #expect(try await reopened.loadCommitment(for: f.week) == CommitmentRecord(week: f.week, committedAt: f.clock.now()))
    }

    @Test func T10a必須14_下書き検証は保存しない() async throws {
        let (f, parents, children) = try await overloaded()
        let before = try await f.store.loadBudgets()
        let report = try await f.service.previewAllocation(week: f.week, committed: proposed(parents + children))
        #expect(report.canCommit)
        #expect(report.totalCommittedMinutes == 1200)
        #expect(try await f.store.loadBudgets() == before)
        #expect(try await f.store.loadCommitment(for: f.week) == nil)
    }

    @Test func T10a必須16_制約違反中も希望は即時保存できる() async throws {
        let (f, parents, _) = try await overloaded()
        try await f.service.setWish(activityID: parents[0], minutes: 2000, direction: .cap, week: f.week)
        let entry = try #require(try await f.store.loadBudgets().first { $0.activityID == parents[0] })
        #expect(entry.wishMinutes == 2000)
        #expect(entry.direction == .cap)
        #expect(entry.committedMinutes == 720)
        #expect(try await f.service.allocationReport(for: f.week).report.capacityOverflowMinutes == 240)
    }

    @Test func 計測中の一括確定は候補値で通知を予約する() async throws {
        let (f, parents, children) = try await overloaded()
        _ = try await f.service.startOrSwitch(to: children[0])
        #expect(await f.alarms.budgets.isEmpty)
        try await f.service.commitAllocation(week: f.week, committed: proposed(parents + children))
        #expect(await f.alarms.budgets.last?.fireAt == f.clock.now().addingTimeInterval(600 * 60))
        await f.alarms.reset()
        try await f.service.uncommitAllocation(week: f.week)
        #expect(await f.alarms.budgets.isEmpty)
    }

    @Test func 過去週の確定変更も今週の継承予算で通知を更新する() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        let previous = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 7))
        try await f.commit(a.id, 600, week: previous)
        try await f.service.commitAllocation(week: f.week, committed: [:])
        _ = try await f.service.startOrSwitch(to: a.id)
        await f.alarms.reset()
        try await f.service.commitAllocation(week: previous, committed: [a.id: 120])
        #expect(await f.alarms.budgets.last?.fireAt == f.clock.now().addingTimeInterval(120 * 60))
    }

    @Test func 希望方向だけの変更も記録を消し同一値は記録を維持する() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.commit(a.id, 600)
        let record = try await f.store.loadCommitment(for: f.week)
        try await f.service.setWish(activityID: a.id, minutes: 600, direction: .cap, week: f.week)
        #expect(try await f.store.loadCommitment(for: f.week) == record)
        try await f.service.setWish(activityID: a.id, minutes: 600, direction: .goal, week: f.week)
        #expect(try await f.store.loadCommitment(for: f.week) == nil)
    }

    @Test func ホームは未使用と未確定を区別し両方で確定扱いしない() async throws {
        let f = try ServiceFixture()
        let unused = try await f.service.homeSections(recentLimit: 5)
        #expect(unused.state == .unused)
        #expect(!unused.isCommitted)
        _ = try await f.activity()
        let pending = try await f.service.homeSections(recentLimit: 5)
        #expect(pending.state == .pending)
        #expect(!pending.isCommitted)
    }
}
