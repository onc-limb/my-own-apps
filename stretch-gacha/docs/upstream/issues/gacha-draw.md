---
feature: gacha-draw
spec: veronica-docs/stretch-gacha/features/gacha-draw/spec.md
generated_at: 2026-08-18
---

# gacha-draw: ワンタップ抽選（2 段重み付きガチャ）とレア度別演出の実装

## 背景

ホーム画面から「今やるストレッチ」を決めるまでの意思決定コストが、継続の最大の障害になっている。種目一覧から自分で選ばせる方式では、L1 最優先の学習容易性（説明書なしで初回起動 60 秒以内に実施開始）を満たせない。

種目データを持つ stretch-catalog は仕様確定済み（status: issued_local）で、読み取り専用 API（`StretchCatalog.shared` / `rarityWeights` / `items(rarity:)`）が利用可能。一方 practice-record・stretch-card・safety-notice は未着手のため、本機能は依存ポートと暫定ビューを自前で用意し、単体でビルド・テスト・実機動作が成立する状態を成果物とする。

## ゴール

- 「回す」ボタン 1 タップで、カタログ 26 件（ストレッチ 24 + ご褒美カード 2）から 1 本だけを抽選し、演出を挟んで結果カードへ引き渡す。
- レア度の重み付き抽選 → 同レア度内の重み付き抽選という 2 段構成を、乱数生成器を注入できる純粋関数として実装し、確率・補正の挙動をすべてユニットテストで検証可能にする。
- 同レア度内の補正は「未入手を出やすくする（重み 2 倍）」「同日に出た種目を避ける」の 2 つだけに限定し、天井・確定枠は入れない。
- コールドスタートから結果カード表示までのエンドツーエンドを 3.0 秒以内に収め、演出中は 60fps を維持する（演出中にメインスレッド I/O を一切走らせない）。

## スコープ（やること / やらないこと）

### やること

- ガチャ画面（`GachaView`）: 「回す」ボタン・演出・結果への遷移。アプリのルート画面
- 2 段抽選ロジック（`GachaDrawer`）: レア度抽選 + 同レア度内抽選（未入手補正 / 同日重複回避）
- 決定的乱数生成器（`SeededRandomGenerator`、SplitMix64）の実装と注入口
- 当日ドロー状態（`DailyDrawState`）の SwiftData 永続化。同日重複回避をアプリ再起動をまたいで機能させる
- 未入手判定の依存ポート（`OwnershipProviding`）の定義と、practice-record 未実装時の既定実装（`EmptyOwnershipProvider`）
- 演出: N/R 1.2 秒・SR/UR 1.8 秒、SR/UR のみ色味変化とハプティクス、全レア度で画面タップによるスキップ
- Reduce Motion 時の短縮演出（0.3 秒フェード）
- 上記すべてのユニットテスト（分布・補正・状態遷移・永続化）

### やらないこと

- **結果カードのレイアウト・内容**（stretch-card の責務）。本機能は `StretchItem` を渡すところまでで、差し替え前提の最小プレースホルダのみ持つ
- **タイマー起動**（stretch-timer）、**図鑑登録・履歴・連続日数の記録**（practice-record）、**図鑑画面**（stretch-collection）
- **種目データの保持**（stretch-catalog が唯一の正。本機能はカタログを読むだけ）
- 天井・確定枠（q1 回答で明示的に不採用）
- 10 連ガチャ・複数同時抽選・引き直し（リロール）
- 回数制限・スタミナ・クールダウン（1 日に何回でも回せる）
- 効果音・BGM（音源アセットを一切持たない。フィードバックはハプティクスのみ）
- 画像・イラスト・Lottie 等のアニメーションアセット（SwiftUI のシェイプと絵文字のみで構成）
- 演出のユーザー設定（速度・オンオフの設定画面）。Reduce Motion への追随のみ行う
- 抽選履歴の一覧表示・確率表示 UI（課金がないため提供確率の開示は不要）
- サーバー・外部 API・アナリティクス送信（L1 制約）

## 実装方針の要約

**技術構成**: Swift 5.9+ / SwiftUI（iOS 17 以上）、`@Observable`、SwiftData（当日ドロー状態 1 モデルのみ）、ハプティクスは `UIImpactFeedbackGenerator(style: .medium)`、テストは XCTest。外部ライブラリ 0。

**抽選アルゴリズム**（`GachaDrawer.draw(_:using:)`、副作用なしの純粋関数）を以下の順で適用する。

1. **レア度抽選**: `catalog.rarityWeights`（N 60 / R 27 / SR 10 / UR 3）で累積和による重み付き選択。候補 0 件のレア度は事前除外して正規化（防御的処理）。**この段は未入手・同日重複の影響を一切受けない**。
2. **同日重複回避**: 選ばれたレア度の候補から `drawnTodayItemIDs` を除いて `pool` を作る。`pool` が空なら解除して全候補に戻す。**レア度の再抽選はしない**。
3. **未入手補正つき選択**: `pool` の各要素に重み（入手済み 1 / 未入手 2）を与え、累積和で 1 件を確定。

全体で最大 26 要素の線形処理 1 回。本番の乱数は `SystemRandomNumberGenerator`（セキュリティ用途ではないため暗号学的乱数 API は使わない旨を実装コメントに明記）、テストは `SeededRandomGenerator` を注入する。

**永続化**: `DailyDrawState`（`dayKey` / `drawnItemIDs` / `updatedAt`）を SwiftData に持ち、**常に 0 行または 1 行**。日付が変わったら行を追加せず既存行を上書きリセットする。`dayKey` は `Calendar.current.dateComponents` から組み立て（`DateFormatter` は使わない）、現在時刻は `DateProviding` として注入する。読み戻し時はカタログに存在しない ID を破棄する（永続化データを「信頼しない入力」として扱う）。

**処理フロー**: `onAppear` でカタログをウォームアップ + `loadDrawnTodayIDs()`（fetch 1 本）→ タップで ownership 取得 → 抽選（同期・O(26)）→ `recordInMemory`（I/O なし）→ `phase = .performing` → 演出（タップでいつでもスキップ）→ `revealed` で `flush()`（save 1 回）。**演出中に I/O を 1 回も走らせない**ことを設計上の固定点とする。

**状態機械**: `GachaPhase`（`idle` / `performing(GachaOutcome)` / `revealed(StretchItem)`）と `spin()` / `skip()` / `onRevealed()`。時間経過はビュー側の `.task` が駆動し、テストは実時間を待たずメソッド直接呼び出しで検証する（壁時計時間をアサートしない）。

**未実装機能との接続**: 入手済み ID は `OwnershipProviding` 経由（既定は空集合 → 同レア度内は均等抽選に正しく縮退）。結果表示は `PlaceholderResultView`（種目名 + 絵文字 + レア度バッジのみ）で、stretch-card 側がここを置き換える。依存の向きは gacha-draw → stretch-catalog / `OwnershipProviding` の一方向に保つ。

**調整値の集約**: 未入手倍率は `DrawTuning`、演出秒数は `GachaAnimation` に集約し、コード中に数値を散らさない。レア度の重みは JSON 側（stretch-catalog）に残したまま触らない。

**変更対象ファイル**:

```
stretch-gacha/
├── StretchGacha/
│   ├── Gacha/
│   │   ├── GachaDrawer.swift            [新規] 2 段抽選の純粋関数 + DrawContext / DrawTuning
│   │   ├── SeededRandomGenerator.swift  [新規] SplitMix64 の決定的 RNG
│   │   ├── OwnershipProviding.swift     [新規] ポート定義 + EmptyOwnershipProvider
│   │   ├── DailyDrawState.swift         [新規] @Model（dayKey / drawnItemIDs / updatedAt）
│   │   ├── DailyDrawStore.swift         [新規] fetch / リセット / メモリ更新 / flush
│   │   ├── GachaAnimation.swift         [新規] 演出秒数・区間の定数
│   │   ├── GachaViewModel.swift         [新規] @Observable 状態機械
│   │   ├── GachaView.swift              [新規] ボタン + カプセル演出 + スキップ
│   │   └── PlaceholderResultView.swift  [新規] stretch-card 実装までの暫定表示
│   └── StretchGachaApp.swift            [変更] modelContainer に DailyDrawState を登録、ルートを GachaView に
└── StretchGachaTests/
    └── GachaDrawTests.swift             [新規] 分布・補正・状態遷移・永続化のテスト
```

**実装順**: `SeededRandomGenerator` → `GachaDrawer`（`selectRarity` / `applyDailyDedup` / `selectItemWithOwnershipBoost` の 3 ヘルパに分割）→ `OwnershipProviding` → `DailyDrawState` / `DailyDrawStore` → `GachaAnimation` → `GachaViewModel` → `GachaView` → `PlaceholderResultView` → テスト → 仕上げ確認。分布テストは in-memory の `ModelContainer`（`isStoredInMemoryOnly: true`）とシード固定 RNG で行う。テストは範囲・上限でアサートし、「特定シードで特定の種目が出る」ような実装順序依存の厳密アサートは書かない。

## 受け入れ条件

- [ ] ガチャ画面が起動時のルート画面として表示され、「回す」ボタン 1 タップで抽選 → 演出 → 結果表示まで到達する
- [ ] `GachaDrawer.draw(_:using:)` が `StretchCatalog` / 入手済み集合 / 当日集合 / 乱数生成器のみに依存し、SwiftUI・SwiftData・システム時刻を参照しない（import と引数で確認できる）
- [ ] シード固定の `SeededRandomGenerator` で同じ `DrawContext` を与えると、常に同じ結果列が再現される
- [ ] シード固定で 100,000 回抽選したとき、レア度別の出現割合が期待値（N 60% / R 27% / SR 10% / UR 3%）の **相対 ±20% 以内**に収まる
- [ ] 同じ 100,000 回の抽選が **2 秒以内**に完了する（テスト実行環境での上限値。実機での設計目標は 1 回 1ms 未満）
- [ ] 入手済み集合が空のとき、同レア度内の各種目の出現割合が均等（相対 ±20% 以内）になる
- [ ] N 12 件のうち 4 件を入手済みとしたとき、未入手 1 件あたりの出現割合が入手済み 1 件あたりの **約 2 倍**（比が 1.6〜2.4 の範囲）になる
- [ ] 未入手補正を適用しても、レア度別の合計出現割合が期待値の相対 ±20% 以内に保たれる（補正はレア度段に影響しない）
- [ ] 当日集合にレア度 SR の 4 件中 3 件が入っているとき、SR が選ばれた抽選では **必ず残り 1 件**が返る
- [ ] 当日集合にレア度 SR の 4 件すべてが入っているとき、SR が選ばれた抽選は 4 件の中から返る（重複回避が解除される）
- [ ] 当日集合による除外が行われても、レア度別の合計出現割合が期待値の相対 ±20% 以内に保たれる（レア度の再抽選が起きない）
- [ ] 天井処理が存在しない: 未入手が残っていても、一定回数の連続重複後に未入手が確定で返る挙動がない（連続重複が発生し得ることをテストで示す）
- [ ] `DailyDrawState` の行数が、日付をまたいで 10 回以上抽選しても **常に 1 行以下**である
- [ ] `dayKey` が前日のまま残っている状態で抽選すると、行が上書きリセットされ `drawnItemIDs` が当日分のみになる
- [ ] `drawnItemIDs` にカタログに存在しない ID が混入していても、クラッシュせず該当 ID を無視して抽選が成立する
- [ ] ガチャ画面の初期化で SwiftData の fetch が **1 本**、ガチャ 1 回あたりの fetch が **0 本**・save が **1 回**である
- [ ] 演出時間の定数が N/R = 1.2 秒、SR/UR = 1.8 秒、Reduce Motion = 0.3 秒である
- [ ] `phase == .performing` の間に `spin()` を呼んでも抽選が実行されず、結果が変わらない（連打による二重抽選が起きない）
- [ ] `skip()` を `performing` 中に呼ぶと、待ち時間なしで `revealed` へ遷移し、返される種目が演出開始時に確定したものと同一である
- [ ] 演出完走時とスキップ時の双方で `onRevealed()` が 1 回だけ呼ばれ、`flush()` による save が 1 回だけ発生する
- [ ] SR/UR の抽選でのみハプティクスが発火し、N/R では発火しない（発火呼び出しを差し替え可能にして回数を検証する）
- [ ] `Gacha/` 配下のソースが `URLSession` / `Network` / `CFNetwork` を import していない
- [ ] `Gacha/` 配下に `print` / `os_log` によるログ出力が存在しない
- [ ] 画像・音源アセットを 1 つも追加していない（Assets.xcassets への追加が 0 件）
- [ ] カタログに種目を 1 件追加したフィクスチャで、`Gacha/` 配下のコードを 1 行も変更せずに抽選が成立し、追加種目が抽選対象に含まれる
- [ ] **【上位条件】実機のコールドスタート（プロセス起動）から結果カード表示までのエンドツーエンドが 3.0 秒以内**（SR/UR の最長演出・演出スキップなしの最悪ケース。手動計測で確認する）
- [ ] 上記エンドツーエンド条件の内訳として、実機のコールドスタートからガチャ画面が操作可能になるまで（T1）が **1.19 秒以下**（設計目標 1.00 秒に対する検収上の上限。T2 の最大 1.81 秒と合わせて 3.0 秒を超えないための従属条件。手動計測で確認する）
- [ ] 本機能の実装によりビルド警告が 0 件である

## 参照

- 機能仕様ドキュメント: `veronica-docs/stretch-gacha/features/gacha-draw/spec.md`
- 依存（読み取り専用）: stretch-catalog（`StretchCatalog.shared` / `rarityWeights` / `items(rarity:)` / `totalCount`、status: issued_local）
- 後続で接続予定: practice-record（`OwnershipProviding` の実装差し替え）、stretch-card（`PlaceholderResultView` の置き換え）、safety-notice（初回注意書きのルート側での被せ表示）
