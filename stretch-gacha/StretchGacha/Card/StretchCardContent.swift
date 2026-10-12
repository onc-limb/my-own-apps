import Foundation

/// 表示用派生モデル。StretchItem を「信頼しない入力」として扱い、
/// 防御的処理をここに集約する（壊れたデータでも静かに欠けるだけにする）。
struct StretchCardContent: Equatable {
    let rarity: Rarity
    let rarityLabel: String
    let bodyPartLabel: String
    let name: String
    let emoji: String           // 先頭 1 文字に切り詰め済み
    let durationText: String?   // nil なら時間チップを描かない
    let steps: [String]         // 空配列なら手順セクションごと描かない
    let caution: String?        // trim 後に空なら nil

    static func make(from item: StretchItem) -> StretchCardContent {
        let emoji = String(item.emoji.prefix(1))
        let durationText = item.durationSeconds > 0
            ? DurationLabel.text(seconds: item.durationSeconds) : nil
        let steps = item.steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let caution = item.caution
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        return StretchCardContent(rarity: item.rarity,
                                  rarityLabel: item.rarity.displayName,
                                  bodyPartLabel: item.bodyPart.displayName,
                                  name: item.name,
                                  emoji: emoji,
                                  durationText: durationText,
                                  steps: steps,
                                  caution: caution)
    }
}
