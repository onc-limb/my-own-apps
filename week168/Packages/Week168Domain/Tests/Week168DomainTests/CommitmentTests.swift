import Foundation
import Testing
import Week168Domain

struct CommitmentTests {
    private let week = LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 14))

    private func activity(parent: ActivityID? = nil, mode: BudgetMode = .managed) -> Activity {
        Activity(id: ActivityID(rawValue: UUID()), name: "活動", parentID: parent, sortOrder: 0,
                 budgetMode: mode, defaultPlannedMinutes: nil, colorHex: "", isArchived: false)
    }

    private func budget(_ id: ActivityID, _ minutes: Int?) -> BudgetEntry {
        BudgetEntry(activityID: id, effectiveFrom: week, direction: .cap,
                    wishMinutes: 720, committedMinutes: minutes)
    }

    @Test func T10a必須01_予算あり活動がなければ未使用() throws {
        let tree = try ActivityTree.build(from: [activity(mode: .unset), activity(mode: .excluded)])
        let report = AllocationValidator.report(tree: tree, budgets: BudgetResolver.resolve(
            week: week, entries: [], capacities: []), week: week)
        #expect(report.commitmentState(hasCommitmentRecord: false) == .unused)
        #expect(report.commitmentState(hasCommitmentRecord: true) == .unused)
    }

    @Test func T10a必須02_制約を満たしても記録なしなら未確定() throws {
        let tree = try ActivityTree.build(from: [activity()])
        let report = AllocationValidator.report(tree: tree, budgets: BudgetResolver.resolve(
            week: week, entries: [], capacities: []), week: week)
        #expect(report.canCommit)
        #expect(report.commitmentState(hasCommitmentRecord: false) == .pending)
    }

    @Test func T10a必須03_記録と制約充足で確定() throws {
        let a = activity()
        let tree = try ActivityTree.build(from: [a])
        let report = AllocationValidator.report(tree: tree, budgets: BudgetResolver.resolve(
            week: week, entries: [budget(a.id, 600)], capacities: []), week: week)
        #expect(report.commitmentState(hasCommitmentRecord: true) == .committed)
    }

    @Test func T10a必須15_nil候補は未入力に戻し他の値を維持() throws {
        let a = activity()
        let b = activity()
        let tree = try ActivityTree.build(from: [a, b])
        let budgets = BudgetResolver.resolve(week: week, entries: [budget(a.id, 600), budget(b.id, 120)], capacities: [])
        let report = AllocationValidator.reportApplying(tree: tree, budgets: budgets, week: week,
                                                        proposedCommitted: [a.id: nil])
        #expect(report.nodes.first { $0.activityID == a.id }?.committedMinutes == nil)
        #expect(report.totalCommittedMinutes == 120)
        #expect(budgets.budget(for: a.id)?.committedMinutes == 600)
    }

    @Test func T10a必須17_既存レポートと削減量の挙動を維持() throws {
        let parent = activity()
        let child = activity(parent: parent.id)
        let tree = try ActivityTree.build(from: [parent, child])
        let budgets = BudgetResolver.resolve(week: week, entries: [budget(parent.id, 600), budget(child.id, 720)],
                                             capacities: [CapacityEntry(effectiveFrom: week, totalMinutes: 540)])
        let report = AllocationValidator.report(tree: tree, budgets: budgets, week: week)
        #expect(report.capacityOverflowMinutes == 60)
        #expect(report.offendingActivities == [parent.id])
        #expect(report.nodes.first { $0.activityID == parent.id }?.overflowMinutes == 120)
        #expect(report.commitmentState(hasCommitmentRecord: true) == .pending)
        #expect(AllocationValidator.reportApplying(tree: tree, budgets: budgets, week: week, proposedCommitted: [:]) == report)
        let reduction = AllocationValidator.requiredReduction(tree: tree, budgets: budgets, parent: parent.id, newCommittedMinutes: 600)
        #expect(reduction.excessMinutes == 120)
        #expect(reduction.affectedChildren == [child.id])
    }
}
