import Testing
import Week168Domain
import Week168UseCases

struct ActivityTests {
    @Test func 必須25_循環しない親で活動作成が成功() async throws {
        let f = try ServiceFixture()
        let parent = try await f.activity("親")
        let child = try await f.activity("子", parent: parent.id)
        #expect(child.parentID == parent.id)
        #expect(try await f.store.loadActivities().contains(child))
    }

    @Test func 必須26_対象外の子に予算ありを作ると失敗し未保存() async throws {
        let f = try ServiceFixture()
        let parent = try await f.activity(mode: .excluded)
        await #expect(throws: ActivityTree.BuildError.self) {
            try await f.activity(parent: parent.id, mode: .managed)
        }
        #expect(try await f.store.loadActivities() == [parent])
    }

    @Test func 必須27_活動削除は子と記録の削除件数を返す() async throws {
        let f = try ServiceFixture()
        let parent = try await f.activity("親")
        let child = try await f.activity("子", parent: parent.id)
        let grandchild = try await f.activity("孫", parent: child.id)
        try await f.history(child.id, minutes: 10)
        _ = try await f.service.startOrSwitch(to: grandchild.id)
        let deleted = try await f.service.deleteActivity(parent.id)
        #expect(deleted.children == 2)
        #expect(deleted.entries == 2)
        #expect(try await f.store.loadActivities().isEmpty)
        #expect(try await f.entries().isEmpty)
    }

    @Test func 必須28_並替はソート順を振り直して保存() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity("一")
        let b = try await f.activity("二")
        let c = try await f.activity("三")
        try await f.service.reorderActivities([c.id, a.id, b.id], under: nil)
        let saved = try await f.store.loadActivities()
        #expect(saved.map(\.id) == [c.id, a.id, b.id])
        #expect(saved.map(\.sortOrder) == [0, 1, 2])
    }

    @Test func 必須29_アーカイブは状態を保存して過去実績を保持() async throws {
        let f = try ServiceFixture()
        let a = try await f.activity()
        try await f.history(a.id, minutes: 45)
        let before = try await f.entries()
        try await f.service.archiveActivity(a.id, archived: true)
        #expect(try await f.store.loadActivities().first?.isArchived == true)
        #expect(try await f.entries() == before)
        #expect(try await f.service.weeklyReport(for: f.week)[a.id]?.totalMinutes == 45)
        let home = try await f.service.homeSections(recentLimit: 5)
        #expect(home.sections.recentlyUsed.isEmpty)
        #expect(home.sections.weeklyProgress == [a.id])
    }
}
