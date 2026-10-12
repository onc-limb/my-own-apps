import Foundation

// カタログの正はバンドル同梱の StretchCatalog.json（サーバー・SwiftData を持たない）。
// id は practice-record が永続化する安定キー。一度実機に入れた id はリネーム・削除しない。

enum ItemKind: String, Codable, Sendable {
    case stretch   // 通常のストレッチ種目
    case reward    // ご褒美カード（休憩系アクション）
}

enum Rarity: String, Codable, CaseIterable, Sendable {
    case n = "N"
    case r = "R"
    case sr = "SR"
    case ur = "UR"

    var displayName: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .n: 0
        case .r: 1
        case .sr: 2
        case .ur: 3
        }
    }
}

enum BodyPart: String, Codable, CaseIterable, Sendable {
    case neck
    case shoulder
    case lowerBack
    case upperBack
    case legs
    case eyesWrists
    case rest   // ご褒美（kind == .reward 専用）

    var displayName: String {
        switch self {
        case .neck: "首"
        case .shoulder: "肩"
        case .lowerBack: "腰"
        case .upperBack: "背中"
        case .legs: "脚"
        case .eyesWrists: "目・手首"
        case .rest: "ご褒美"
        }
    }

    /// 図鑑の部位セクション順（rest は末尾）
    var sortOrder: Int {
        switch self {
        case .neck: 0
        case .shoulder: 1
        case .lowerBack: 2
        case .upperBack: 3
        case .legs: 4
        case .eyesWrists: 5
        case .rest: 6
        }
    }
}

struct StretchItem: Codable, Identifiable, Hashable, Sendable {
    let id: String              // 例: "neck-01"。安定キー（変更禁止）
    let name: String
    let kind: ItemKind
    let bodyPart: BodyPart
    let rarity: Rarity
    let durationSeconds: Int    // 合計秒数（左右ある種目は合計値）
    let emoji: String           // 視覚補助（絵文字 1 文字）
    let steps: [String]
    let caution: String?        // 種目固有の注意。全体注意は safety-notice の責務
}

struct RarityWeight: Codable, Sendable {
    let rarity: Rarity
    let weight: Int             // 正の整数。全件の合計が 100
}

struct CatalogFile: Codable, Sendable {
    let schemaVersion: Int
    let rarityWeights: [RarityWeight]
    let items: [StretchItem]
}
