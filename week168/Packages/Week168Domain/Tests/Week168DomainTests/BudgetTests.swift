import Foundation
import Testing
import Week168Domain

@Suite("予算と配分")
struct BudgetTests {
    private func id(_ value: Int) -> ActivityID {
        ActivityID(rawValue: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!)
    }

    private func week(_ value: Int) -> LogicalWeek {
        LogicalWeek(startDay: LogicalDay(year: 2026, month: 9, day: 1 + value * 7))
    }

    private func activity(
        _ value: Int, parent: Int? = nil, name: String = "Activity",
        mode: BudgetMode = .managed, archived: Bool = false
    ) -> Activity {
        Activity(id: id(value), name: name, parentID: parent.map { id($0) }, sortOrder: value,
                 budgetMode: mode, defaultPlannedMinutes: nil, colorHex: "#123456", isArchived: archived)
    }

    private func entry(_ value: Int, _ minutes: Int?, wish: Int? = nil, from: Int = 1) -> BudgetEntry {
        BudgetEntry(activityID: id(value), effectiveFrom: week(from), direction: value == 5 ? .goal : .cap,
                    wishMinutes: wish ?? minutes ?? 0, committedMinutes: minutes)
    }

    private var activities: [Activity] {
        [activity(1, name: "開発"), activity(2, parent: 1, name: "Week168"),
         activity(3, parent: 1, name: "climbinsight"), activity(4, parent: 1, name: "onclimb-industries"),
         activity(5, name: "勉強", mode: .managed), activity(6, parent: 5, name: "アーキテクチャ"),
         activity(7, parent: 5, name: "英語"), activity(8, name: "クライミング", mode: .excluded)]
    }

    private var entries: [BudgetEntry] {
        [entry(1, 540), entry(2, 120), entry(3, 300), entry(4, 120),
         entry(5, 780), entry(6, 180), entry(7, 600)]
    }

    private func resolved(_ values: [BudgetEntry], capacity: Int? = 1200) -> ResolvedBudgets {
        BudgetResolver.resolve(week: week(1), entries: values,
                               capacities: [CapacityEntry(effectiveFrom: week(1), totalMinutes: capacity)])
    }

    private func report(
        _ values: [BudgetEntry]? = nil, activities input: [Activity]? = nil, capacity: Int? = 1200
    ) throws -> AllocationReport {
        AllocationValidator.report(tree: try ActivityTree.build(from: input ?? activities),
                                   budgets: resolved(values ?? entries, capacity: capacity), week: week(1))
    }

    private func node(_ value: Int, in report: AllocationReport) throws -> AllocationNode {
        try #require(report.nodes.first { $0.activityID == id(value) })
    }

    private func history(_ target: Int, reversed: Bool = false) -> ResolvedBudgets {
        let values = [entry(1, 600), entry(1, 480, from: 3)]
        return BudgetResolver.resolve(week: week(target), entries: reversed ? values.reversed() : values, capacities: [])
    }

    @Test("01: W1 は 600") func firstWeek() { #expect(history(1).budget(for: id(1))?.committedMinutes == 600) }
    @Test("02: W2 は W1 の 600 を継承") func inheritedWeek() { #expect(history(2).budget(for: id(1))?.committedMinutes == 600) }
    @Test("03: W3 は 480") func changedWeek() { #expect(history(3).budget(for: id(1))?.committedMinutes == 480) }
    @Test("04: W4 は 480 を継承") func laterWeek() { #expect(history(4).budget(for: id(1))?.committedMinutes == 480) }
    @Test("05: W0 は予算なし") func beforeHistory() { #expect(history(0).budget(for: id(1)) == nil) }

    @Test("06: 総枠も変更週から引き継ぐ")
    func capacityHistory() {
        let capacities = [CapacityEntry(effectiveFrom: week(1), totalMinutes: 600),
                          CapacityEntry(effectiveFrom: week(3), totalMinutes: 480)]
        let expected: [Int?] = [nil, 600, 600, 480, 480]
        for index in 0...4 {
            let result = BudgetResolver.resolve(week: week(index), entries: [], capacities: capacities)
            #expect(result.capacityMinutes == expected[index])
            #expect(result.week == week(index))
        }
    }

    @Test("07: 順不同でも同じ解決結果")
    func unorderedHistory() {
        for index in 0...4 {
            #expect(history(index, reversed: true).budget(for: id(1)) == history(index).budget(for: id(1)))
        }
        let capacities = [CapacityEntry(effectiveFrom: week(3), totalMinutes: 480),
                          CapacityEntry(effectiveFrom: week(1), totalMinutes: 600)]
        #expect(BudgetResolver.resolve(week: week(4), entries: [], capacities: capacities).capacityMinutes == 480)
    }

    @Test("08: 実データは 1320、総枠超過 120、確定不可")
    func realOverflow() throws {
        let result = try report()
        #expect(result.totalCommittedMinutes == 1320)
        #expect(result.capacityMinutes == 1200)
        #expect(result.capacityOverflowMinutes == 120)
        #expect(!result.canCommit)
    }

    @Test("09: 開発と勉強の子の合計は親と一致")
    func balancedParents() throws {
        let result = try report()
        #expect(try node(1, in: result).overflowMinutes == 0)
        #expect(try node(5, in: result).overflowMinutes == 0)
    }

    @Test("10: 総枠だけの超過なら違反活動は空")
    func capacityOnlyOffenders() throws { #expect(try report().offendingActivities.isEmpty) }

    private var reducedEntries: [BudgetEntry] {
        entries.map { value in
            var value = value
            if value.activityID == id(5) { value.committedMinutes = 660 }
            if value.activityID == id(7) { value.committedMinutes = 480 }
            return value
        }
    }

    @Test("11: 英語 480、勉強 660 で総枠 1200 に収まる")
    func reducedCommitments() throws {
        let result = try report(reducedEntries)
        #expect(result.totalCommittedMinutes == 1200)
        #expect(result.capacityOverflowMinutes == 0)
        #expect(result.canCommit)
    }

    @Test("12: 希望 1320、超過 120 のまま確定できる")
    func independentWishes() throws {
        let result = try report(reducedEntries)
        #expect(result.totalWishMinutes == 1320)
        #expect(result.wishOverflowMinutes == 120)
        #expect(try node(7, in: result).wishMinutes == 600)
        #expect(try node(5, in: result).wishMinutes == 780)
        #expect(result.canCommit)
    }

    @Test("13: 開発 540 に子 300 + 300 は 60 超過")
    func parentOverflow() throws {
        let result = try report([entry(1, 540), entry(2, 300), entry(3, 300)])
        #expect(try node(1, in: result).overflowMinutes == 60)
        #expect(try node(1, in: result).unallocatedMinutes == -60)
        #expect(!result.canCommit)
        #expect(result.offendingActivities == [id(1)])
    }

    @Test("14: 孫の合計が子を超える")
    func grandchildOverflow() throws {
        let result = try report([entry(1, 540), entry(2, 120), entry(3, 180)],
                                activities: [activity(1), activity(2, parent: 1), activity(3, parent: 2)])
        #expect(try node(2, in: result).overflowMinutes == 60)
        #expect(!result.canCommit)
    }

    @Test("15: 親子の超過 ID は入力順によらずツリー順")
    func stableOffenders() throws {
        let input = [activity(1), activity(2, parent: 1), activity(3, parent: 2)]
        for ordered in [input, input.reversed()] {
            let result = try report([entry(1, 120), entry(2, 180), entry(3, 300)], activities: ordered)
            #expect(result.offendingActivities == [id(1), id(2)])
            #expect(!result.canCommit)
        }
    }

    private var unsetChildActivities: [Activity] {
        activities.map { value in
            var value = value
            if value.id == id(4) { value.budgetMode = .unset }
            return value
        }
    }

    @Test("16: 未設定の子に残り 120 を共有する")
    func unallocatedShare() throws {
        #expect(try node(1, in: report(activities: unsetChildActivities)).unallocatedMinutes == 120)
    }

    @Test("17: 未設定の子に過去の予算があっても合計は 420")
    func unsetConsumesNothing() throws {
        let result = try report(activities: unsetChildActivities)
        #expect(try node(1, in: result).childrenCommittedMinutes == 420)
        #expect(try node(4, in: result).committedMinutes == nil)
        #expect(try node(4, in: result).wishMinutes == nil)
    }

    @Test("18: 予算なしの未配分は nil")
    func noBudgetRemainder() throws {
        let result = try report(activities: unsetChildActivities)
        #expect(try node(4, in: result).unallocatedMinutes == nil)
        #expect(try node(8, in: result).unallocatedMinutes == nil)
    }

    @Test("19: 対象外のトップレベルは希望も確定も消費しない")
    func excludedRoot() throws {
        let result = try report(entries + [entry(8, 9000)])
        #expect(result.totalCommittedMinutes == 1320)
        #expect(result.totalWishMinutes == 1320)
        #expect(try node(8, in: result).committedMinutes == nil)
    }

    @Test("20: 対象外の子は親の枠を消費しない")
    func excludedChild() throws {
        let input = activities + [activity(9, parent: 1, mode: .excluded)]
        let result = try report(entries + [entry(9, 9000)], activities: input)
        #expect(try node(1, in: result).childrenCommittedMinutes == 540)
        #expect(try node(1, in: result).overflowMinutes == 0)
    }

    @Test("21: managed の確定 nil は 0 として確定を許可")
    func nilCommitment() throws {
        let result = try report([entry(1, nil, wish: 540), entry(2, nil, wish: 120)],
                                activities: [activity(1), activity(2, parent: 1)])
        #expect(result.totalCommittedMinutes == 0)
        #expect(try node(1, in: result).childrenCommittedMinutes == 0)
        #expect(result.canCommit)
    }

    @Test("22: 未入力はノードでも nil を維持")
    func preserveNil() throws {
        let result = try report([entry(1, nil, wish: 540)], activities: [activity(1)])
        #expect(try node(1, in: result).committedMinutes == nil)
        #expect(try node(1, in: result).wishMinutes == 540)
    }

    @Test("23: 総枠なしなら 1320 を確定できる")
    func unlimitedCapacity() throws {
        let result = try report(capacity: nil)
        #expect(result.totalCommittedMinutes == 1320)
        #expect(result.capacityOverflowMinutes == 0)
        #expect(result.wishOverflowMinutes == 0)
        #expect(result.canCommit)
    }

    @Test("24: 開発を 360 に縮小するには 180 減らす")
    func requiredShrink() throws {
        let result = AllocationValidator.requiredReduction(tree: try ActivityTree.build(from: activities),
            budgets: resolved(entries), parent: id(1), newCommittedMinutes: 360)
        #expect(result.excessMinutes == 180)
        #expect(result.affectedChildren == [id(2), id(3), id(4)])
    }

    @Test("25: 開発を 600 に増やすなら削減不要")
    func noReduction() throws {
        let result = AllocationValidator.requiredReduction(tree: try ActivityTree.build(from: activities),
            budgets: resolved(entries), parent: id(1), newCommittedMinutes: 600)
        #expect(result.excessMinutes == 0)
        #expect(result.affectedChildren.isEmpty)
    }

    @Test("26: 削減の対象は managed の子のみ")
    func reductionModes() throws {
        let input = unsetChildActivities + [activity(9, parent: 1, mode: .excluded)]
        let result = AllocationValidator.requiredReduction(tree: try ActivityTree.build(from: input),
            budgets: resolved(entries + [entry(9, 9000)]), parent: id(1), newCommittedMinutes: 360)
        #expect(result.excessMinutes == 60)
        #expect(result.affectedChildren == [id(2), id(3)])
    }

    @Test("27: 対象外の子が managed なら拒否")
    func managedUnderExcluded() {
        #expect(throws: ActivityTree.BuildError.budgetUnderExcluded(id(2), ancestor: id(1))) {
            try ActivityTree.build(from: [activity(1, mode: .excluded), activity(2, parent: 1)])
        }
    }

    @Test("28: 対象外の孫が managed でも拒否")
    func managedGrandchildUnderExcluded() {
        #expect(throws: ActivityTree.BuildError.budgetUnderExcluded(id(3), ancestor: id(1))) {
            try ActivityTree.build(from: [activity(3, parent: 2), activity(2, parent: 1, mode: .unset),
                                          activity(1, mode: .excluded)])
        }
    }

    @Test("29: 対象外配下の unset と excluded は許可")
    func nonManagedUnderExcluded() throws {
        let tree = try ActivityTree.build(from: [activity(1, mode: .excluded),
            activity(2, parent: 1, mode: .unset), activity(3, parent: 2, mode: .excluded)])
        #expect(tree.descendants(of: id(1)) == [id(2), id(3)])
    }

    @Test("S-12: アーカイブ済みの親子も同じ予算計算に含む")
    func archivedBudgets() throws {
        let input = activities.map { value in
            var value = value
            value.isArchived = true
            return value
        }
        #expect(try report(activities: input) == report())
    }

    @Test("後の nil は古い総枠と確定値を解除する")
    func clearedHistory() {
        let result = BudgetResolver.resolve(week: week(4),
            entries: [entry(1, nil, wish: 900, from: 3), entry(1, 600), entry(2, 120)],
            capacities: [CapacityEntry(effectiveFrom: week(3), totalMinutes: nil),
                         CapacityEntry(effectiveFrom: week(1), totalMinutes: 1200)])
        #expect(result.capacityMinutes == nil)
        #expect(result.budget(for: id(1)) == entry(1, nil, wish: 900, from: 3))
        #expect(result.budget(for: id(2)) == entry(2, 120))
    }

    @Test("希望が非常に大きくても確定を制約しない")
    func largeWish() throws {
        let result = try report([entry(1, 540, wish: Int.max)], activities: [activity(1)])
        #expect(result.canCommit)
        #expect(result.wishOverflowMinutes == Int.max - 1200)
    }

    @Test("週次の方向を表示に反映する")
    func resolvedDirection() throws {
        var value = entry(1, 540)
        value.direction = .goal
        let result = try node(1, in: report([value], activities: [activity(1)]))
        #expect(result.mode == .managed)
        #expect(result.direction == .goal)
    }


    @Test("方向を目標から上限に変更しても過去週の方向を保持する")
    func historicalDirection() throws {
        let tree = try ActivityTree.build(from: [activity(7, name: "英語")])
        var goal = entry(7, 600, from: 1)
        goal.direction = .goal
        let cap = entry(7, 480, from: 3)
        // 新しいレコードを含む同一履歴から、過去・現在の各週を解決する。
        for (index, direction, minutes) in [(1, BudgetDirection.goal, 600), (2, .goal, 600),
                                             (3, .cap, 480), (4, .cap, 480)] {
            let budgets = BudgetResolver.resolve(week: week(index), entries: [cap, goal], capacities: [])
            let result = AllocationValidator.report(tree: tree, budgets: budgets, week: week(index))
            let english = try node(7, in: result)
            #expect(english.mode == .managed)
            #expect(english.direction == direction)
            #expect(english.committedMinutes == minutes)
            #expect(result.canCommit)
        }
        let before = BudgetResolver.resolve(week: week(0), entries: [cap, goal], capacities: [])
        let result = AllocationValidator.report(tree: tree, budgets: before, week: week(0))
        #expect(try node(7, in: result).direction == nil)
    }

    @Test("レコードなしの managed は未入力として扱う")
    func missingManagedEntry() throws {
        let result = try report([], activities: [activity(1)])
        #expect(result.canCommit)
        #expect(try node(1, in: result).wishMinutes == nil)
        #expect(try node(1, in: result).committedMinutes == nil)
        #expect(try node(1, in: result).direction == nil)
    }

    @Test("未入力の親も子の確定値に対して INV-1 を検証する")
    func nilParentWithCommittedChild() throws {
        let result = try report([entry(1, nil), entry(2, 120)],
                                activities: [activity(1), activity(2, parent: 1)])
        #expect(try node(1, in: result).overflowMinutes == 120)
        #expect(!result.canCommit)
    }

    @Test("同週の重複レコードは最後を採用する")
    func duplicateEffectiveWeek() {
        let result = BudgetResolver.resolve(week: week(1), entries: [entry(1, 600), entry(1, 480)],
            capacities: [CapacityEntry(effectiveFrom: week(1), totalMinutes: 1200),
                         CapacityEntry(effectiveFrom: week(1), totalMinutes: nil)])
        #expect(result.budget(for: id(1))?.committedMinutes == 480)
        #expect(result.capacityMinutes == nil)
    }
}
