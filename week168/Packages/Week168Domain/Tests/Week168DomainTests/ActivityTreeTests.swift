import Foundation
import Testing
import Week168Domain

@Suite("活動ツリー")
struct ActivityTreeTests {
    private func id(_ value: Int) -> ActivityID {
        ActivityID(rawValue: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!)
    }

    private func activity(
        _ value: Int, parent: Int? = nil, name: String = "Activity", order: Int = 0,
        mode: BudgetMode = .unset, archived: Bool = false
    ) -> Activity {
        Activity(
            id: id(value), name: name, parentID: parent.map { id($0) }, sortOrder: order,
            budgetMode: mode, defaultPlannedMinutes: nil, colorHex: "#123456", isArchived: archived
        )
    }

    private func threeLevels() throws -> ActivityTree {
        try ActivityTree.build(from: [activity(3, parent: 2), activity(1), activity(2, parent: 1)])
    }

    @Test("01: フラット配列から 2 階層を構築する")
    func buildTwoLevels() throws {
        let parent = activity(1)
        let child = activity(2, parent: 1)
        let tree = try ActivityTree.build(from: [child, parent])
        #expect(tree.node(parent.id) == parent)
        #expect(tree.node(child.id) == child)
        #expect(tree.children(of: parent.id) == [child])
        #expect(tree.ancestors(of: child.id) == [parent.id])
    }

    @Test("02: 3 階層の祖先は親から近い順で自分を含まない")
    func nearestAncestorsFirst() throws {
        #expect(try threeLevels().ancestors(of: id(3)) == [id(2), id(1)])
    }

    @Test("03: 存在しない親は missingParent")
    func missingParent() {
        #expect(throws: ActivityTree.BuildError.missingParent(id(1), parent: id(2))) {
            try ActivityTree.build(from: [activity(1, parent: 2)])
        }
    }

    @Test("04: 2 件の循環は停止して cycleDetected")
    func twoNodeCycle() {
        #expect(throws: ActivityTree.BuildError.cycleDetected(involving: [id(1), id(2)])) {
            try ActivityTree.build(from: [activity(1, parent: 2), activity(2, parent: 1)])
        }
    }

    @Test("05: 3 件の循環は cycleDetected")
    func threeNodeCycle() {
        #expect(throws: ActivityTree.BuildError.cycleDetected(involving: [id(1), id(2), id(3)])) {
            try ActivityTree.build(from: [activity(1, parent: 2), activity(2, parent: 3), activity(3, parent: 1)])
        }
    }

    @Test("06: 自己参照は cycleDetected")
    func selfCycle() {
        #expect(throws: ActivityTree.BuildError.cycleDetected(involving: [id(1)])) {
            try ActivityTree.build(from: [activity(1, parent: 1)])
        }
    }

    @Test("07: ID の重複は duplicateID")
    func duplicateID() {
        #expect(throws: ActivityTree.BuildError.duplicateID(id(1))) {
            try ActivityTree.build(from: [activity(1), activity(1, name: "Other")])
        }
    }

    @Test("08: 空配列から空のツリーを構築する")
    func emptyTree() throws {
        let tree = try ActivityTree.build(from: [])
        #expect(tree.topLevel().isEmpty)
        #expect(tree.children(of: nil).isEmpty)
        #expect(tree.node(id(1)) == nil)
        #expect(tree.ancestors(of: id(1)).isEmpty)
        #expect(tree.descendants(of: id(1)).isEmpty)
    }

    @Test("09: nil の子はトップレベルだけ")
    func topLevelChildren() throws {
        let root = activity(1, order: 1)
        let other = activity(4, order: 0)
        let tree = try ActivityTree.build(from: [root, activity(2, parent: 1), other])
        #expect(tree.children(of: nil) == [other, root])
        #expect(tree.topLevel() == tree.children(of: nil))
    }

    @Test("10: 同じ sortOrder の子は名前昇順")
    func sortByName() throws {
        let a = activity(2, parent: 1, name: "Alpha")
        let b = activity(3, parent: 1, name: "Beta")
        for input in [[activity(1), b, a], [a, b, activity(1)]] {
            #expect(try ActivityTree.build(from: input).children(of: id(1)) == [a, b])
        }
    }

    @Test("11: sortOrder は名前より優先する")
    func sortByOrder() throws {
        let first = activity(2, parent: 1, name: "Z", order: -1)
        let last = activity(3, parent: 1, name: "A", order: 1)
        let tree = try ActivityTree.build(from: [last, activity(1), first])
        #expect(tree.children(of: id(1)) == [first, last])
    }

    @Test("12: トップレベルの祖先は空")
    func rootAncestors() throws {
        #expect(try threeLevels().ancestors(of: id(1)).isEmpty)
    }

    @Test("13: 葉の子孫は空")
    func leafDescendants() throws {
        #expect(try threeLevels().descendants(of: id(3)).isEmpty)
    }

    @Test("14: 根の子孫に子と孫を含む")
    func rootDescendants() throws {
        #expect(try threeLevels().descendants(of: id(1)) == [id(2), id(3)])
    }

    @Test("15: 存在しない ID の node は nil")
    func unknownNode() throws {
        let tree = try threeLevels()
        #expect(tree.node(id(99)) == nil)
        #expect(tree.children(of: id(99)).isEmpty)
        #expect(tree.ancestors(of: id(99)).isEmpty)
        #expect(tree.descendants(of: id(99)).isEmpty)
    }

    @Test("16: 子を親に変更できない")
    func rejectChildParent() throws {
        #expect(try !threeLevels().canReparent(id(1), under: id(2)))
    }

    @Test("17: 孫を親に変更できない")
    func rejectGrandchildParent() throws {
        #expect(try !threeLevels().canReparent(id(1), under: id(3)))
    }

    @Test("18: 自分自身を親に変更できない")
    func rejectSelfParent() throws {
        #expect(try !threeLevels().canReparent(id(2), under: id(2)))
    }

    @Test("19: 無関係な活動を親に変更できる")
    func allowUnrelatedParent() throws {
        let tree = try ActivityTree.build(from: [activity(1), activity(2, parent: 1), activity(3)])
        #expect(tree.canReparent(id(2), under: id(3)))
    }

    @Test("20: nil への変更は常に可能")
    func allowTopLevel() throws {
        let tree = try threeLevels()
        for value in [1, 2, 3, 99] {
            #expect(tree.canReparent(id(value), under: nil))
        }
    }

    @Test("21: 予算未設定と予算対象外は異なる")
    func distinguishUnsetAndExcluded() throws {
        #expect(BudgetMode.unset != .excluded)
        #expect(BudgetMode.unset != .managed(.cap))
        #expect(BudgetMode.excluded != .managed(.goal))
        let unset = activity(1, mode: .unset)
        let excluded = activity(2, parent: 1, mode: .excluded)
        let tree = try ActivityTree.build(from: [unset, excluded])
        #expect(tree.node(id(1))?.budgetMode == .unset)
        #expect(tree.children(of: id(1)).first?.budgetMode == .excluded)
    }

    @Test("22: managed の cap と goal は異なる")
    func distinguishDirections() {
        #expect(BudgetMode.managed(.cap) != .managed(.goal))
        #expect(BudgetMode.managed(.cap) == .managed(.cap))
        #expect(BudgetMode.managed(.goal) == .managed(.goal))
    }

    @Test("23: アーカイブ済みの活動も保持する")
    func retainArchivedActivities() throws {
        let root = activity(1, archived: true)
        let child = activity(2, parent: 1, archived: true)
        let leaf = activity(3, parent: 2)
        let tree = try ActivityTree.build(from: [child, root, leaf])
        #expect(tree.node(root.id) == root)
        #expect(tree.node(child.id) == child)
        #expect(tree.topLevel() == [root])
        #expect(tree.children(of: root.id) == [child])
        #expect(tree.ancestors(of: leaf.id) == [child.id, root.id])
        #expect(tree.descendants(of: root.id) == [child.id, leaf.id])
    }

    @Test("循環へ流入する経路と別の正常な木があっても循環部分を検出する")
    func cycleAfterValidComponent() {
        #expect(throws: ActivityTree.BuildError.cycleDetected(involving: [id(2), id(3)])) {
            try ActivityTree.build(from: [
                activity(9), activity(10, parent: 9), activity(1, parent: 2),
                activity(2, parent: 3), activity(3, parent: 2)
            ])
        }
    }

    @Test("深い階層を再帰なしで構築・参照する")
    func deepHierarchy() throws {
        let count = 10_000
        let input = (1...count).reversed().map { activity($0, parent: $0 == 1 ? nil : $0 - 1) }
        let tree = try ActivityTree.build(from: input)
        #expect(tree.ancestors(of: id(count)) == (1..<count).reversed().map { id($0) })
        #expect(tree.descendants(of: id(1)) == (2...count).map { id($0) })
        #expect(!tree.canReparent(id(1), under: id(count)))
    }

    @Test("名前と順序が同じ場合も UUID 順で決定的に並ぶ")
    func deterministicTies() throws {
        let a = activity(2, parent: 1)
        let b = activity(3, parent: 1)
        for input in [[activity(1), b, a], [a, b, activity(1)]] {
            #expect(try ActivityTree.build(from: input).children(of: id(1)) == [a, b])
        }
    }

    @Test("分岐のある子孫は各兄弟の順序に従う先行順")
    func branchingDescendants() throws {
        let tree = try ActivityTree.build(from: [
            activity(5, parent: 4), activity(4, parent: 1, order: 1), activity(1),
            activity(3, parent: 2), activity(2, parent: 1)
        ])
        #expect(tree.descendants(of: id(1)) == [id(2), id(3), id(4), id(5)])
    }

    @Test("既存親への新規作成と祖先への移動を許可し、不明な親を拒否する")
    func reparentBoundaryCases() throws {
        let tree = try threeLevels()
        #expect(tree.canReparent(id(99), under: id(1)))
        #expect(tree.canReparent(id(3), under: id(1)))
        #expect(tree.canReparent(id(3), under: id(2)))
        #expect(!tree.canReparent(id(2), under: id(99)))
        #expect(!tree.canReparent(id(99), under: id(99)))
    }

    @Test("ID と予算方向は Codable で往復し、活動は全プロパティを保持する")
    func publicValueTypes() throws {
        let value = id(1)
        #expect(try JSONDecoder().decode(ActivityID.self, from: JSONEncoder().encode(value)) == value)
        #expect(Set([value, id(1), id(2)]).count == 2)
        for direction in [BudgetDirection.cap, .goal] {
            #expect(try JSONDecoder().decode(BudgetDirection.self, from: JSONEncoder().encode(direction)) == direction)
        }
        let original = activity(1)
        var changed = original
        #expect(changed == original)
        #expect(changed.defaultPlannedMinutes == nil)
        changed.name = "Changed"
        changed.parentID = id(2)
        changed.sortOrder = 7
        changed.budgetMode = .managed(.goal)
        changed.defaultPlannedMinutes = 30
        changed.colorHex = "#ABCDEF"
        changed.isArchived = true
        #expect(changed == Activity(
            id: original.id, name: "Changed", parentID: id(2), sortOrder: 7,
            budgetMode: .managed(.goal), defaultPlannedMinutes: 30,
            colorHex: "#ABCDEF", isArchived: true
        ))
        #expect(original != changed)
    }
}
