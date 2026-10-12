import Foundation

struct DrawContext {
    let catalog: StretchCatalog
    let ownedItemIDs: Set<String>      // practice-record 由来（図鑑登録済み）
    let drawnTodayItemIDs: Set<String> // 当日すでに抽選で出た種目
}

enum DrawTuning {
    static let ownedWeight = 1          // 入手済み種目の相対重み
    static let unownedWeight = 2        // 未入手種目の相対重み（= 入手済みの 2 倍）
}

/// 2 段抽選（レア度の重み付き抽選 → 同レア度内の重み付き抽選）。
/// 副作用なしの純粋関数。SwiftUI・SwiftData・時刻に依存しない。
/// 天井（N 回連続で未入手確定）は入れない（ガチャの偶然性を残すユーザー決定）。
enum GachaDrawer {

    static func draw(_ context: DrawContext,
                     using rng: inout some RandomNumberGenerator) -> StretchItem {
        let rarity = selectRarity(context.catalog, using: &rng)
        let pool = applyDailyDedup(candidates: context.catalog.items(rarity: rarity),
                                   drawnToday: context.drawnTodayItemIDs)
        return selectItemWithOwnershipBoost(pool: pool,
                                            owned: context.ownedItemIDs,
                                            using: &rng)
    }

    /// 1 段目: レア度抽選。未入手・同日重複の影響を受けない
    /// （レア度の体感確率をデータの重みだけで決めるため）。
    static func selectRarity(_ catalog: StretchCatalog,
                             using rng: inout some RandomNumberGenerator) -> Rarity {
        // 候補 0 件のレア度は除外する防御的処理（バリデータが通常は保証する）
        let entries = [Rarity.n, .r, .sr, .ur]
            .filter { !catalog.items(rarity: $0).isEmpty }
            .map { ($0, catalog.weight(for: $0)) }
            .filter { $0.1 > 0 }
        precondition(!entries.isEmpty, "抽選候補のレア度がありません")
        let total = entries.map(\.1).reduce(0, +)
        var roll = Int.random(in: 0..<total, using: &rng)
        for (rarity, weight) in entries {
            roll -= weight
            if roll < 0 { return rarity }
        }
        return entries[entries.count - 1].0
    }

    /// 2 段目: 同日重複回避。当日引き切っていたら解除する（レア度の再抽選はしない）。
    static func applyDailyDedup(candidates: [StretchItem],
                                drawnToday: Set<String>) -> [StretchItem] {
        let pool = candidates.filter { !drawnToday.contains($0.id) }
        return pool.isEmpty ? candidates : pool
    }

    /// 3 段目: 未入手 2 倍補正つきの重み付き選択。
    static func selectItemWithOwnershipBoost(pool: [StretchItem],
                                             owned: Set<String>,
                                             using rng: inout some RandomNumberGenerator) -> StretchItem {
        precondition(!pool.isEmpty, "抽選候補の種目がありません")
        let weights = pool.map {
            owned.contains($0.id) ? DrawTuning.ownedWeight : DrawTuning.unownedWeight
        }
        let total = weights.reduce(0, +)
        var roll = Int.random(in: 0..<total, using: &rng)
        for (item, weight) in zip(pool, weights) {
            roll -= weight
            if roll < 0 { return item }
        }
        return pool[pool.count - 1]
    }
}
