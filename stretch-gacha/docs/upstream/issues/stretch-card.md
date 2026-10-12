---
feature: stretch-card
spec: veronica-docs/stretch-gacha/features/stretch-card/spec.md
generated_at: 2026-08-18
---

# stretch-card: ガチャ結果カードビュー（StretchCardView）の実装と PlaceholderResultView の置き換え

## 背景

gacha-draw は抽選で確定した `StretchItem` を表示する場所として、暫定の `PlaceholderResultView` を置いている。この暫定実装では、部位・レア度・種目名・実施時間・手順・種目固有の注意を 1 画面で読み切れる密度に達しておらず、L1 最優先の非機能要件である「説明書なしで初回起動 60 秒以内に最初のガチャ → 実施開始」のうち、結果カード読了に割り当てられた約 20 秒を満たせない。

また、gacha-draw は「コールドスタート → 結果表示 3.0 秒」に対して余裕が 190ms しかなく（抽選 0.01 秒 + 演出 1.80 秒 + コールドスタート分で合計 2.81 秒）、結果表示部品が独自のアニメーションや非同期処理を持つと予算を超える。結果表示部品は「`StretchItem` の純粋な関数」として設計する必要がある。

さらに、レア度に対応する色が gacha-draw の演出側とカード側に二重定義されると、レア度の追加・変更時に両方を直す必要が生じる。将来の stretch-collection（図鑑の入手済み種目詳細）でも同じカードを再利用したい。

## ゴール

- `PlaceholderResultView` を `StretchCardView` で置き換え、部位・レア度・種目名・実施時間・番号付き手順・種目固有の注意が 1 画面で読み切れる密度で描画される。
- カードが gacha-draw の時間予算に **0 秒**しか追加しない（独自アニメーション・非同期処理・I/O を一切持たない）ことを、構造的に担保する。
- 表示ロジックを純粋関数（`StretchCardContent.make(from:)` / `DurationLabel.text(seconds:)` / `RarityStyle`）に隔離し、受け入れ条件のほぼ全項目を UI テスト基盤なしのユニットテストで検証できる状態にする。
- レア度色の単一の正を `RarityStyle` に置き、gacha-draw の演出色もそこを参照する。
- スタイル 2 種（`.result` / `.detail`）とフッタースロットを備え、将来の stretch-timer（「はじめる」ボタン）と stretch-collection（詳細表示）がカードのコードを変更せずに利用できる状態にする。
- Dynamic Type / VoiceOver / 色覚多様性 / ダークモードに対応する。

## スコープ（やること / やらないこと）

### やること

- 表示用派生モデル `StretchCardContent` と、`StretchItem` から組み立てる純粋関数 `make(from:)`（防御的処理をここに集約）
- カード本体ビュー `StretchCardView`（レア度バッジ / 部位チップ / 絵文字 / 種目名 / 実施時間 / 区切り線 / 番号付き手順 / 注意）
- スタイル 2 種: `.result`（ガチャ結果用: 絵文字 56pt・種目名 `.title2` bold・枠線 1.5pt）/ `.detail`（図鑑詳細用: 絵文字 40pt・種目名 `.title3` bold・枠線 1.0pt）。差分はメトリクスのみ
- フッタースロット（`@ViewBuilder`）。`Footer == EmptyView` の便利イニシャライザも用意する
- レア度 → 色・ラベルの対応 `RarityStyle`（ライト / ダーク両対応、アセット追加なし）と `AdaptiveColor.make(light:dark:)`
- 秒数 → 表示文字列 `DurationLabel`（3 分岐、`DateComponentsFormatter` を使わない）
- 手順エリアのみをスクロール可能にし、ヘッダとフッターを常時可視に保つレイアウト（`CardMetrics` / `StretchCardStyle` に数値を集約）
- `PlaceholderResultView` の削除と `GachaView` の結果表示箇所の差し替え、演出のレア度色参照の `RarityStyle.accent(for:)` への統一
- Dynamic Type / VoiceOver / 色覚多様性 / ダークモードへの対応
- 上記すべてのユニットテスト（派生値・境界値・防御的処理・コントラスト・性能・拡張性の実証）

### やらないこと

- **抽選ロジック・演出**（gacha-draw の責務）。カードは確定済みの `StretchItem` を受け取るだけ
- **種目データの保持・検証**（stretch-catalog が唯一の正。カードは読むだけ・検証しない）
- **タイマーの起動と実行**（stretch-timer）。フッターにボタンの「置き場所」を用意するところまで
- **実施記録・図鑑登録・入手済みバッジ**（practice-record）。「登録済み」等の状態表示をカードに持たせない
- **図鑑画面そのもの・未入手のシルエット表現**（stretch-collection）
- 画像・イラスト・図解アセット（視覚補助は `StretchItem.emoji` の 1 文字のみ）
- カード自身の入場・退場アニメーション（gacha-draw のクロスフェード区間に乗せる。カード側は `transition(.opacity)` の宣言のみ）
- カードのシェア・スクリーンショット出力・テキストコピー・お気に入り登録
- カードのカスタマイズ設定（文字サイズ設定画面・配色テーマ切り替え）。OS の Dynamic Type / 外観設定への追随のみ
- 多言語化（日本語直書き。`Localizable.strings` を作らない）
- 手順テキストのリッチ表現（Markdown 解釈・リンク検出・部分強調）
- サーバー・外部 API・アナリティクス送信（L1 制約）
- SwiftData モデルの定義・永続化（`SwiftData` を import しない）
- `make(from:)` のキャッシュ、`LazyVStack` による手順リストの仮想化、描画時間の計測基盤・ログ出力

## 実装方針の要約

**依存の向きは stretch-card → stretch-catalog の一方向のみ。** stretch-card から gacha-draw / timer / record / collection を参照しない。

**技術**: Swift 5.9+ / SwiftUI（iOS 17 以上）。`UIKit` は `UIColor(dynamicProvider:)` にのみ使用。SwiftData は import しない。テストは XCTest。外部ライブラリ 0。

**変更対象ファイル**:

```
stretch-gacha/
├── StretchGacha/
│   ├── Card/
│   │   ├── StretchCardContent.swift     [新規] 表示用派生モデル + make(from:)
│   │   ├── DurationLabel.swift          [新規] 秒数 → 表示文字列（3 分岐）
│   │   ├── RarityStyle.swift            [新規] レア度 → accent / badgeForeground
│   │   ├── AdaptiveColor.swift          [新規] light/dark 2 色から Color を作る helper
│   │   ├── CardMetrics.swift            [新規] 余白・角丸・行高・枠線幅の定数
│   │   ├── StretchCardStyle.swift       [新規] .result / .detail のメトリクス差分
│   │   └── StretchCardView.swift        [新規] カード本体 + フッタースロット
│   └── Gacha/
│       ├── GachaView.swift              [変更] 結果表示を StretchCardView に差し替え。
│       │                                        演出の色味変化を RarityStyle.accent(for:) 参照に統一
│       └── PlaceholderResultView.swift  [削除] 役割を StretchCardView が引き継ぐ
└── StretchGachaTests/
    └── StretchCardTests.swift           [新規] 派生値・境界値・防御的処理・コントラスト・性能
```

**実装手順**:

1. `AdaptiveColor.swift`: `static func make(light: UInt32, dark: UInt32) -> Color`（引数は `0xRRGGBB`）。`UIColor(dynamicProvider:)` で `userInterfaceStyle` を見て切り替える。RGB 成分を取り出す純粋関数もここに置き、テストからコントラスト比計算に使えるよう `internal` にする。
2. `RarityStyle.swift`: N `#6E6E73`/`#98989D`、R `#2A62C4`/`#6FA8FF`、SR `#7B4FD1`/`#B69BFF`、UR `#8C6000`/`#F0C14B`（ライト/ダーク）を定義し、`accent(for:)` / `badgeForeground(for:)` を実装。バッジ文字色はライト `#FFFFFF` / ダーク `#1C1C1E`。`switch rarity` を全ケース網羅し `default` を書かない。
3. `DurationLabel.swift`: `seconds < 60` → 「N秒」、`seconds % 60 == 0` → 「N分」、それ以外 → 「N分M秒」。`DateComponentsFormatter` を使わない旨をコメントに残す。
4. `StretchCardContent.swift`: 変換規則を実装。`emoji` は `String(item.emoji.prefix(1))`、`durationSeconds` は `1...` のみ変換して 0 以下は `nil`、`steps` は各要素 trim + 空要素除去、`caution` は trim 後に空なら `nil`、`name` は空文字でもそのまま。各防御的処理を独立した式に分け、テストから個別に確認できる形にする。`kind` による分岐をしない。
5. `CardMetrics.swift` / `StretchCardStyle.swift`: レイアウト数値を定数化。ビューにマジックナンバーを書かない。
6. `StretchCardView.swift`: 上から ①ヘッダ行（左レア度バッジ / 右部位チップ）②絵文字 ③種目名（最大 2 行・`.minimumScaleFactor(0.8)`）④実施時間（「⏱ 60秒」）⑤区切り線 ⑥手順（`ScrollView` 内・通常の `VStack`）⑦注意（⚠️ + `.caption` + 角丸 8pt の淡色背景、スクロール領域内）を実装。ヘッダとフッターは `VStack` の固定位置。すべてのテキストを `Text(verbatim:)` で描く。`.animation` / `withAnimation` / `Task` を書かない。見出しラベル（「手順」「注意」）を置かない。VoiceOver は「ヘッダ+名称+時間」を `accessibilityElement(children: .combine)` で 1 要素にまとめ、絵文字は `.accessibilityHidden(true)`、手順は 1 行 1 要素（「手順 1、…」）。
7. `GachaView.swift` の差し替え: `PlaceholderResultView(item:)` を `StretchCardView(item:style: .result) { Button("もう1回") { ... } }` に置換。演出中のレア度色参照を `RarityStyle.accent(for:)` に統一し、gacha-draw 側の重複定数を削除。`PlaceholderResultView.swift` を削除。`GachaViewModel` / `GachaDrawer` / `GachaAnimation` の秒数 / `DailyDrawStore` には変更を加えない。
8. `StretchCardTests.swift`: 受け入れ条件の各項目に 1:1 対応するテストを実装。コントラスト比は WCAG の相対輝度式（`L = 0.2126R + 0.7152G + 0.0722B`、各成分は sRGB のガンマ逆変換後）をテスト内ヘルパで計算。同梱カタログ 26 件を回して `make(from:)` がクラッシュしないことを確認。
9. 拡張性の実証テスト: stretch-catalog のフィクスチャ JSON（26 件 + ダミー 1 件）を読み、追加種目に対して `make(from:)` が正しい派生値を返すことを確認する。
10. 仕上げ確認: import 制約・ログ不在・アセット追加 0 件・ビルド警告 0 件を確認し、iPhone SE 実機 / シミュレータでライト・ダーク・Dynamic Type AX5 の 3 条件を目視確認する。

**レイアウト予算（設計基準機 iPhone SE 375×667・縦画面固定）**: 画面上余白 16 + カード最大 543 + 間隔 16 + フッター 56 + 下余白 16 = 647（セーフエリア高と一致）。カード固定部は種目名 2 行の最悪ケースで 265pt、手順スクロール領域は 278pt 以上（種目名 1 行なら 307pt）。カタログ規約の最大（6 件 × 各 60 文字 = 626pt）でもヘッダ・フッターは常時可視のまま、手順だけがスクロールで全文に到達できる。スクロール可否のヒントは OS 標準のインジケータのみ。

**Dynamic Type**: ヘッダ（バッジ・チップ・種目名・実施時間）は上限 `.xxxLarge`（固定部が伸びて手順領域が消えるのを防ぐため）。手順・注意はスクロール領域内なので上限なし（AX5 まで追随）。

## 受け入れ条件

- [ ] ガチャ結果表示が `PlaceholderResultView` ではなく `StretchCardView` で描画され、`PlaceholderResultView.swift` がリポジトリから削除されている
- [ ] `StretchCardView` に部位・レア度・種目名・実施時間・手順・種目固有の注意がすべて描画される
- [ ] `StretchCardContent.make(from:)` が `StretchItem` のみに依存し、SwiftUI の描画・SwiftData・システム時刻・乱数を参照しない（import と引数で確認できる）
- [ ] `DurationLabel.text(seconds:)` が 20→「20秒」、45→「45秒」、59→「59秒」、60→「1分」、75→「1分15秒」、90→「1分30秒」を返す
- [ ] `RarityStyle` が `Rarity` の 4 ケースすべてに accent / badgeForeground を返し、`rarityLabel` が「N」「R」「SR」「UR」になる
- [ ] バッジの文字色と塗り色のコントラスト比が、ライト / ダーク × 4 レア度の **全 8 組で 4.5:1 以上**である（WCAG 相対輝度式でテスト内計算。設計上の最小は約 5.1 で閾値に余裕がある）
- [ ] レア度がバッジの文字としても表示され、色のみでレア度を伝える箇所が存在しない
- [ ] `emoji` が 2 文字以上の `StretchItem` を渡しても、描画される絵文字が先頭 1 文字のみになる
- [ ] `emoji` が空文字の `StretchItem` を渡してもクラッシュせず、レイアウトが崩れない
- [ ] `steps` が空配列の `StretchItem` を渡すと、手順セクションと直前の区切り線が描かれず、クラッシュしない
- [ ] `steps` に空白のみの要素が含まれる場合、その要素が除去されて番号が連番のまま維持される
- [ ] `caution` が `nil` / 空文字 / 空白のみのとき注意セクションが描かれず、非空のときだけ描かれる
- [ ] `durationSeconds` が 0 以下のとき `durationText` が `nil` になり、時間チップが描かれない
- [ ] `name` が空文字でもクラッシュせず、他の要素の配置が変わらない
- [ ] `kind == .reward` の種目（`reward-01` / `reward-02`）が、`kind == .stretch` と同じレイアウト経路で描画される（reward 専用の分岐が `Card/` 配下に存在しない）
- [ ] 同梱カタログ 26 件すべてに対して `StretchCardContent.make(from:)` がクラッシュせず、`rarityLabel` / `bodyPartLabel` / `durationText` が非空を返す
- [ ] `StretchCardContent.make(from:)` の **10,000 回の実行が 2 秒以内**に完了する（テスト実行環境での上限値。実機での設計目標は 1 回 200µs 未満）
- [ ] `StretchCardView` のソースに `.animation` / `withAnimation` / `Task` / `Task.sleep` / `async` が存在しない（カードが gacha-draw の時間予算に 0 秒しか追加しないことの構造的な担保）
- [ ] 手順・注意・種目名がすべて `Text(verbatim:)` で描画され、`LocalizedStringKey` を受ける `Text` イニシャライザが `Card/` 配下に存在しない
- [ ] `Card/` 配下のソースが `SwiftData` / `URLSession` / `Network` / `CFNetwork` を import していない
- [ ] `Card/` 配下に `print` / `os_log` / `debugPrint` によるログ出力が存在しない
- [ ] 画像・音源・カラーセットを 1 つも追加していない（Assets.xcassets への追加が 0 件）
- [ ] 部位名・レア度名の文字列リテラルが `Card/` 配下に存在しない（`displayName` 経由でのみ取得している）
- [ ] カタログに種目を 1 件追加したフィクスチャで、`Card/` 配下のコードを 1 行も変更せずに `make(from:)` が正しい派生値を返す
- [ ] レア度の色定義が `RarityStyle` の 1 箇所のみに存在し、`Gacha/` 配下に重複したレア度色定数が残っていない
- [ ] **【表示確認】** iPhone SE（375×667）縦画面で同梱 26 件を表示したとき、レア度バッジ・部位チップ・種目名・実施時間・フッターが常時可視であり、手順のみがスクロールする（手動確認）
- [ ] **【表示確認】** 手順 6 件 × 各 60 文字（カタログ規約の最大）のフィクスチャで、テキストのクリップ・はみ出しが発生せず、全文がスクロールで到達可能である（手動確認）
- [ ] **【表示確認】** Dynamic Type を AX5 にしても、ヘッダ（バッジ・名称・時間）が固定部に収まりフッターが画面外へ押し出されない（手動確認）
- [ ] **【表示確認】** ライトモード / ダークモードの両方で、文字が背景に埋もれず枠線・バッジが識別できる（手動確認）
- [ ] **【表示確認】** VoiceOver で「レア度 → 部位 → 種目名 → 実施時間」が 1 要素として読まれ、続いて「手順 1、…」の順に読み上げられ、絵文字が読み上げられない（手動確認）
- [ ] gacha-draw 側の受け入れ条件（コールドスタート → 結果カード表示 3.0 秒以内、T1 1.19 秒以下、演出秒数 1.2 / 1.8 / 0.3 秒）が本機能の導入後も引き続き満たされる（手動計測で確認する）
- [ ] 本機能の実装によりビルド警告が 0 件である

## 参照

- 機能仕様ドキュメント: `veronica-docs/stretch-gacha/features/stretch-card/spec.md`
- 依存する既存機能: stretch-catalog（`StretchItem` / `Rarity` / `BodyPart` / `ItemKind` / `displayName`。**Swift コードと JSON は変更しない**）
- 差し替え対象: gacha-draw（`GachaView` の結果表示箇所と演出の色参照のみ。`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` は変更しない）
- 将来の利用側: stretch-timer（フッタースロット）、stretch-collection（`.detail` スタイル）
