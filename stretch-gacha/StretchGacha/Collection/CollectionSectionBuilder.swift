import Foundation

/// 図鑑のセクション構築（純粋関数）。[StretchItem] と Set<String> のみを受け、
/// SwiftUI・SwiftData・PracticeStore・時刻・乱数に依存しない。
enum CollectionSectionBuilder {

    static func build(items: [StretchItem],
                      ownedItemIDs: Set<String>) -> [CollectionSection] {
        // 1. 記載順のまま走査し、カタログ内インデックスを保持して部位でグループ化
        let indexed = items.enumerated().map { (index: $0.offset, item: $0.element) }
        let grouped = Dictionary(grouping: indexed, by: { $0.item.bodyPart })
        // 4. 部位の sortOrder 昇順・空セクション除外
        return BodyPart.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { part in
                guard let group = grouped[part], !group.isEmpty else { return nil }
                // 2. (rarity.sortOrder, カタログ内インデックス) の辞書順で昇順ソート
                //    （安定ソートに依存せず、同じカタログに対して常に同じ並びを保証する）
                let sorted = group.sorted {
                    ($0.item.rarity.sortOrder, $0.index) < ($1.item.rarity.sortOrder, $1.index)
                }
                // 3. 入手済み判定は contains の片方向のみ（集合側を走査しない）
                let cells = sorted.map {
                    CollectionCellContent.make(from: $0.item,
                                               isOwned: ownedItemIDs.contains($0.item.id))
                }
                return CollectionSection(id: part.rawValue,
                                         title: part.displayName,
                                         cells: cells)
            }
    }
}
