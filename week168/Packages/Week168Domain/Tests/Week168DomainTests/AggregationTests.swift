import Foundation
import Testing
import Week168Domain

@Suite("集計とホーム構成")
struct AggregationTests {
    private func id(_ value: Int) -> ActivityID {
        ActivityID(rawValue: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!)
    }

    private let start = Date(timeIntervalSince1970: 0)
    private var interval: DateInterval { DateInterval(start: start, duration: 7 * 24 * 3600) }
    private var week: LogicalWeek { LogicalWeek(startDay: LogicalDay(year: 1970, month: 1, day: 1)) }

    private func activity(_ value: Int, parent: Int? = nil, mode: BudgetMode = .managed,
                          archived: Bool = false) -> Activity {
        Activity(id: id(value), name: "Activity \(value)", parentID: parent.map { id($0) },
                 sortOrder: value, budgetMode: mode, defaultPlannedMinutes: nil,
                 colorHex: "#123456", isArchived: archived)
    }

    private func entry(_ value: Int, seconds: Double, offset: Double = 0, running: Bool = false) -> TimeEntry {
        TimeEntry(id: EntryID(rawValue: UUID()), activityID: id(value),
                  startedAt: start.addingTimeInterval(offset),
                  endedAt: running ? nil : start.addingTimeInterval(offset + seconds),
                  plannedMinutes: nil, note: "")
    }

    private func budget(_ value: Int, _ minutes: Int?, direction: BudgetDirection = .cap) -> BudgetEntry {
        BudgetEntry(activityID: id(value), effectiveFrom: week, direction: direction,
                    wishMinutes: 999, committedMinutes: minutes)
    }

    private func summarize(_ activities: [Activity], _ entries: [TimeEntry] = [],
                           budgets: [BudgetEntry] = [], now: Date? = nil) throws -> [ActivityID: ActivitySummary] {
        Aggregator.summarize(entries: entries, tree: try ActivityTree.build(from: activities),
            budgets: BudgetResolver.resolve(week: week, entries: budgets, capacities: []),
            interval: interval, now: now ?? interval.end)
    }

    private func comparison(_ actual: Int, _ limit: Int?, direction: BudgetDirection = .cap) throws
        -> [ActivityID: ActivitySummary] {
        try summarize([activity(1)], [entry(1, seconds: Double(actual * 60))],
                      budgets: [budget(1, limit, direction: direction)])
    }

    private func compose(_ activities: [Activity], entries: [TimeEntry] = [], budgets: [BudgetEntry] = [],
                         lastUsed: [ActivityID: Date] = [:], limit: Int = 10, committed: Bool = true) throws -> HomeSections {
        HomeComposer.compose(tree: try ActivityTree.build(from: activities),
            summaries: try summarize(activities, entries, budgets: budgets),
            lastUsedAt: lastUsed, recentLimit: limit, isCommitted: committed)
    }

    private var development: [Activity] {
        [activity(1), activity(2, parent: 1), activity(3, parent: 1), activity(4, parent: 1)]
    }
    private var developmentEntries: [TimeEntry] {
        [entry(2, seconds: 120 * 60), entry(3, seconds: 300 * 60, offset: 120 * 60),
         entry(4, seconds: 120 * 60, offset: 420 * 60)]
    }

    @Test("01: 子の 120 + 300 + 120 分を親へ集計")
    func childrenTotal() throws {
        let result = try summarize(development, developmentEntries)
        #expect(result[id(1)]?.totalMinutes == 540)
        #expect(result[id(1)]?.ownMinutes == 0)
    }

    @Test("02: 親自身の 60 分も加算")
    func ownAndChildren() throws {
        let result = try summarize(development, developmentEntries + [entry(1, seconds: 3600, offset: 540 * 60)])
        #expect(result[id(1)]?.ownMinutes == 60)
        #expect(result[id(1)]?.totalMinutes == 600)
    }

    @Test("03: 孫の実績も根へ加算")
    func grandchildren() throws {
        let result = try summarize([activity(1), activity(2, parent: 1), activity(3, parent: 2)],
                                   [entry(3, seconds: 7200)])
        #expect(result[id(1)]?.totalMinutes == 120)
        #expect(result[id(2)]?.totalMinutes == 120)
        #expect(result[id(1)]?.ownMinutes == 0)
    }

    @Test("04: 90 秒 × 10 件 = 15 分")
    func fractionalRecords() throws {
        let result = try summarize([activity(1)], (0..<10).map { entry(1, seconds: 90, offset: Double($0 * 90)) })
        #expect(result[id(1)]?.totalMinutes == 15)
        #expect(result[id(1)]?.ownMinutes == 15)
    }

    @Test("05: 週の境界と重なる部分のみ集計")
    func weekBoundaries() throws {
        let result = try summarize([activity(1)], [entry(1, seconds: 7200, offset: -3600),
            entry(1, seconds: 7200, offset: interval.duration - 3600),
            entry(1, seconds: 60, offset: -60), entry(1, seconds: 60, offset: interval.duration)])
        #expect(result[id(1)]?.totalMinutes == 120)
    }

    @Test("06: 10:00 から進行中、now 11:30 なら 90 分")
    func runningUntilNow() throws {
        let result = try summarize([activity(1)], [entry(1, seconds: 0, offset: 36000, running: true)],
                                   now: start.addingTimeInterval(41400))
        #expect(result[id(1)]?.totalMinutes == 90)
    }

    @Test("07: 進行中でも期間終端で打ち切る")
    func runningUntilIntervalEnd() throws {
        let result = try summarize([activity(1)],
            [entry(1, seconds: 0, offset: interval.duration - 3600, running: true)],
            now: interval.end.addingTimeInterval(7200))
        #expect(result[id(1)]?.totalMinutes == 60)
    }

    @Test("08: 記録なしなら実績 0")
    func noEntries() throws {
        let result = try summarize([activity(1)])
        #expect(result[id(1)]?.ownMinutes == 0)
        #expect(result[id(1)]?.totalMinutes == 0)
    }

    @Test("09: 上限 540、実績 600 は超過 60")
    func capOverage() throws { #expect(try comparison(600, 540)[id(1)]?.deviationMinutes == 60) }

    @Test("10: 上限 540、実績 300 は問題なし")
    func belowCap() throws { #expect(try comparison(300, 540)[id(1)]?.deviationMinutes == 0) }

    @Test("11: 目標 480、実績 0 は不足 480")
    func goalShortfall() throws { #expect(try comparison(0, 480, direction: .goal)[id(1)]?.deviationMinutes == 480) }

    @Test("12: 目標 480、実績 600 は問題なし")
    func goalAchieved() throws { #expect(try comparison(600, 480, direction: .goal)[id(1)]?.deviationMinutes == 0) }

    @Test("13: 予算未設定は比較値なし")
    func unsetBudget() throws {
        for result in [try summarize([activity(1, mode: .unset)], budgets: [budget(1, 540)]),
                       try summarize([activity(1)])] {
            let summary = try #require(result[id(1)])
            #expect(summary.budgetMinutes == nil)
            #expect(summary.direction == nil)
            #expect(summary.deviationMinutes == nil)
            #expect(Aggregator.remainingMinutes(for: id(1), summaries: result) == nil)
        }
    }

    @Test("14: 対象外も実績あり、予算なし")
    func excludedBudget() throws {
        let result = try summarize([activity(1, mode: .excluded)], [entry(1, seconds: 3600)], budgets: [budget(1, 540)])
        #expect(result[id(1)]?.totalMinutes == 60)
        #expect(result[id(1)]?.budgetMinutes == nil)
        #expect(result[id(1)]?.direction == nil)
        #expect(result[id(1)]?.deviationMinutes == nil)
    }

    @Test("15: 確定値未入力なら予算なし")
    func missingCommitment() throws {
        let result = try comparison(300, nil)
        #expect(result[id(1)]?.budgetMinutes == nil)
        #expect(result[id(1)]?.deviationMinutes == nil)
        #expect(Aggregator.remainingMinutes(for: id(1), summaries: result) == nil)
    }

    @Test("16: 上限残り 240")
    func positiveRemaining() throws {
        #expect(try Aggregator.remainingMinutes(for: id(1), summaries: comparison(300, 540)) == 240)
    }

    @Test("17: 超過時の残りは -60")
    func negativeRemaining() throws {
        #expect(try Aggregator.remainingMinutes(for: id(1), summaries: comparison(600, 540)) == -60)
    }

    @Test("18: 対象外の子も親の実績に含むが枠は消費しない")
    func excludedChildActual() throws {
        let activities = [activity(1), activity(2, parent: 1, mode: .excluded)]
        let budgets = [budget(1, 540), budget(2, 9000)]
        let result = try summarize(activities, [entry(2, seconds: 600 * 60)], budgets: budgets)
        #expect(result[id(1)]?.totalMinutes == 600)
        #expect(result[id(1)]?.ownMinutes == 0)
        #expect(result[id(2)]?.budgetMinutes == nil)
        let report = AllocationValidator.report(tree: try ActivityTree.build(from: activities),
            budgets: BudgetResolver.resolve(week: week, entries: budgets, capacities: []), week: week)
        #expect(report.totalCommittedMinutes == 540)
        #expect(report.nodes.first?.childrenCommittedMinutes == 0)
    }

    @Test("19: 対象外の子の実績も親の超過判定に含む")
    func excludedChildDeviation() throws {
        let result = try summarize([activity(1), activity(2, parent: 1, mode: .excluded)],
                                   [entry(2, seconds: 600 * 60)], budgets: [budget(1, 540)])
        #expect(result[id(1)]?.deviationMinutes == 60)
        #expect(Aggregator.remainingMinutes(for: id(1), summaries: result) == -60)
    }

    @Test("20: 未達は英語 480、アーキテクチャ 120 の順")
    func goalsByShortfall() throws {
        let result = try compose([activity(1), activity(2)], entries: [entry(1, seconds: 3600)],
                                 budgets: [budget(1, 180, direction: .goal), budget(2, 480, direction: .goal)])
        #expect(result.unmetGoals == [id(2), id(1)])
    }

    @Test("21: 達成済みの目標を除く")
    func achievedGoalHidden() throws {
        let result = try compose([activity(1)], entries: [entry(1, seconds: 480 * 60)],
                                 budgets: [budget(1, 480, direction: .goal)])
        #expect(result.unmetGoals.isEmpty)
    }

    @Test("22: 上限超過は未達目標に含めない")
    func exceededCapHidden() throws {
        let result = try compose([activity(1)], entries: [entry(1, seconds: 600 * 60)], budgets: [budget(1, 540)])
        #expect(result.unmetGoals.isEmpty)
    }

    @Test("23: 未確定なら予算判定しない")
    func uncommittedGoalsHidden() throws {
        let result = try compose([activity(1)], budgets: [budget(1, 480, direction: .goal)],
                                 lastUsed: [id(1): start], committed: false)
        #expect(result.unmetGoals.isEmpty)
        #expect(result.recentlyUsed == [id(1)])
        #expect(result.weeklyProgress == [id(1)])
    }

    @Test("24: 最近使った順")
    func recentOrder() throws {
        let result = try compose([activity(1), activity(2), activity(3)],
            lastUsed: [id(1): start, id(2): start.addingTimeInterval(60)])
        #expect(result.recentlyUsed == [id(2), id(1)])
    }

    @Test("25: 最近の 5 件を 3 件に制限")
    func recentLimit() throws {
        let result = try compose((1...5).map { activity($0) },
            lastUsed: Dictionary(uniqueKeysWithValues: (1...5).map { (id($0), start.addingTimeInterval(Double($0))) }), limit: 3)
        #expect(result.recentlyUsed == [id(5), id(4), id(3)])
    }

    @Test("26: アーカイブ済みを最近と未達から除く")
    func archivedSections() throws {
        let result = try compose([activity(1, archived: true)], budgets: [budget(1, 480, direction: .goal)],
                                 lastUsed: [id(1): start])
        #expect(result.recentlyUsed.isEmpty)
        #expect(result.unmetGoals.isEmpty)
    }

    @Test("27: アーカイブ済みも 1 分以上の実績があれば週次に含む")
    func archivedWithActual() throws {
        let result = try compose([activity(1, archived: true)], entries: [entry(1, seconds: 60)])
        #expect(result.weeklyProgress == [id(1)])
    }

    @Test("28: アーカイブ済みの実績 0 は週次から除く")
    func archivedWithoutActual() throws {
        let result = try compose([activity(1, archived: true)])
        #expect(result.weeklyProgress.isEmpty)
    }

    @Test("29: 週次は深さ優先の先行順")
    func weeklyPreorder() throws {
        let result = try compose([activity(2), activity(4, parent: 1), activity(5, parent: 3),
                                  activity(3, parent: 1), activity(1)])
        #expect(result.weeklyProgress == [id(1), id(3), id(5), id(4), id(2)])
    }

    @Test("子孫間の小数秒も親で合算してから分へ変換")
    func fractionalDescendants() throws {
        let result = try summarize([activity(1), activity(2, parent: 1), activity(3, parent: 2)],
            [entry(1, seconds: 19.5), entry(2, seconds: 20.25, offset: 19.5),
             entry(3, seconds: 20.25, offset: 39.75)])
        #expect(result[id(1)]?.ownMinutes == 0)
        #expect(result[id(2)]?.totalMinutes == 0)
        #expect(result[id(1)]?.totalMinutes == 1)
    }

    @Test("未達の不足同値と使用日時同値は階層順")
    func tiedHomeOrder() throws {
        let result = try compose([activity(2), activity(3, parent: 1), activity(1)],
            budgets: [budget(1, 60, direction: .goal), budget(2, 60, direction: .goal), budget(3, 60, direction: .goal)],
            lastUsed: [id(1): start, id(2): start, id(3): start])
        #expect(result.unmetGoals == [id(1), id(3), id(2)])
        #expect(result.recentlyUsed == [id(1), id(3), id(2)])
    }

    @Test("目標の残りも符号付き、予算と実績が同値なら偏差 0")
    func goalRemainingAndEquality() throws {
        for direction in [BudgetDirection.cap, .goal] {
            let equal = try comparison(480, 480, direction: direction)
            #expect(equal[id(1)]?.deviationMinutes == 0)
            #expect(Aggregator.remainingMinutes(for: id(1), summaries: equal) == 0)
        }
        #expect(try Aggregator.remainingMinutes(for: id(1), summaries: comparison(300, 480, direction: .goal)) == 180)
        #expect(try Aggregator.remainingMinutes(for: id(1), summaries: comparison(600, 480, direction: .goal)) == -120)
        #expect(Aggregator.remainingMinutes(for: id(99), summaries: [:]) == nil)
    }

    @Test("過去週の確定予算と方向を使う")
    func historicalBudget() throws {
        let later = BudgetEntry(activityID: id(1), effectiveFrom: LogicalWeek(startDay: LogicalDay(year: 1970, month: 1, day: 8)),
                                direction: .cap, wishMinutes: 999, committedMinutes: 100)
        let result = try summarize([activity(1)], budgets: [later, budget(1, 480, direction: .goal)])
        #expect(result[id(1)]?.budgetMinutes == 480)
        #expect(result[id(1)]?.direction == .goal)
        #expect(result[id(1)]?.deviationMinutes == 480)
    }

    @Test("アーカイブ親は子の実績でも週次に表示、1 分未満は非表示")
    func archivedDescendantActual() throws {
        let result = try compose([activity(1, archived: true), activity(2, parent: 1), activity(3, archived: true)],
                                 entries: [entry(2, seconds: 60), entry(3, seconds: 59)])
        #expect(result.weeklyProgress == [id(1), id(2)])
    }

    @Test("F-1: 実績 0 のアーカイブ親も実績のある現役の子と階層順に表示")
    func archivedZeroParentWithActiveChild() throws {
        let tree = try ActivityTree.build(from: [activity(2, parent: 1), activity(1, archived: true)])
        // Supply summaries directly to exercise the review's zero-total parent input.
        let summaries = [
            id(1): ActivitySummary(activityID: id(1), ownMinutes: 0, totalMinutes: 0,
                                   budgetMinutes: nil, direction: nil),
            id(2): ActivitySummary(activityID: id(2), ownMinutes: 60, totalMinutes: 60,
                                   budgetMinutes: nil, direction: nil)
        ]
        let result = HomeComposer.compose(tree: tree, summaries: summaries,
            lastUsedAt: [id(1): start, id(2): start], recentLimit: 10, isCommitted: true)
        #expect(result.weeklyProgress == [id(1), id(2)])
        #expect(result.recentlyUsed == [id(2)])
    }

    @Test("F-1: 実績なしの現役の孫も全祖先を表示し、不要なアーカイブ兄弟は除く")
    func activeGrandchildIncludesAllAncestors() throws {
        let result = try compose([
            activity(5), activity(4, parent: 2, archived: true), activity(3, parent: 2),
            activity(2, parent: 1, archived: true), activity(1, archived: true)
        ])
        #expect(result.weeklyProgress == [id(1), id(2), id(3), id(5)])
    }

    @Test("空ツリーと非正の最近件数制限")
    func emptyAndNonpositiveLimit() throws {
        #expect(try compose([]) == HomeSections(unmetGoals: [], recentlyUsed: [], weeklyProgress: []))
        for limit in [0, -1] {
            #expect(try compose([activity(1)], lastUsed: [id(1): start], limit: limit).recentlyUsed.isEmpty)
        }
    }
}
