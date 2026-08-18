import Foundation

/// セル表示用の派生モデル。未入手の派生モデルには item.name / steps / durationSeconds を
/// そもそも載せない（ビューの条件分岐を書き間違えても実名が描画されない構造にする）。
struct CollectionCellContent: Equatable, Identifiable {
    let id: String
    let isOwned: Bool
    let rarity: Rarity
    let rarityLabel: String
    let emoji: String           // 先頭 1 文字。未入手でも同じ値（シルエット化はビュー側）
    let displayName: String     // 入手済み: item.name / 未入手: "???"
    let accessibilityLabel: String

    static func make(from item: StretchItem, isOwned: Bool) -> CollectionCellContent {
        let emoji = String(item.emoji.prefix(1))
        let label = item.rarity.displayName
        let name = isOwned ? item.name : "???"
        let accessibility = isOwned
            ? "\(item.name)、レア度 \(label)、入手済み"
            : "未入手、レア度 \(label)"
        return CollectionCellContent(id: item.id,
                                     isOwned: isOwned,
                                     rarity: item.rarity,
                                     rarityLabel: label,
                                     emoji: emoji,
                                     displayName: name,
                                     accessibilityLabel: accessibility)
    }
}
