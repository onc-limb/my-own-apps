import Foundation

/// 同梱 JSON を「信頼しない入力」として扱い、記述規約を機械的に検査する。
/// 検査項目は仕様書の JSON 記述規約と 1:1 対応。DEBUG / RELEASE の両方で常時実行する。
enum CatalogValidator {

    static let forbiddenWords = ["治る", "治療", "効能", "医学", "監修", "診断", "処方"]
    private static let idPattern = /^[a-z]{3,12}-[0-9]{2}$/

    /// 違反内容を人が読める文字列で返す。空配列なら妥当。
    static func validate(_ catalog: StretchCatalog) -> [String] {
        var violations: [String] = []
        let items = catalog.allItems

        // 1. schemaVersion
        if catalog.schemaVersion != 1 {
            violations.append("schemaVersion が 1 ではない: \(catalog.schemaVersion)")
        }
        // 2. 件数 20...30
        if !(20...30).contains(items.count) {
            violations.append("件数が 20〜30 の範囲外: \(items.count)")
        }
        // 3. id 形式・一意
        var seen = Set<String>()
        for item in items {
            if item.id.wholeMatch(of: idPattern) == nil {
                violations.append("\(item.id): id の形式が不正")
            }
            if !seen.insert(item.id).inserted {
                violations.append("\(item.id): id が重複")
            }
        }
        // 4. 重み: 全 4 レア度・各 1 以上・合計 100
        for rarity in Rarity.allCases where catalog.weight(for: rarity) < 1 {
            violations.append("レア度 \(rarity.rawValue) の重みが未定義または 1 未満")
        }
        let weightSum = Rarity.allCases.map { catalog.weight(for: $0) }.reduce(0, +)
        if weightSum != 100 {
            violations.append("重みの合計が 100 ではない: \(weightSum)")
        }
        // 5. 全レア度に 1 件以上
        for rarity in Rarity.allCases where catalog.items(rarity: rarity).isEmpty {
            violations.append("レア度 \(rarity.rawValue) の種目が 0 件")
        }
        // 6. レア度別件数の単調非増加（N ≥ R ≥ SR ≥ UR。上位ほど絞る収集設計）
        let counts = [Rarity.n, .r, .sr, .ur].map { catalog.items(rarity: $0).count }
        if counts != counts.sorted(by: >) {
            violations.append("レア度別件数が N ≥ R ≥ SR ≥ UR になっていない: \(counts)")
        }
        for item in items {
            // 7. reward は UR かつ rest
            if item.kind == .reward, item.rarity != .ur || item.bodyPart != .rest {
                violations.append("\(item.id): reward は UR かつ rest でなければならない")
            }
            // 8. stretch は rest 以外
            if item.kind == .stretch, item.bodyPart == .rest {
                violations.append("\(item.id): stretch の bodyPart に rest は使えない")
            }
            // 10. durationSeconds 20...90
            if !(20...90).contains(item.durationSeconds) {
                violations.append("\(item.id): durationSeconds が 20〜90 の範囲外: \(item.durationSeconds)")
            }
            // 11. name 1...20 / steps 2...6 要素・各 1...60 文字
            if !(1...20).contains(item.name.count) {
                violations.append("\(item.id): name が 1〜20 文字ではない")
            }
            if !(2...6).contains(item.steps.count) {
                violations.append("\(item.id): steps が 2〜6 要素ではない")
            }
            for (index, step) in item.steps.enumerated() where !(1...60).contains(step.count) {
                violations.append("\(item.id): steps[\(index)] が 1〜60 文字ではない")
            }
            // 12. emoji 1 文字
            if item.emoji.count != 1 {
                violations.append("\(item.id): emoji が 1 文字ではない")
            }
            // 13. 禁止語
            let texts = [item.name] + item.steps + [item.caution ?? ""]
            for word in forbiddenWords where texts.contains(where: { $0.contains(word) }) {
                violations.append("\(item.id): 禁止語「\(word)」を含む")
            }
        }
        // 9. rest 以外の 6 部位すべてに stretch が 1 件以上
        for part in BodyPart.allCases where part != .rest {
            if !items.contains(where: { $0.bodyPart == part && $0.kind == .stretch }) {
                violations.append("部位 \(part.displayName) のストレッチが 0 件")
            }
        }
        return violations
    }
}
