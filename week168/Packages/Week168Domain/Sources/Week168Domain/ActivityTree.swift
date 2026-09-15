/// 構築時に親の存在・ID の一意性・循環を検証した活動ツリー。
public struct ActivityTree: Sendable {
    private let nodes: [ActivityID: Activity]
    private let childrenByParent: [ActivityID?: [Activity]]

    private init(nodes: [ActivityID: Activity], childrenByParent: [ActivityID?: [Activity]]) {
        self.nodes = nodes
        self.childrenByParent = childrenByParent
    }

    public static func build(from activities: [Activity]) throws -> ActivityTree {
        var nodes: [ActivityID: Activity] = [:]
        for activity in activities {
            guard nodes[activity.id] == nil else {
                throw BuildError.duplicateID(activity.id)
            }
            nodes[activity.id] = activity
        }
        for activity in activities {
            if let parent = activity.parentID, nodes[parent] == nil {
                throw BuildError.missingParent(activity.id, parent: parent)
            }
        }

        var validated: Set<ActivityID> = []
        for activity in activities where !validated.contains(activity.id) {
            var path: [ActivityID] = []
            var positions: [ActivityID: Int] = [:]
            var current: ActivityID? = activity.id
            while let id = current, !validated.contains(id) {
                if let start = positions[id] {
                    // ASSUMPTION: 循環部分だけを親方向の順で返し、閉路の始点を末尾に重複させない。
                    throw BuildError.cycleDetected(involving: Array(path[start...]))
                }
                positions[id] = path.count
                path.append(id)
                current = nodes[id]?.parentID
            }
            validated.formUnion(path)
        }

        var childrenByParent = Dictionary(grouping: activities, by: \.parentID)
        for parent in Array(childrenByParent.keys) {
            childrenByParent[parent]?.sort {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                if $0.name != $1.name { return $0.name < $1.name }
                // ASSUMPTION: 順序と名前が同じ場合も入力順に依存しないよう UUID を最終比較に使う。
                return $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
            }
        }
        // 循環検証後、対象外の祖先を引き継いで全階層を一度ずつ検証する。
        var pending = (childrenByParent[nil] ?? []).reversed().map {
            (activity: $0, excludedAncestor: Optional<ActivityID>.none)
        }
        while let item = pending.popLast() {
            if case .managed = item.activity.budgetMode, let ancestor = item.excludedAncestor {
                throw BuildError.budgetUnderExcluded(item.activity.id, ancestor: ancestor)
            }
            let ancestor = item.activity.budgetMode == .excluded ? item.activity.id : item.excludedAncestor
            pending.append(contentsOf: (childrenByParent[item.activity.id] ?? []).reversed().map {
                (activity: $0, excludedAncestor: ancestor)
            })
        }
        return ActivityTree(nodes: nodes, childrenByParent: childrenByParent)
    }

    public func node(_ id: ActivityID) -> Activity? {
        nodes[id]
    }

    public func children(of id: ActivityID?) -> [Activity] {
        childrenByParent[id] ?? []
    }

    public func ancestors(of id: ActivityID) -> [ActivityID] {
        var result: [ActivityID] = []
        var current = nodes[id]?.parentID
        while let parent = current {
            result.append(parent)
            current = nodes[parent]?.parentID
        }
        return result
    }

    public func descendants(of id: ActivityID) -> [ActivityID] {
        // ASSUMPTION: 子孫は children の並びに従う深さ優先の先行順で返す。
        var result: [ActivityID] = []
        var pending = Array(children(of: id).reversed())
        while let activity = pending.popLast() {
            result.append(activity.id)
            pending.append(contentsOf: children(of: activity.id).reversed())
        }
        return result
    }

    public func topLevel() -> [Activity] {
        children(of: nil)
    }

    public func canReparent(_ id: ActivityID, under newParent: ActivityID?) -> Bool {
        guard let newParent else { return true }
        // ASSUMPTION: 新規活動の作成前にも使えるよう、変更元 ID は未登録でもよい。親は存在を要求する。
        guard id != newParent, nodes[newParent] != nil else { return false }
        return !ancestors(of: newParent).contains(id)
    }
}
