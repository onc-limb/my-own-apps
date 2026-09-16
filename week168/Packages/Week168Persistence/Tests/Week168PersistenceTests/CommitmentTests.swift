import Foundation
import Testing
@testable import Week168Persistence
import Week168Domain

struct CommitmentTests {
    private let week = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 14))
    private let instant = Date(timeIntervalSince1970: 123456)

    private func budget(_ id: ActivityID, week: LogicalWeek, minutes: Int = 720) -> BudgetEntry {
        BudgetEntry(activityID: id, effectiveFrom: week, direction: .goal,
                    wishMinutes: 720, committedMinutes: minutes)
    }

    @Test func 確定記録は週ごとに更新と削除と再読込ができる() async throws {
        let disk = try DiskFixture()
        let record = CommitmentRecord(week: week, committedAt: instant)
        try await disk.store!.saveCommitment(record)
        try await disk.store!.saveCommitment(CommitmentRecord(week: week, committedAt: instant.addingTimeInterval(1)))
        try disk.reopen()
        #expect(try await disk.store!.loadCommitment(for: week)?.committedAt == instant.addingTimeInterval(1))
        try await disk.store!.deleteCommitment(for: week)
        try disk.reopen()
        #expect(try await disk.store!.loadCommitment(for: week) == nil)
    }

    @Test func 保存失敗時は全予算と既存確定記録をロールバックする() async throws {
        let disk = try DiskFixture()
        let ids = [ActivityID(rawValue: UUID()), ActivityID(rawValue: UUID())]
        for id in ids { try await disk.store!.upsertBudget(budget(id, week: week)) }
        let original = CommitmentRecord(week: week, committedAt: instant)
        try await disk.store!.saveCommitment(original)
        await disk.store!.failNextSaves(3)
        await #expect(throws: PersistenceError.self) {
            try await disk.store!.commitAllocation(week: week, committed: [ids[0]: 600, ids[1]: 600], at: instant.addingTimeInterval(1))
        }
        #expect(try await disk.store!.loadBudgets().allSatisfy { $0.committedMinutes == 720 })
        #expect(try await disk.store!.loadCommitment(for: week) == original)
        try disk.reopen()
        #expect(try await disk.store!.loadBudgets().allSatisfy { $0.committedMinutes == 720 })
        #expect(try await disk.store!.loadCommitment(for: week) == original)
    }

    @Test func 予算行なしを含むストア直接確定も全体をロールバックする() async throws {
        let disk = try DiskFixture()
        let id = ActivityID(rawValue: UUID())
        let original = budget(id, week: week)
        try await disk.store!.upsertBudget(original)
        await #expect(throws: PersistenceError.self) {
            try await disk.store!.commitAllocation(week: week,
                committed: [id: 600, ActivityID(rawValue: UUID()): 600], at: instant)
        }
        #expect(try await disk.store!.loadBudgets() == [original])
        #expect(try await disk.store!.loadCommitment(for: week) == nil)
        try disk.reopen()
        #expect(try await disk.store!.loadBudgets() == [original])
        #expect(try await disk.store!.loadCommitment(for: week) == nil)
    }

    @Test func 継承予算の一括確定は過去を維持し一回だけ保存する() async throws {
        let disk = try DiskFixture()
        let id = ActivityID(rawValue: UUID())
        let previous = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 7))
        let original = budget(id, week: previous)
        try await disk.store!.upsertBudget(original)
        await disk.store!.requireSingleSave()
        try await disk.store!.commitAllocation(week: week, committed: [id: nil], at: instant)
        let entries = try await disk.store!.loadBudgets()
        #expect(entries.count == 2)
        #expect(entries.contains(original))
        #expect(entries.first { $0.effectiveFrom == week }?.committedMinutes == nil)
        #expect(try await disk.store!.loadCommitment(for: week)?.committedAt == instant)
        #expect(try await disk.store!.loadCommitment(for: previous) == nil)
    }
}

extension Week168Store {
    func requireSingleSave() {
        var count = 0
        saveOperation = { context in
            count += 1
            #expect(count == 1)
            try context.save()
        }
    }
}
