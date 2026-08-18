---
feature: stretch-collection
spec: veronica-docs/stretch-gacha/features/stretch-collection/spec.md
generated_at: 2026-08-18
---

# 図鑑画面（stretch-collection）: 部位別セクション + 3 列グリッドで全 26 件を一覧表示し、未入手はシルエット表示にする

## 背景

practice-record によって `RootTabView`（ガチャ / 履歴の 2 タブ）と実施記録の永続化・メモリ索引が導入され、`PracticeStore.ownedItemIDs() -> Set<String>` で入手済み種目の集合を fetch 0 本で取得できる状態になっている。一方で、入手した種目の手順を後から見返す手段はガチャを回すこと以外に存在せず、「どの部位のどのレア度がまだ埋まっていないか」も分からない。

L1 は「MVP では図鑑のシルエット表示のみで進捗を示す」と定めており、副次指標として「図鑑が埋めたくなる動機として機能しているか」を挙げている。本機能はこの空白を埋める最後の L1 画面であり、これによりガチャ / 図鑑 / 履歴の 3 画面が揃い、L1 制約「画面は 3 つまで」をちょうど満たす。

本機能は何も永続化せず、SwiftData のクエリを 1 本も増やさない。表示用のセクション構造はカタログと入手済み集合だけを引数に取る純粋関数で組み立てるため、L1 最優先 2 位のパフォーマンス予算（コールドスタート → 結果表示 3.0 秒）に 0 秒を追加する。

## ゴール

1. **収集の狙いが定まる状態を作る**: 部位ごとのセクションとレア度バッジによって「どの部位のどのレア度が空いているか」は一目で分かり、種目名・手順は伏せたままにすることで「何が出るか」は分からない状態を保つ。埋める手段をガチャに限定し、義務感ではなく収集欲で継続を駆動する。
2. **入手済みの内容を取りに行ける状態を作る**: 一度出た種目の手順・実施時間を、`StretchCardView(item:style: .detail)` の詳細シートでいつでも見返せるようにし、図鑑を「見返す場所」として成立させる。
3. **既存の性能・構造を一切劣化させない**: 起動経路（T1）に登場せず、fetch 0 本 / save 0 回 / 永続化状態 0 個 / 追加アセット 0 個を維持し、他機能への変更を `RootTabView.swift` の 1 ファイルに封じ込める。

## スコープ（やること / やらないこと）

### やること

- 図鑑画面 `CollectionView`（部位セクション + 3 列グリッド + 詳細シート提示 + `rebuild()`）
- セル表示用の派生モデル `CollectionCellContent` と変換純粋関数 `make(from:isOwned:)`
- セクション値型 `CollectionSection` と構築純粋関数 `CollectionSectionBuilder.build(items:ownedItemIDs:)`
- セル `CollectionCellView`（レア度バッジ / 絵文字 or シルエット / 種目名 or「???」）
- 詳細シート `CollectionDetailSheet`（`StretchCardView(item:style: .detail)` + フッターに「閉じる」）
- 未入手セルのタップ応答（セル内ラベルを「???」→「未入手」に差し替え。同時に 1 つ以下）
- レイアウト定数 `CollectionMetrics`（列数・余白・セル寸法・階調・不透明度・枠線幅）
- `RootTabView` への図鑑タブ挿入（ガチャ / 図鑑 / 履歴の 3 タブ構成）
- 入手集合の変化を反映する再構築（`onAppear` / `scenePhase == .active`）
- 上記すべてのユニットテスト（並び順・入手済み判定・防御的処理・不変条件・性能・拡張性）
- 条件付き: `BodyPart.rest.displayName` が未定義の場合のみ `Catalog/CatalogModels.swift` に 1 ケース追記

### やらないこと

- **コンプ率・達成率・件数表示**（collection-progress の責務）。セクション見出しにも「3/5」等を出さない
- **NEW バッジ / 既読フラグ**。既読状態を一切永続化せず、入手済み / 未入手の 2 状態のみを持つ
- **実施記録・図鑑登録の書き込み**（practice-record の責務）。入手済み集合を読むだけ
- **抽選ロジック・演出**（gacha-draw の責務）。`Gacha/` を 0 ファイル変更
- **図鑑からのタイマー起動**。`Timer/` を import しない。詳細シートに「はじめる」を置かない
- **カード内のレイアウト**（stretch-card の責務）。`.detail` をそのまま使い、3 つ目の `StretchCardStyle` を追加しない
- **種目データの保持・検証**（stretch-catalog が唯一の正）
- **整理軸の切り替え UI**、検索・フィルタ・並べ替え・部位ジャンプ導線
- お気に入り、メモ、実施回数・最終実施日のセル内表示
- 未入手セルのヒント表示・提供確率の開示 UI
- 図鑑の共有・スクリーンショット出力・エクスポート
- 画像・イラスト・シルエット専用アセット（視覚補助は `StretchItem.emoji` 1 文字の階調変換のみ）
- 入場アニメーション・出現の時間差演出・入手時の解放演出
- 多言語化（日本語直書き。`Localizable.strings` を作らない）
- サーバー・外部 API・アナリティクス送信

## 実装方針の要約

### 構造

- 依存の向きは **stretch-collection → stretch-catalog / stretch-card / practice-record** の一方向。他機能から本機能の型を参照させない。
- `PracticeStore` に触れるのは `CollectionView.swift` の 1 箇所のみ。純粋関数群は `[StretchItem]` と `Set<String>` しか知らない。
- `Collection/` 配下は `SwiftData` / `URLSession` / `Network` / `CFNetwork` / `UserNotifications` を import せず、`Gacha/` / `Timer/` の型を参照しない。描画経路に I/O・非同期・アニメーションを 1 つも置かないことを設計上の固定点とする。

### 整理軸と並び順

- **セクション = 部位（`BodyPart.sortOrder` 昇順）、セクション内 = レア度昇順**。`rest`（ご褒美）は `sortOrder` により末尾に来る。ソート順を本機能で再定義しない。
- 同一レア度内は **`(rarity.sortOrder, カタログ内インデックス)` の辞書順**で並べる。第 2 キーを入れるのは Swift の `sort` が安定ソートを保証しないため。同じカタログに対して常に同じ並びになることを構造的に保証する。
- `cells` が空のセクションは描かない（カタログのバリデータが保証するため通常は発生しない防御的処理）。
- 見出し文字列は `BodyPart.displayName` をそのまま使い、**部位名の文字列リテラルを `Collection/` に置かない**。

### 未入手の見せ方

| 要素 | 入手済み | 未入手 |
|---|---|---|
| レア度バッジ | `RarityStyle` の色 + 文字（N/R/SR/UR） | 同じ（伏せない） |
| 部位 | セクション見出し | 同じ（伏せない） |
| 絵文字 | `StretchItem.emoji` の 1 文字 | 同じ 1 文字を `.grayscale(1.0).opacity(0.35)` |
| 種目名 | `StretchItem.name` | 「???」 |
| 手順・実施時間 | 詳細シートで閲覧可 | 見せない（シートを開かない） |
| セル背景 / 枠線 / 文字色 | `secondarySystemBackground` / `accent` 50% 1.0pt / `label` | `tertiarySystemFill` / `separator` 1.0pt / `secondaryLabel` |

**未入手セルの派生モデルに `name` / `steps` / `durationSeconds` をそもそも載せない**ことで、ビューの条件分岐を書き間違えても実名が描画されない構造にする。未入手セルからはシートを開かない（`selectedItem` への代入経路が入手済み分岐にしかない）。

### 派生モデルと変換規則

- `CollectionCellContent`: `id` / `isOwned` / `rarity` / `rarityLabel` / `emoji` / `displayName` / `accessibilityLabel`
- `emoji` は `String(item.emoji.prefix(1))`（空なら空文字。絵文字行の高さは確保）
- 未入手の `displayName` は常に `"???"`（`item.name` を参照しない）
- `accessibilityLabel` は入手済み `"\(name)、レア度 \(rarityLabel)、入手済み"` / 未入手 `"未入手、レア度 \(rarityLabel)"`
- `ownedItemIDs` は「信頼しない入力」として扱い、判定は `contains` の片方向のみ。集合側を走査しないため、カタログに無い ID が混入しても無視される。

### 画面・レイアウト

- `ScrollView` + `LazyVGrid`（`GridItem(.flexible())` × 3 の固定 3 列）+ `Section`。固定ヘッダを持たず、画面全体が 1 つのスクロール領域。
- 設計基準機（iPhone SE 375×667・縦固定）でセル **107 × 122pt**、横方向検算 `16 + 107 + 11 + 107 + 11 + 107 + 16 = 375`。グリッド全体 **1714pt**（利用可能高さ 598pt に対し約 2.9 画面分）、初期表示で上端から 466pt = 8 セルが視界に入る。
- Dynamic Type はセル高さを固定せず内容に追従（絵文字のみ `.system(size: 40)` 固定の装飾要素）。
- 詳細シートは `presentationDetents([.large])` + `presentationDragIndicator(.visible)`。手順スクロール領域は 276pt（種目名 2 行時）/ 302pt（1 行時）で、stretch-card の常時可視・全文到達条件を満たす。
- 数値はすべて `CollectionMetrics` に集約し、ビューにマジックナンバーを書かない。

### 更新タイミング

`[CollectionSection]` を `@State` に持ち、`onAppear`（タブ選択のたびに発火）と `scenePhase == .active` への復帰で `rebuild()` する。永続化層の観測挙動に依存しない。

```swift
private func rebuild() {
    sections = CollectionSectionBuilder.build(items: catalog.allItems,
                                              ownedItemIDs: store.ownedItemIDs())
}
```

### 変更対象ファイル

```
stretch-gacha/
├── StretchGacha/
│   ├── Collection/
│   │   ├── CollectionCellContent.swift     [新規]
│   │   ├── CollectionSection.swift         [新規]
│   │   ├── CollectionSectionBuilder.swift  [新規]
│   │   ├── CollectionMetrics.swift         [新規]
│   │   ├── CollectionCellView.swift        [新規]
│   │   ├── CollectionDetailSheet.swift     [新規]
│   │   └── CollectionView.swift            [新規]
│   ├── RootTabView.swift                   [変更] 図鑑タブを 1 つ挿入
│   └── Catalog/CatalogModels.swift         [条件付き変更] rest.displayName 未定義時のみ 1 ケース追記
└── StretchGachaTests/
    └── StretchCollectionTests.swift        [新規]
```

`Gacha/` / `Timer/` / `Card/` / `Record/` は 0 ファイル変更。`StretchCatalog.json` の差分は 0 件。

### 実装手順

1. `CollectionMetrics.swift`: 列数 3 / 左右余白 16 / 列間 11 / セル内パディング 8 / 絵文字 40pt / 行間 12 / セクション間 16 / 見出し 28 / `grayscale 1.0` / `opacity 0.35` / 枠線 1.0 を定数化し、検算値をコメント併記
2. `CollectionCellContent.swift`: 絵文字切り詰め・「???」分岐・`accessibilityLabel` 組み立てを独立した式に分ける
3. `CollectionSection.swift` / `CollectionSectionBuilder.swift`: グループ化 → ソート → セル変換 → セクション整列を private ヘルパに分割
4. `CollectionCellView.swift`: 表示表とメトリクス通りに描画。テキストはすべて `Text(verbatim:)`、アクセシビリティ修飾を付与、`.animation` / `Task` を書かない
5. `CollectionDetailSheet.swift`: `StretchCardView(.detail) { Button("閉じる") { dismiss() } }` を包むだけ
6. `CollectionView.swift`: グリッド + `sections` / `selectedItem` / `revealedUnownedID` + `rebuild()`
7. `RootTabView.swift`: ガチャと履歴の間に図鑑タブ（`square.grid.2x2` / ラベル「図鑑」）を挿入。既定選択タブ・非永続化には触れない
8. `BodyPart.rest.displayName` の定義有無を確認し、未定義時のみ 1 ケース追記 + `CatalogTests` 違反 0 件を確認
9. `StretchCollectionTests.swift`: 受け入れ条件と 1:1 対応するテストを実装（件数は不変条件、並び順・文字列は厳密値でアサート、`PracticeStore` を使うテストは `isStoredInMemoryOnly: true`）
10. 拡張性の実証テスト（26 件 + ダミー 1 件のフィクスチャ）
11. 仕上げ確認（import / ログ / アセット / ビルド警告 / 実機目視）

## 受け入れ条件

### タブ構成と画面の成立

- [ ] タブが「ガチャ」「図鑑」「履歴」の **3 つ**になり、図鑑タブから図鑑画面へ到達できる
- [ ] 起動直後に選択されているのがガチャタブであり、タブ選択状態が永続化されず再起動のたびにガチャから始まる
- [ ] 図鑑画面に、部位ごとのセクション見出しと 3 列のグリッドが表示される
- [ ] セクションの順序が `BodyPart.sortOrder` 昇順であり、ご褒美（`rest`）セクションが**末尾**に置かれる
- [ ] 各セクション内のセルが `Rarity.sortOrder` 昇順（N → R → SR → UR）に並び、同一レア度内はカタログの記載順を保つ（同じカタログに対して並びが常に同一である）
- [ ] 全セクションのセル数の合計が `StretchCatalog.shared.totalCount` と一致する
- [ ] セクション数が「1 件以上の種目を持つ部位の数」と一致し、0 件の部位のセクションが描かれない
- [ ] ご褒美カード（`kind == .reward`）が通常の部位セクションと同じセル表現で描画される（reward 専用の分岐が `Collection/` 配下に存在しない）

### 未入手 / 入手済みの表現

- [ ] 入手済み集合が空のとき、全セルが未入手表示（シルエット + 「???」）になる
- [ ] 入手済み集合がカタログの全 ID を含むとき、全セルが入手済み表示（絵文字 + 種目名）になる
- [ ] 未入手セルの `displayName` が **「???」** であり、派生モデルに `StretchItem.name` が載っていない
- [ ] 未入手セルにも **レア度バッジが表示され**、所属する部位セクションに配置される（部位とレア度は伏せない）
- [ ] 未入手セルの派生モデルに実施時間・手順・注意が含まれない
- [ ] 入手済みセルの `displayName` が `StretchItem.name` と一致する
- [ ] `emoji` が 2 文字以上の種目でも、描画される絵文字が先頭 1 文字のみになる
- [ ] `emoji` が空文字の種目でもクラッシュせず、セルのレイアウトが崩れない
- [ ] 入手済み集合にカタログに存在しない ID が含まれていても、クラッシュせず表示に影響しない
- [ ] 入手済み集合に含まれない種目が、いかなる経路でも入手済み表示にならない

### タップ挙動

- [ ] 入手済みセルをタップすると詳細シートが開き、`StretchCardView(item:style: .detail)` で手順・実施時間・注意が表示される
- [ ] 詳細シートに「閉じる」があり、タップでシートが閉じる
- [ ] 詳細シートに「はじめる」等のタイマー起動導線が存在せず、図鑑からタイマーが起動しない
- [ ] 未入手セルをタップしてもシートが開かず、そのセルの種目名ラベルが「???」から **「未入手」** に差し替わる
- [ ] 「未入手」と表示されるセルが常に **1 つ以下**である（別の未入手セルをタップすると前のセルが「???」に戻る）
- [ ] 同じ未入手セルを再度タップすると「???」に戻る
- [ ] 未入手セルのタップで入手状態・実施記録・連続日数のいずれも変化しない
- [ ] 図鑑画面を離れて戻ると「未入手」の表示状態が解除されている（状態が永続化されていない）

### 更新と他機能との整合

- [ ] タイマーを完走した種目が、図鑑タブへ切り替えた時点で入手済み表示になっている
- [ ] タイマーを「やめる」で中断した種目は、図鑑で未入手表示のままである
- [ ] `onAppear` と `scenePhase == .active` への復帰で図鑑が再構築される
- [ ] `Gacha/` 配下が 0 ファイル変更である
- [ ] `Timer/` 配下が 0 ファイル変更である
- [ ] `Card/` 配下が 0 ファイル変更である
- [ ] `Record/` 配下が 0 ファイル変更である
- [ ] `Catalog/` 配下の変更が 0 ファイル、または `BodyPart.rest.displayName` の 1 ケース追記のみである（`StretchCatalog.json` の差分は 0 件）
- [ ] 図鑑が `PracticeStore` の読み取り API（`ownedItemIDs()` / `isOwned(_:)`）のみを呼び、`record` / `loadIndex` / `refreshForCurrentDay` を呼ばない
- [ ] gacha-draw / practice-record の既存条件「ガチャ 1 回あたりの fetch が 0 本・save が 1 回」「起動時の索引読み込みが fetch 1 本」が本機能の導入後も維持される

### 純粋性・性能・規模

- [ ] `CollectionSectionBuilder.build` が `[StretchItem]` と `Set<String>` のみに依存し、SwiftUI・SwiftData・`PracticeStore`・システム時刻・乱数を参照しない（import と引数で確認できる）
- [ ] 図鑑の表示・再構築・詳細シート提示のいずれにおいても SwiftData の fetch が **0 本**・save が **0 回**である
- [ ] `CollectionSectionBuilder.build` の **10,000 回の実行が 2 秒以内**に完了する（テスト実行環境での上限値。実機での設計目標は 1 回 1ms 未満）
- [ ] 本機能が SwiftData のモデルを 1 つも追加せず、`ModelContainer` の登録内容が変わっていない
- [ ] 本機能が UserDefaults・ファイル・キーチェーンのいずれにも書き込まない（既読フラグ・スクロール位置を永続化しない）
- [ ] コンプ率・達成率・件数（「3/5」等）の表示が図鑑画面に存在しない
- [ ] NEW バッジおよび既読状態を表す UI・データが存在しない

### 構造・依存

- [ ] `Collection/` 配下のソースが `SwiftData` / `URLSession` / `Network` / `CFNetwork` / `UserNotifications` を import していない
- [ ] `Collection/` 配下に `print` / `os_log` / `debugPrint` によるログ出力が存在しない
- [ ] `Collection/` 配下のソースが `Gacha/` / `Timer/` 配下の型を参照していない
- [ ] `Collection/` 配下に `.animation` / `withAnimation` / `Task` / `async` が存在しない
- [ ] セル・シート内のテキストがすべて `Text(verbatim:)` で描画され、`LocalizedStringKey` を受ける `Text` イニシャライザが `Collection/` 配下に存在しない
- [ ] `Collection/` 配下にレア度色の定数が存在せず、バッジ・枠線の色が `RarityStyle` を参照している
- [ ] `Collection/` 配下に部位名・レア度名・種目名の文字列リテラルが存在しない（`displayName` と `StretchItem` 経由でのみ取得している。本機能固有の固定文言「図鑑」「???」「未入手」「閉じる」を除く）
- [ ] 画像・音源・カラーセットを 1 つも追加していない（Assets.xcassets への追加が 0 件）
- [ ] カタログに種目を 1 件追加したフィクスチャで、`Collection/` 配下のコードを 1 行も変更せずに、その種目が該当部位セクションの正しい位置に現れ、未入手表示になる
- [ ] 本機能の実装によりビルド警告が 0 件である

### 手動計測・表示確認

- [ ] **【手動計測】** 実機のコールドスタートからガチャ画面が操作可能になるまで（T1）が **1.19 秒以下**である（gacha-draw / practice-record の既存条件。本機能の増分は 0）
- [ ] **【手動計測】** 実機のコールドスタートから結果カード表示までのエンドツーエンドが **3.0 秒以内**である（同上）
- [ ] **【手動計測】** 図鑑タブを選択してから初回描画が完了するまでが **1 秒以内**である（設計目標は 100ms 以内）
- [ ] **【表示確認】** iPhone SE（375×667）縦画面で、3 列グリッドが横方向にはみ出さず、初期表示で「首」5 件と「肩」の 1 行目が視界に入る
- [ ] **【表示確認】** 全 26 件をスクロールして到達でき、途中でセルのクリップ・重なり・文字の切れが発生しない
- [ ] **【表示確認】** 未入手セルの絵文字がグレーで、入手済みセルの絵文字が本来の色で描かれ、両者が一目で区別できる
- [ ] **【表示確認】** 詳細シートで、レア度バッジ・部位チップ・種目名・実施時間・「閉じる」が常時可視であり、手順のみがスクロールする
- [ ] **【表示確認】** 手順 6 件 × 各 60 文字（カタログ規約の最大）のフィクスチャでも、詳細シートで全文がスクロールで到達可能である
- [ ] **【表示確認】** ライトモード / ダークモードの両方で、セクション見出し・レア度バッジ・シルエット・「???」が識別でき、未入手セルと入手済みセルが区別できる
- [ ] **【表示確認】** Dynamic Type を AX5 にしても、セルの文字がクリップされず、行が縦に伸びるだけで全件へスクロール到達できる
- [ ] **【表示確認】** VoiceOver で、セクション見出し（部位名）に続いて入手済みセルが「首の横倒し、レア度 N、入手済み」、未入手セルが「未入手、レア度 N」と読まれ、絵文字と「???」が読み上げられない
- [ ] **【表示確認】** VoiceOver で、未入手セルをタップして表示が「未入手」に変わった後も、読み上げ内容が変化しない

## 参照

- 機能仕様ドキュメント: `veronica-docs/stretch-gacha/features/stretch-collection/spec.md`
  - §1 責務境界 / §2 整理軸 / §3 未入手の見せ方 / §4 表示用派生モデル / §5.1〜§5.5 画面仕様 / §6 データモデル（永続化なし）/ §7 処理フロー
  - 「非機能要件」「非機能優先順位との対応」「セキュリティ」「実装方針（既存実装との整合・変更対象ファイル・実装手順）」「仮置き依存」
- 関連機能仕様: stretch-catalog / stretch-card / practice-record / gacha-draw / stretch-timer（いずれも status: issued_local）、collection-progress（後回し）、safety-notice（未着手）
