import Foundation

enum CatalogError: Error, CustomStringConvertible {
    case resourceNotFound(String)
    case invalid([String])

    var description: String {
        switch self {
        case .resourceNotFound(let name): "同梱カタログが見つかりません: \(name).json"
        case .invalid(let violations): "カタログ規約違反:\n" + violations.joined(separator: "\n")
        }
    }
}

/// 読み取り専用のカタログストア。プロセス生存中に 1 回だけ読み込み、メモリ常駐させる。
struct StretchCatalog: Sendable {

    /// アプリ全体で共有するシングルトン（static let は遅延初期化かつスレッドセーフ）。
    /// 同梱データの破損はビルド成果物の不正なので、実行時に握り潰さず即座に落とす。
    static let shared: StretchCatalog = {
        do { return try StretchCatalog.load() }
        catch { fatalError("同梱カタログの読み込みに失敗: \(error)") }
    }()

    let schemaVersion: Int
    let allItems: [StretchItem]                 // JSON の記載順
    let rarityWeights: [Rarity: Int]

    private let itemsByID: [String: StretchItem]
    private let itemsByRarity: [Rarity: [StretchItem]]
    private let itemsByBodyPart: [BodyPart: [StretchItem]]

    /// テストから bundle / ファイル名を差し替えられるようにする
    static func load(bundle: Bundle = .main,
                     resource: String = "StretchCatalog") throws -> StretchCatalog {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw CatalogError.resourceNotFound(resource)
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(CatalogFile.self, from: data)
        let catalog = StretchCatalog(file: file)
        let violations = CatalogValidator.validate(catalog)
        guard violations.isEmpty else { throw CatalogError.invalid(violations) }
        return catalog
    }

    init(file: CatalogFile) {
        schemaVersion = file.schemaVersion
        allItems = file.items
        rarityWeights = Dictionary(uniqueKeysWithValues: file.rarityWeights.map { ($0.rarity, $0.weight) })
        itemsByID = Dictionary(file.items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        itemsByRarity = Dictionary(grouping: file.items, by: \.rarity)
        itemsByBodyPart = Dictionary(grouping: file.items, by: \.bodyPart)
    }

    func item(id: String) -> StretchItem? { itemsByID[id] }
    func items(rarity: Rarity) -> [StretchItem] { itemsByRarity[rarity] ?? [] }
    func items(bodyPart: BodyPart) -> [StretchItem] { itemsByBodyPart[bodyPart] ?? [] }

    var stretchItems: [StretchItem] { allItems.filter { $0.kind == .stretch } }
    var rewardItems: [StretchItem] { allItems.filter { $0.kind == .reward } }
    var totalCount: Int { allItems.count }
    func weight(for rarity: Rarity) -> Int { rarityWeights[rarity] ?? 0 }
}
