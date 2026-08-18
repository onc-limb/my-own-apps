# 機能仕様: stretch-catalog

## 変更履歴

- 2026-08-18 初版作成

## 概要と提供価値

ストレッチガチャが提示するコンテンツ（ストレッチ種目とご褒美カード）を、サーバーを一切持たずにアプリバンドル同梱の JSON 1 ファイルとして保持し、読み取り専用の Swift API として他機能（gacha-draw / stretch-card / stretch-timer / practice-record / stretch-collection）へ供給する。

提供価値は 2 つ。

1. **完全オフライン動作**: 外部 API・サーバーを持たない L1 制約（運用コスト月 0 円）を満たしたまま、コールドスタート直後からガチャが引ける。
2. **週末の片手間でも壊れない拡張性**: 種目の追加が `StretchCatalog.json` への追記だけで完結し、Swift コードの変更を伴わない。追記ミスは同梱のバリデータとテストが検出する。

初回同梱は **26 件（ストレッチ 24 種 + ご褒美カード 2 枚）**。レア度は 4 段階（N / R / SR / UR）、抽選の重みもデータファイル側に持たせ、コードを触らず調整できるようにする。

## スコープ（やること / やらないこと）

### やること

- 種目データのスキーマ定義（Swift の `Decodable` 型 + JSON スキーマ）
- 初回同梱データ 26 件の作成（本書の「同梱データ一覧」がそのまま実装対象）
- レア度別の抽選重み（N 60 / R 27 / SR 10 / UR 3）をデータファイル側に保持
- アプリ起動後の初回アクセス時に 1 度だけ読み込み・検証してメモリ常駐させるストア（`StretchCatalog`）
- 他機能が使う読み取り専用の参照 API（id 引き / 部位引き / レア度引き / 全件）
- データ整合性バリデータ（`CatalogValidator`）とその単体テスト
- コンテンツ規約（医学的効能を謳わない）のテストによる機械的チェック

### やらないこと

- 種目データの追加・編集 UI（アプリ内エディタ、管理画面）
- サーバー配信・リモート更新・差分ダウンロード（L1 制約：サーバー / 外部 API 禁止）
- SwiftData への種目マスタの永続化（カタログはバンドルが唯一の正）
- スキーマのマイグレーション機構（`schemaVersion` フィールドは持つが、変換コードは書かない）
- データのエクスポート / インポート、他形式との互換（L1 妥協特性：互換性・相互運用性）
- 画像・イラスト・動画アセット（手順の視覚補助は絵文字 1 文字のみ。アセットカタログ管理を持ち込まない）
- 多言語化（日本語直書き。`Localizable.strings` は作らない）
- 抽選アルゴリズムそのものの実装（gacha-draw の責務。本機能は重みデータと参照 API を提供するところまで）
- 種目データを表示する画面（画面は gacha / 図鑑 / 履歴の 3 つのみという L1 方針に従い、デバッグ用一覧画面も作らない）

## 機能仕様の詳細

### 1. 責務境界

| 機能 | 本機能から受け取るもの |
|---|---|
| gacha-draw | `rarityWeights`（重み）、`items(rarity:)`（レア度内の候補配列）。抽選ロジックは gacha-draw 側 |
| stretch-card | `StretchItem`（名称・部位・レア度・手順・秒数・絵文字・注意書き） |
| stretch-timer | `StretchItem.durationSeconds` |
| practice-record | `StretchItem.id`（記録に永続化する安定キー） |
| stretch-collection | `allItems`（分母 = 26）、`items(bodyPart:)`、`items(rarity:)`。未入手判定は practice-record 側 |

**重要な運用ルール**: `id` は practice-record が SwiftData に永続化する安定キーである。**一度実機に入れた `id` はリネーム・削除しない**（削除すると既存の実施記録が孤立する）。誤りがあった場合も `id` は据え置き、`name` / `steps` のみ修正する。

### 2. データモデル

```swift
// CatalogModels.swift

enum ItemKind: String, Codable {
    case stretch   // 通常のストレッチ種目
    case reward    // ご褒美カード（休憩系アクション）
}

enum Rarity: String, Codable, CaseIterable {
    case n  = "N"
    case r  = "R"
    case sr = "SR"
    case ur = "UR"

    var displayName: String { rawValue }        // "N" / "R" / "SR" / "UR"
    var sortOrder: Int { ... }                  // N=0, R=1, SR=2, UR=3
}

enum BodyPart: String, Codable, CaseIterable {
    case neck        // 首
    case shoulder    // 肩
    case lowerBack   // 腰
    case upperBack   // 背中
    case legs        // 脚
    case eyesWrists  // 目・手首
    case rest        // ご褒美（休憩）※ kind == .reward 専用

    var displayName: String { ... }             // "首" / "肩" / ...
    /// 図鑑の部位セクション順（rest は末尾）
    var sortOrder: Int { ... }
}

struct StretchItem: Codable, Identifiable, Hashable {
    let id: String              // 例: "neck-01"。安定キー（変更禁止）
    let name: String            // 例: "首の横倒し"
    let kind: ItemKind
    let bodyPart: BodyPart
    let rarity: Rarity
    let durationSeconds: Int    // タイマーに渡す合計秒数（左右ある種目は合計値）
    let emoji: String           // 視覚補助（絵文字 1 文字）
    let steps: [String]         // 手順。1 要素 = 1 行
    let caution: String?        // 種目固有の注意（無い場合は null）
}

struct RarityWeight: Codable {
    let rarity: Rarity
    let weight: Int             // 正の整数。全件の合計が 100 になること
}
```

### 3. JSON フォーマット

配置: `stretch-gacha/StretchGacha/Resources/StretchCatalog.json`（アプリターゲットの Copy Bundle Resources に含める）

```json
{
  "schemaVersion": 1,
  "rarityWeights": [
    { "rarity": "N",  "weight": 60 },
    { "rarity": "R",  "weight": 27 },
    { "rarity": "SR", "weight": 10 },
    { "rarity": "UR", "weight": 3 }
  ],
  "items": [
    {
      "id": "neck-02",
      "name": "首の横倒し",
      "kind": "stretch",
      "bodyPart": "neck",
      "rarity": "N",
      "durationSeconds": 60,
      "emoji": "🙆",
      "steps": [
        "背すじを伸ばして座る",
        "右手を頭の左側に添える",
        "右にゆっくり倒して30秒キープ",
        "反対側も同じように30秒"
      ],
      "caution": null
    },
    {
      "id": "reward-01",
      "name": "深呼吸ブレイク",
      "kind": "reward",
      "bodyPart": "rest",
      "rarity": "UR",
      "durationSeconds": 60,
      "emoji": "🎁",
      "steps": [
        "当たり！ ストレッチはお休み",
        "目を閉じて、鼻から4秒吸う",
        "口から8秒かけて吐く",
        "これを1分くり返す"
      ],
      "caution": null
    }
  ]
}
```

**JSON 記述規約**（追記時に守るルール。バリデータが機械的に検査する）

| 項目 | 規約 |
|---|---|
| `id` | 正規表現 `^[a-z]{3,12}-[0-9]{2}$`。全件で一意。部位プレフィックス + 連番 |
| `name` | 1〜20 文字。左右の別は名称に含めず手順で表現する |
| `durationSeconds` | 20 以上 90 以下の整数。左右ある種目は合計値（例: 片側 30 秒 × 2 → 60） |
| `emoji` | 絵文字 1 文字（`String` の `count == 1`） |
| `steps` | 2〜6 要素。各要素 1〜60 文字（執筆ガイドは 40 文字以内を推奨） |
| `caution` | 種目固有の注意のみ。全体向けの注意書きは safety-notice の責務なので書かない |
| `kind` = `reward` | `rarity` は必ず `UR`、`bodyPart` は必ず `rest` |
| `kind` = `stretch` | `bodyPart` は `rest` 以外 |
| 禁止語 | `name` / `steps` / `caution` に「治る」「治療」「効能」「医学」「監修」「診断」「処方」を含めない |

### 4. 同梱データ一覧（初回 26 件）

**ストレッチ 24 種**

| id | 名称 | 部位 | レア度 | 秒 | 手順の要点 |
|---|---|---|---|---|---|
| neck-01 | 首の前倒し | 首 | N | 30 | あごを引いて首の後ろを伸ばす |
| neck-02 | 首の横倒し | 首 | N | 60 | 片側 30 秒 × 2 |
| neck-04 | チンタック | 首 | N | 30 | あごを水平に引いて 5 秒 × 数回 |
| neck-03 | 首まわし | 首 | R | 40 | ゆっくり大きく左右まわし |
| neck-05 | 首の斜め前伸ばし | 首 | R | 60 | 片側 30 秒 × 2 |
| shoulder-01 | 肩のすくめ上げ | 肩 | N | 30 | すくめて 5 秒・脱力を繰り返す |
| shoulder-02 | 肩まわし | 肩 | N | 40 | 前まわし 20 秒・後ろまわし 20 秒 |
| shoulder-03 | 腕の胸前引き寄せ | 肩 | R | 60 | 片側 30 秒 × 2 |
| shoulder-04 | 肘の頭上引き | 肩 | R | 60 | 片側 30 秒 × 2 |
| shoulder-05 | 背中で手つなぎ | 肩 | SR | 60 | 上下持ち替えで 30 秒 × 2 |
| lowback-01 | 腰の後ろそらし | 腰 | N | 30 | 立って腰に手を当て軽くそらす |
| lowback-02 | 体側伸ばし | 腰 | N | 60 | 片側 30 秒 × 2 |
| lowback-03 | 座位ツイスト | 腰 | R | 60 | 片側 30 秒 × 2 |
| lowback-04 | 膝抱え | 腰 | R | 45 | 仰向けで両膝を抱えて 45 秒 |
| lowback-05 | キャット＆カウ | 腰 | SR | 60 | 四つ這いで背中を丸める・そらす |
| upperback-01 | 背中まるめ | 背中 | N | 30 | 手を前で組んで背中を開く |
| upperback-02 | 万歳のび | 背中 | N | 30 | 頭上で手を組んで上に伸びる |
| upperback-03 | 胸開き | 背中 | R | 40 | 後ろで手を組み胸を張る |
| upperback-04 | 壁つかみ広背筋のばし | 背中 | SR | 60 | 片側 30 秒 × 2 |
| legs-01 | ふくらはぎのばし | 脚 | N | 60 | 片側 30 秒 × 2 |
| legs-02 | もも裏のばし | 脚 | R | 60 | 片側 30 秒 × 2 |
| legs-03 | 股関節前のばし | 脚 | SR | 60 | 片側 30 秒 × 2 |
| eyeswrist-01 | 手首の前後のばし | 目・手首 | N | 60 | 手のひら側 30 秒・甲側 30 秒 |
| eyeswrist-02 | 目のピント切り替え | 目・手首 | N | 30 | 近く 5 秒・遠く 5 秒を繰り返す |

**ご褒美カード 2 枚（UR / `bodyPart: rest`）**

| id | 名称 | レア度 | 秒 | 内容 |
|---|---|---|---|---|
| reward-01 | 深呼吸ブレイク | UR | 60 | 目を閉じて 4 秒吸う・8 秒吐くを 1 分 |
| reward-02 | 遠くを見る休憩 | UR | 60 | 窓の外の遠くをぼんやり眺めて 1 分 |

**内訳の検算**

- 部位別（ストレッチのみ）: 首 5 + 肩 5 + 腰 5 + 背中 4 + 脚 3 + 目・手首 2 = **24**
- レア度別: N 12 + R 8 + SR 4 + UR 2 = **26**（N/R/SR の 24 件がストレッチ、UR の 2 件がご褒美カード）
- 総数: ストレッチ 24 + ご褒美 2 = **26**（L1 の 20〜30 種の範囲内）
- 抽選重み: 60 + 27 + 10 + 3 = **100**
- `durationSeconds` の最大値 = 60（規約上限 90 に対して余裕あり）。演出込みでも 1 セッション 3 分以内という L1 設計を満たす

**ご褒美カードの秒数についての決定事項**: 確認ドキュメント q2 は「1〜2 分」、q3 は「1 種目の合計が 90 秒を超えない」としている。両立させるため、ご褒美カードは **60 秒**に統一し、全カード共通の上限を 90 秒とする。

### 5. ストア API（読み取り専用）

```swift
// CatalogStore.swift

struct StretchCatalog {

    /// アプリ全体で共有するシングルトン。初回アクセス時に 1 度だけ読み込む
    /// （Swift の static let は遅延初期化かつスレッドセーフ）
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

    /// テストから差し替えられるよう bundle / ファイル名を引数化する
    static func load(bundle: Bundle = .main,
                     resource: String = "StretchCatalog") throws -> StretchCatalog

    func item(id: String) -> StretchItem?
    func items(rarity: Rarity) -> [StretchItem]     // 未定義レア度なら []
    func items(bodyPart: BodyPart) -> [StretchItem]

    var stretchItems: [StretchItem] { get }         // kind == .stretch
    var rewardItems: [StretchItem] { get }          // kind == .reward
    var totalCount: Int { get }                     // 図鑑の分母（= allItems.count）
    var weight(for: Rarity) -> Int                  // 未定義なら 0
}
```

- 補助辞書（`itemsByID` 等）は `load()` 内で 1 回だけ構築する。26 件規模なので線形走査でも十分だが、id 引きは practice-record・図鑑から高頻度に呼ばれるため辞書のみ用意する。
- 返り値はすべて値型のコピー。ミュータブルな公開 API は持たない。

### 6. バリデータ

```swift
// CatalogValidator.swift

enum CatalogValidator {
    /// 違反内容を人が読める文字列で返す。空配列なら妥当
    static func validate(_ catalog: StretchCatalog) -> [String]
}
```

検査項目（すべて「§3 JSON 記述規約」と 1:1 対応）:

1. `schemaVersion == 1`
2. 件数が 20 以上 30 以下
3. `id` が正規表現に一致し、全件で一意
4. `Rarity` 全 4 ケースに重みが定義され、各重みが 1 以上、合計が 100
5. `Rarity` 全 4 ケースに 1 件以上の種目が存在する
6. レア度別件数が N ≥ R ≥ SR ≥ UR（上位ほど絞るという収集設計）
7. `kind == .reward` の件は `rarity == .ur` かつ `bodyPart == .rest`
8. `kind == .stretch` の件は `bodyPart != .rest`
9. `rest` 以外の 6 部位すべてに `stretch` が 1 件以上存在する
10. `durationSeconds` が 20...90
11. `name` が 1...20 文字、`steps` が 2...6 要素で各要素 1...60 文字
12. `emoji` が 1 文字
13. 禁止語（`治る` / `治療` / `効能` / `医学` / `監修` / `診断` / `処方`）を含まない

`load()` は デコード後に `validate` を呼び、違反が 1 件でもあれば `CatalogError.invalid(violations)` を throw する（`shared` 経由なら `fatalError`）。同梱データの破損はビルド成果物の不正であり、実行時に握り潰すよりテストで事前検出させる方針（L1 妥協特性「運用性」に整合）。

### 7. 処理フロー

```
[アプリ起動]
      │
      │  （ガチャ画面 or 図鑑画面が最初に StretchCatalog.shared に触れる）
      ▼
StretchCatalog.shared
      ├─ Bundle.main.url(forResource: "StretchCatalog", withExtension: "json")
      │      └─ 見つからない → fatalError（バンドル設定ミス）
      ├─ Data(contentsOf:)                       (~12KB)
      ├─ JSONDecoder().decode(CatalogFile.self)  → 型・必須キー検証
      ├─ CatalogValidator.validate()             → 規約検証（違反あれば fatalError）
      └─ 補助辞書を構築してメモリ常駐（プロセス生存中は再読込しない）
      ▼
[以後は同期・即時返却]
  gacha-draw      : rarityWeights → レア度決定 → items(rarity:) から等確率で 1 件
  stretch-card    : StretchItem をそのまま描画
  stretch-timer   : durationSeconds でカウントダウン
  practice-record : 完了時に item.id を SwiftData に保存
  stretch-collection : allItems を部位・レア度で整理し、未入手は伏せて表示
```

### 8. 図鑑向けの補足

図鑑のシルエット表示は「未入手なら `name` / `steps` を伏せ、`emoji` をグレーで出す」等の表現で実現する。**伏せる判断は stretch-collection 側の責務**であり、カタログは常に全属性を返す（カタログ側に「未入手用の別データ」を持たせない）。

## 非機能要件

| 項目 | 値 | 根拠・備考 |
|---|---|---|
| 同梱種目数 | 初回 26 件。下限 20 / 上限 30 | L1「20〜30 種目」 |
| カタログ読み込み〜利用可能まで | 設計目標 150ms 以内（実機 iPhone・コールドスタート） | L1「ガチャ結果表示まで 3 秒以内」の 5% 以内に収める |
| 同上・テストのアサート閾値 | **500ms 以内** | シミュレータ / CI の実行環境差で揺れるため、余裕を持った上限で固定する |
| JSON ファイルサイズ | 想定 12〜16KB。上限 64KB | 26 件 × 約 500B |
| メモリ常駐量 | 1MB 未満 | 値型 26 件 + 補助辞書 |
| SwiftData クエリ本数 | **0 本**（本機能は永続化層に一切触れない） | カタログの正はバンドル |
| ディスク書き込み回数 | **0 回**（読み取り専用） | |
| ネットワークリクエスト数 | **0 件** | L1 制約：サーバー・外部 API 禁止 |
| 読み込み回数 | プロセス生存中 **1 回**（`static let` の遅延初期化） | ガチャ演出中の再読込を発生させない |
| 種目 1 件追加時に変更するファイル数 | **1 ファイル**（`StretchCatalog.json` のみ） | L1 最優先「保守性」。既存部位・既存レア度の範囲内での追加が対象 |
| 想定同時ユーザー数 | 1（自分のみ、同時実行なし） | L1 妥協特性：スケーラビリティ |
| 初回同梱データ完成時期 | MVP（2 週間）内 ※L1 の仮置き値に基づく | L1「期限・マイルストーン」が【仮置き】 |

**例外**: 新しい部位を増やす場合のみ `BodyPart` enum への 1 ケース追加（+ `displayName` / `sortOrder`）が必要になる。6 部位は L1 で確定しているため通常運用では発生しない想定だが、この 1 箇所だけがデータ追記で完結しない点として明記する。

## 非機能優先順位との対応

### 1 位: 学習容易性（説明書なしで 60 秒以内に最初のガチャ→実施へ）

- **手順テキストの読了負荷を規約で縛る**: `steps` は 2〜6 行・1 行 60 文字以内（推奨 40 文字以内）。stretch-card が 1 画面で読み切れる密度を、データ側で保証する。
- **専門用語を使わない**: 部位名は「首 / 肩 / 腰 / 背中 / 脚 / 目・手首」の日常語のみ。筋肉名（`広背筋のばし` のような一般に流通した語を除く）や解剖学用語を手順本文に持ち込まない。
- **説明を要する概念を増やさない**: レア度は N / R / SR / UR の 4 段階に固定し、それ以上の属性（難易度・強度・タグ等）をカタログに持たせない。ユーザーが覚える軸を「部位」と「レア度」の 2 つに抑える。
- 本機能は画面を持たないため、画面数 3 の制約に影響しない。

### 2 位: パフォーマンス（コールドスタート → ガチャ結果 3 秒以内、演出 60fps）

- 起動〜ガチャ結果の 3 秒予算のうち、カタログの取り分を **150ms 以内**に明示的に確保する（テスト閾値 500ms）。
- 12〜16KB の単一 JSON を 1 回デコードするだけ。ファイル分割・遅延ロード・逐次パースはしない（26 件規模では複雑さがコストに見合わない）。
- **デコードとバリデーションはプロセスで 1 回だけ**。ガチャ演出中・タイマー稼働中にファイル I/O が走らないため、60fps を阻害しない。
- 参照 API はすべて事前構築済みの辞書 / 配列を返す同期関数。`async` にせず、View から直接呼べる形にして待ち合わせを作らない。

### 3 位: 保守性（週末開発でも壊さず拡張できる）

- **追記だけで完結**: 種目追加は JSON に 1 オブジェクト足すだけ。件数・配分・重みはすべてデータ側にあり、コードは 1 行も触らない。
- **配分と重みをデータ化**: レア度別件数の方針（N ≥ R ≥ SR ≥ UR）と抽選重みを JSON に置き、バランス調整をビルド設定やコード定数に散らさない。
- **壊れたら CI ではなくテストが落ちる**: `CatalogValidator` + テストが規約違反（id 重複・秒数超過・重み合計ずれ・禁止語混入）を機械的に検出するため、目視レビューに依存しない。
- **テストは範囲でアサートする**: 「26 件ちょうど」のような厳密値をテストに書くと、種目を 1 件足すたびにテストが落ちて「追記だけで完結」が崩れる。件数は範囲（20〜30 / reward 1〜4）で、構造不変条件（重み合計 100、id 一意、reward → UR）は厳密でアサートする。初回 26 件の内訳の正しさは本書の一覧表との突き合わせで担保する。

### 妥協特性で簡略化すること

| 妥協特性 | 本機能で作らないもの |
|---|---|
| スケーラビリティ | 全件メモリ常駐・線形前提の素朴な実装で通す。インデックス最適化、ページング、DB 化、遅延ロードは一切しない（26 件、将来 100 件でも問題にならない） |
| 互換性・相互運用性 | JSON はこのアプリ専用スキーマ。`schemaVersion` は数値を持つだけでマイグレーション変換コードは書かない。エクスポート / インポート、他形式（CSV・HealthKit 等）への変換なし。多言語化なし |
| 運用性 | 読み込み失敗時のフォールバック用データ、リトライ、リモート更新、エラーレポート送信、アナリティクスを持たない。失敗は `fatalError` で即座に落とし、テストで事前に防ぐ |

## セキュリティ

本機能は完全ローカル・読み取り専用で、ネットワークもユーザー入力も扱わないため、攻撃面は「同梱データの内容」と「バンドル読み込み経路」に限定される。

### 認証・認可

- **不要**（実装しない）。アカウント・ログインを持たず、単一端末・単一ユーザーのローカル完結（L1 スコープ外事項）。カタログは全アプリ機能から等しく読み取り可能でよい。
- カタログを書き換える API を公開しない（`StretchItem` は `let` のみの値型、ストアは読み取り専用）。他機能からの誤変更を型レベルで防ぐ。

### 入力検証

- ユーザー入力は受け付けない（本機能に入力フォーム・テキスト入力は存在しない）。
- **同梱 JSON を「信頼しない入力」として扱う**: `Decodable` による型・必須キー検証に加え、`CatalogValidator` で値域・一意性・列挙値の組み合わせを全件検証する。検証は DEBUG / RELEASE の両方で実行する（26 件で数 ms のため常時実行のコストは無視できる）。
- 不正データは握り潰さず `fatalError` で即座に停止し、部分的に壊れた状態でユーザーに提示しない。

### データ保護

- カタログに個人情報・端末識別子・利用統計を **一切含めない**。含まれるのは種目名・部位・レア度・秒数・手順文のみ。
- 本機能はディスクへ書き込まない。バンドルリソースは OS により読み取り専用。
- **ネットワークを使わない**: `URLSession` / `Network` / `CFNetwork` を import しない。Info.plist の App Transport Security 設定を緩めない。App Privacy「データ収集なし」申告（appstore-release-prep）と矛盾しない状態を維持する。
- ログ出力を残さない（`print` を使わない）。読み込み失敗時のみ `fatalError` のメッセージに違反内容を出す。

### 依存関係

- 外部ライブラリ 0（`Foundation` のみ）。サプライチェーン経由の混入リスクを構造的に排除する（L1 制約：外部ライブラリ原則ゼロ）。

### コンテンツ安全性（法務制約の技術的担保）

- 一般に知られた自重ストレッチのみを収録し、器具・他者の補助を要する種目、荷重をかける種目を含めない。
- 医学的効能・専門家監修を主張しないことを、禁止語チェック（`治る` / `治療` / `効能` / `医学` / `監修` / `診断` / `処方`）としてバリデータとテストに落とし込む。
- `caution` は種目固有の注意のみを扱う。「痛みが出たら中止する」等の全体注意は safety-notice の責務で、カタログに重複して持たせない。

## 実装方針

### 使用技術

- Swift 5.9+ / SwiftUI（iOS 17 以上）
- `Foundation` の `JSONDecoder` のみ。外部ライブラリなし
- テストは XCTest（標準）
- **SwiftData は使わない**（本機能では import しない）

### 既存実装との整合

現時点で他機能の仕様ドキュメント・実装は存在しない。**stretch-catalog は最初に実装される機能**であり、他の 5 つの MVP 機能はすべて本機能の読み取り専用 API に依存する。したがって本機能は「他機能が未実装でも単体でビルド・テストが通る」状態を成果物とし、UI・永続化には一切踏み込まない。

Xcode プロジェクト（`stretch-gacha/`）が未作成の場合は、本機能に必要な最小構成（アプリターゲット 1 + ユニットテストターゲット 1、iOS 17 デプロイメントターゲット、縦画面固定）のみを作成する。画面は L1 の 3 画面方針を先取りせず、本機能では追加しない。

### 変更対象ファイル

```
stretch-gacha/
├── StretchGacha/
│   ├── Resources/
│   │   └── StretchCatalog.json          [新規] 同梱データ 26 件
│   └── Catalog/
│       ├── CatalogModels.swift          [新規] StretchItem / Rarity / BodyPart / ItemKind / RarityWeight
│       ├── CatalogStore.swift           [新規] StretchCatalog（load / shared / 参照 API）
│       └── CatalogValidator.swift       [新規] 規約検証
└── StretchGachaTests/
    └── CatalogTests.swift               [新規] 構造不変条件・規約・性能のテスト
```

### 実装手順

1. **ターゲット確認**: `stretch-gacha/` に Xcode プロジェクトとテストターゲットが存在することを確認。無ければ最小構成で作成する（iOS 17 / 縦画面固定 / SwiftUI ライフサイクル）。
2. **`CatalogModels.swift`**: `ItemKind` / `Rarity` / `BodyPart` / `StretchItem` / `RarityWeight` と、ファイル全体を表す `CatalogFile`（`schemaVersion` / `rarityWeights` / `items`）を定義。`BodyPart.displayName` / `sortOrder`、`Rarity.sortOrder` も併せて実装。
3. **`StretchCatalog.json`**: 本書「同梱データ一覧」の 26 件と重み 4 件を記述。`steps` は §3 の規約（2〜6 行 / 各行 40 文字以内推奨）に従って日本語で執筆。左右のある種目は「右側 30 秒 → 反対側も 30 秒」の形で手順に書き、`durationSeconds` は合計値にする。Xcode の Copy Bundle Resources に登録する。
4. **`CatalogValidator.swift`**: §6 の 13 項目を実装。違反は「どの id の何が悪いか」が分かる文字列で返す。
5. **`CatalogStore.swift`**: `load(bundle:resource:)` でファイル読み込み → デコード → 検証 → 補助辞書構築。`shared` は `static let` で遅延初期化し、失敗時は `fatalError`。参照 API 群（`item(id:)` / `items(rarity:)` / `items(bodyPart:)` / `stretchItems` / `rewardItems` / `totalCount` / `weight(for:)`）を実装。
6. **`CatalogTests.swift`**: 「受け入れ条件」の各項目に対応するテストを実装。件数は範囲アサート、構造不変条件は厳密アサート。読み込み時間は 500ms 上限で計測。
7. **拡張性の実証テスト**: テスト用フィクスチャ JSON（既存 26 件 + ダミー 1 件）をテストバンドルに置き、`load(bundle:resource:)` で読めることを確認する。Swift コードを変更せずに種目が増やせることをテストで示す。
8. **仕上げ確認**: `Catalog/` 配下のファイルが `SwiftData` / `URLSession` / `SwiftUI` を import していないことを目視 + テストで確認する。

## 受け入れ条件

- [ ] `StretchCatalog.json` がアプリバンドルに含まれ、`StretchCatalog.load()` がエラーなく完了する
- [ ] `CatalogValidator.validate()` が初回同梱データに対して違反 0 件を返す
- [ ] 種目件数が 20 件以上 30 件以下であることをテストがアサートする（初回同梱の実データは 26 件で、本書の一覧表と一致する）
- [ ] `kind == .reward` の件数が 1 件以上 4 件以下、`kind == .stretch` の件数が「総数 − reward 件数」に一致する（初回同梱は reward 2 / stretch 24）
- [ ] レア度別件数が N ≥ R ≥ SR ≥ UR の順で単調非増加であり、4 レア度すべてに 1 件以上存在する（初回同梱は N12 / R8 / SR4 / UR2）
- [ ] `rarityWeights` が 4 レア度すべてを定義し、各重みが 1 以上、**合計がちょうど 100** である（初回同梱は N60 / R27 / SR10 / UR3）
- [ ] 全件の `id` が `^[a-z]{3,12}-[0-9]{2}$` に一致し、重複が 0 件である
- [ ] 全件の `durationSeconds` が 20 以上 90 以下である（初回同梱の最大値は 60）
- [ ] 全件の `name` が 1〜20 文字、`steps` が 2〜6 要素で各要素が 1〜60 文字、`emoji` が 1 文字である
- [ ] `kind == .reward` の全件が `rarity == .ur` かつ `bodyPart == .rest` である
- [ ] `kind == .stretch` の全件が `bodyPart != .rest` であり、`rest` を除く 6 部位すべてに 1 件以上のストレッチが存在する（初回同梱は 首5 / 肩5 / 腰5 / 背中4 / 脚3 / 目・手首2 = 24）
- [ ] `name` / `steps` / `caution` のいずれにも禁止語（治る・治療・効能・医学・監修・診断・処方）が含まれない
- [ ] `caution` 以外のすべてのフィールドが非 optional で、全件に値が入っている
- [ ] `item(id:)` が既存 id に対して該当種目を返し、未知の id に対して `nil` を返す
- [ ] `items(rarity:)` / `items(bodyPart:)` の返却件数の合計が、それぞれ `totalCount` に一致する
- [ ] コールドな `load()` の所要時間が **500ms 以内**である（テスト実行環境での上限値。実機での設計目標は 150ms 以内）
- [ ] JSON ファイルサイズが **64KB 以内**である
- [ ] `StretchCatalog.shared` に複数回アクセスしてもファイル読み込みが 1 回しか発生しない（読み込み回数を数えられる形でテスト、またはインスタンス同一性で確認）
- [ ] `Catalog/` 配下のソースが `SwiftData` / `URLSession` / `Network` を import していない
- [ ] テスト用フィクスチャ（種目を 1 件追記した JSON）を Swift コードの変更なしに読み込め、追加した種目が `item(id:)` / `items(bodyPart:)` から取得できる
- [ ] 本機能の実装によりビルド警告が 0 件である

## 仮置き依存

| # | L1 の仮置き値 | 本書での依存箇所 | 仮置きが覆った場合の影響 |
|---|---|---|---|
| 1 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 初回同梱を 26 件（L1 の 20〜30 種の中央付近）で締め、初版では画像アセット・多言語化・種目編集 UI を作らないと決めた判断 | 期間が延びる場合は 30 件までの増量や視覚補助の拡充を検討する余地がある。データ追記のみで対応可能なため、構造変更は不要 |
| 2 | 配布・審査「当面は Xcode 直接インストール。4 週間後に App Store 公開を判断」 | ストア審査向けメタデータ（コンテンツレーティング資料、出典表記、免責文の多重化）を本機能では持たない判断 | 公開判断が前倒しになった場合、`caution` の記載方針とコンテンツ出典の扱いを appstore-release-prep 側で再点検する必要がある（カタログのスキーマ変更は伴わない想定） |

## 実装記録
