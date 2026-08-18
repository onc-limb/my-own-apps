---
feature: stretch-catalog
spec: veronica-docs/stretch-gacha/features/stretch-catalog/spec.md
generated_at: 2026-08-18
---

# ストレッチ種目カタログ（stretch-catalog）: バンドル同梱 JSON による読み取り専用カタログの実装

## 背景

ストレッチガチャは「サーバー・外部 API を持たない（運用コスト月 0 円）」という L1 制約のもとで動くローカル完結アプリである。ガチャが提示するコンテンツ（ストレッチ種目とご褒美カード）をどこに置き、どう供給するかが、他のすべての MVP 機能の前提になる。

現時点で他機能（gacha-draw / stretch-card / stretch-timer / practice-record / stretch-collection）の仕様ドキュメント・実装は存在せず、**stretch-catalog は最初に実装される機能**である。他の 5 機能はすべて本機能の読み取り専用 API に依存するため、本機能は「他機能が未実装でも単体でビルド・テストが通る」状態を成果物とし、UI・永続化には一切踏み込まない。

また、週末の片手間で開発を続けられることが保守性の要件であり、種目の追加が JSON への追記だけで完結し、追記ミスは同梱バリデータとテストが機械的に検出する構造が必要である。

## ゴール

- アプリバンドル同梱の `StretchCatalog.json` 1 ファイルをコンテンツの唯一の正とし、**完全オフラインでコールドスタート直後からガチャが引ける**状態にする。
- 初回同梱 **26 件（ストレッチ 24 種 + ご褒美カード 2 枚）**、レア度 4 段階（N / R / SR / UR）、抽選重み（N 60 / R 27 / SR 10 / UR 3）をデータファイル側に保持する。
- 他機能へ供給する読み取り専用の Swift API（id 引き / 部位引き / レア度引き / 全件 / 重み）を提供する。
- 種目 1 件の追加で変更するファイルを **`StretchCatalog.json` の 1 ファイルのみ**に抑える（Swift コードの変更を伴わない）。
- カタログの読み込み〜利用可能までを実機で 150ms 以内（テストのアサート閾値は 500ms）に収め、プロセス生存中の読み込みを 1 回に限定する。
- データ整合性・コンテンツ規約（医学的効能を謳わない）の違反を、目視レビューではなくバリデータとテストで検出する。

## スコープ（やること / やらないこと）

### やること

- 種目データのスキーマ定義（Swift の `Decodable` 型 + JSON フォーマット規約）
- 初回同梱データ 26 件の作成（仕様書「同梱データ一覧」がそのまま実装対象）
- レア度別の抽選重み（N 60 / R 27 / SR 10 / UR 3）をデータファイル側に保持
- アプリ起動後の初回アクセス時に 1 度だけ読み込み・検証してメモリ常駐させるストア（`StretchCatalog`）
- 他機能が使う読み取り専用の参照 API（`item(id:)` / `items(rarity:)` / `items(bodyPart:)` / `allItems` / `stretchItems` / `rewardItems` / `totalCount` / `weight(for:)`）
- データ整合性バリデータ（`CatalogValidator`、13 項目）とその単体テスト
- コンテンツ規約（禁止語チェック）のテストによる機械的チェック
- Xcode プロジェクトが未作成の場合の最小構成作成（アプリターゲット 1 + ユニットテストターゲット 1、iOS 17、縦画面固定、SwiftUI ライフサイクル）

### やらないこと

- 種目データの追加・編集 UI（アプリ内エディタ、管理画面）
- サーバー配信・リモート更新・差分ダウンロード（L1 制約：サーバー / 外部 API 禁止）
- SwiftData への種目マスタの永続化（カタログはバンドルが唯一の正）
- スキーマのマイグレーション機構（`schemaVersion` は持つが変換コードは書かない）
- データのエクスポート / インポート、他形式（CSV・HealthKit 等）との互換
- 画像・イラスト・動画アセット（視覚補助は絵文字 1 文字のみ）
- 多言語化（日本語直書き。`Localizable.strings` は作らない）
- 抽選アルゴリズムそのものの実装（gacha-draw の責務。本機能は重みデータと参照 API までを提供）
- 種目データを表示する画面（デバッグ用一覧画面も作らない）
- 読み込み失敗時のフォールバックデータ、リトライ、エラーレポート送信、アナリティクス

## 実装方針の要約

**使用技術**: Swift 5.9+ / SwiftUI（iOS 17 以上）、`Foundation` の `JSONDecoder` のみ。外部ライブラリ 0。テストは XCTest。**SwiftData は import しない**。

**変更対象ファイル**

```
stretch-gacha/
├── StretchGacha/
│   ├── Resources/
│   │   └── StretchCatalog.json          [新規] 同梱データ 26 件 + 重み 4 件
│   └── Catalog/
│       ├── CatalogModels.swift          [新規] StretchItem / Rarity / BodyPart / ItemKind / RarityWeight / CatalogFile
│       ├── CatalogStore.swift           [新規] StretchCatalog（load / shared / 参照 API）
│       └── CatalogValidator.swift       [新規] 規約検証（13 項目）
└── StretchGachaTests/
    └── CatalogTests.swift               [新規] 構造不変条件・規約・性能のテスト
```

**実装手順**

1. `stretch-gacha/` に Xcode プロジェクトとテストターゲットが存在することを確認。無ければ最小構成で作成する。
2. `CatalogModels.swift`: `ItemKind` / `Rarity` / `BodyPart` / `StretchItem` / `RarityWeight` と、ファイル全体を表す `CatalogFile`（`schemaVersion` / `rarityWeights` / `items`）を定義。`BodyPart.displayName` / `sortOrder`、`Rarity.sortOrder` も併せて実装。
3. `StretchCatalog.json`: 仕様書の 26 件と重み 4 件を記述。`steps` は 2〜6 行 / 各行 40 文字以内推奨で日本語執筆。左右のある種目は「右側 30 秒 → 反対側も 30 秒」の形で手順に書き、`durationSeconds` は合計値にする。Copy Bundle Resources に登録する。
4. `CatalogValidator.swift`: 仕様書 §6 の 13 項目を実装。違反は「どの id の何が悪いか」が分かる文字列の配列で返す（空配列なら妥当）。
5. `CatalogStore.swift`: `load(bundle:resource:)` でファイル読み込み → デコード → 検証 → 補助辞書構築。`shared` は `static let` で遅延初期化（スレッドセーフ）し、失敗時は `fatalError`。返り値はすべて値型のコピーで、ミュータブルな公開 API は持たない。
6. `CatalogTests.swift`: 受け入れ条件の各項目に対応するテストを実装。
7. 拡張性の実証テスト: テスト用フィクスチャ JSON（既存 26 件 + ダミー 1 件）をテストバンドルに置き、`load(bundle:resource:)` で読めることを確認する。
8. 仕上げ確認: `Catalog/` 配下が `SwiftData` / `URLSession` / `Network` を import していないことを目視 + テストで確認する。

**設計上の要点**

- **`id` は practice-record が SwiftData に永続化する安定キー**。一度実機に入れた `id` はリネーム・削除しない（既存の実施記録が孤立するため）。誤りがあった場合も `id` は据え置き、`name` / `steps` のみ修正する。
- **同梱 JSON を「信頼しない入力」として扱う**。`Decodable` の型・必須キー検証に加え、`CatalogValidator` で値域・一意性・列挙値の組み合わせを全件検証し、DEBUG / RELEASE の両方で実行する。不正データは握り潰さず `fatalError` で即座に停止する。
- **テストは範囲でアサートする**。件数は範囲（20〜30 / reward 1〜4）でアサートし、構造不変条件（重み合計 100、id 一意、reward → UR）は厳密にアサートする。「26 件ちょうど」のような厳密値を書くと種目追加のたびにテストが落ち、「追記だけで完結」が崩れるため。初回 26 件の内訳の正しさは仕様書の一覧表との突き合わせで担保する。
- 参照 API はすべて事前構築済みの辞書 / 配列を返す同期関数とし、`async` にしない。
- ネットワーク・ディスク書き込み・SwiftData クエリはいずれも 0。`print` によるログ出力も残さない。

## 受け入れ条件

- [ ] `StretchCatalog.json` がアプリバンドルに含まれ、`StretchCatalog.load()` がエラーなく完了する
- [ ] `CatalogValidator.validate()` が初回同梱データに対して違反 0 件を返す
- [ ] 種目件数が 20 件以上 30 件以下であることをテストがアサートする（初回同梱の実データは 26 件で、仕様書の一覧表と一致する）
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

## 参照

- 機能仕様ドキュメント: `veronica-docs/stretch-gacha/features/stretch-catalog/spec.md`
  - §1 責務境界 / §2 データモデル / §3 JSON フォーマットおよび記述規約
  - §4 同梱データ一覧（初回 26 件・内訳の検算）
  - §5 ストア API / §6 バリデータ（13 検査項目）/ §7 処理フロー / §8 図鑑向けの補足
  - 「非機能要件」「非機能優先順位との対応」「セキュリティ」「実装方針」「仮置き依存」
