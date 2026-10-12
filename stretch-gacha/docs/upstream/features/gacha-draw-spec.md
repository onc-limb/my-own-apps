# 機能仕様: gacha-draw

## 変更履歴

- 2026-08-18 初版作成
- 2026-08-18 L3 指摘対応: 受け入れ条件のコールドスタート性能をエンドツーエンド 3.0 秒以内に一本化し、T1 の検収上限を 1.19 秒以下へ引き下げて従属させた

## 概要と提供価値

ホーム画面の「回す」ボタン 1 タップで、stretch-catalog が同梱する 26 件（ストレッチ 24 + ご褒美カード 2）から「今やるストレッチ」を **1 本だけ** 抽選し、1.2〜1.8 秒の演出を挟んで結果カードへ引き渡す機能。抽選は **レア度の重み付き抽選 → 同レア度内の重み付き抽選** の 2 段構成で、同レア度内には「未入手を出やすくする補正」と「同日に出た種目を避ける補正」の 2 つだけを入れる。

提供価値は 2 つ。

1. **意思決定コストゼロ**: 種目一覧から選ぶ操作を排除し、「開く → 1 タップ → もうストレッチが決まっている」状態を作る。L1 最優先の学習容易性（初回起動 60 秒以内に実施開始）の主要な担い手。
2. **偶然性と収集欲の両立**: レア度の重みで「当たり」の手応えを作りつつ、未入手 2 倍補正で図鑑コンプが確実に前進する。天井（N 回連続で未入手確定）は入れず、ガチャとしての偶然性を残す。

回数制限は設けない（1 日に何回でも回せる）。抽選ロジックは乱数生成器を注入できる純粋関数として実装し、重み・補正の挙動をすべてユニットテストで検証可能にする。

## スコープ（やること / やらないこと）

### やること

- ガチャ画面（`GachaView`）: 「回す」ボタン・演出・結果への遷移。アプリのルート画面
- 2 段抽選ロジック（`GachaDrawer`）: レア度抽選 + 同レア度内抽選（未入手補正 / 同日重複回避）
- 決定的乱数生成器（`SeededRandomGenerator`）の実装と注入口
- 当日ドロー状態（`DailyDrawState`）の SwiftData 永続化。同日重複回避をアプリ再起動をまたいで機能させる
- 未入手判定の依存ポート（`OwnershipProviding`）定義と、practice-record 未実装時の既定実装
- 演出: N/R 1.2 秒・SR/UR 1.8 秒、SR/UR のみ色味変化とハプティクス、全レア度で画面タップによるスキップ
- Reduce Motion 時の短縮演出（0.3 秒フェード）
- 上記すべてのユニットテスト（分布・補正・状態遷移・永続化）

### やらないこと

- **結果カードのレイアウト・内容**（stretch-card の責務）。本機能は `StretchItem` を渡すところまで。差し替え前提の最小プレースホルダのみ持つ
- **タイマー起動**（stretch-timer）、**図鑑登録・履歴・連続日数の記録**（practice-record）、**図鑑画面**（stretch-collection）
- **種目データの保持**（stretch-catalog が唯一の正。本機能はカタログを読むだけ）
- 天井・確定枠（q1 回答で明示的に不採用）
- 10 連ガチャ・複数同時抽選・引き直し（リロール）
- 回数制限・スタミナ・クールダウン
- 効果音・BGM（音源アセットを一切持たない。フィードバックはハプティクスのみ）
- 画像・イラスト・Lottie 等のアニメーションアセット（SwiftUI のシェイプと絵文字のみで構成）
- 演出のユーザー設定（速度・オンオフの設定画面）。Reduce Motion への追随のみ行う
- 抽選履歴の一覧表示・確率表示 UI（提供確率の開示画面は課金がないため不要）
- サーバー・外部 API・アナリティクス送信（L1 制約）

## 機能仕様の詳細

### 1. 責務境界

| 相手 | 方向 | 受け渡すもの |
|---|---|---|
| stretch-catalog | 受け取る | `StretchCatalog.shared`（`rarityWeights` / `items(rarity:)` / `totalCount`） |
| practice-record | 受け取る | 入手済み種目 ID の集合（`OwnershipProviding`）。未実装の間は空集合を返す既定実装で動く |
| stretch-card | 渡す | 抽選確定した `StretchItem` 1 件 |
| safety-notice | 受け取る | 初回注意書きの確認済みフラグ。未確認の間はガチャ画面の手前に注意書きが出る（表示制御は safety-notice 側） |

### 2. 画面仕様（ガチャ画面）

L1 の 3 画面（ガチャ / 図鑑 / 履歴）のうちの 1 つ。縦画面固定。

**状態 A: 待機（idle）**

| 要素 | 内容 |
|---|---|
| カプセル | 画面中央。SwiftUI の `Circle` + 絵文字 1 文字（🎁）。静止 |
| 主ボタン | 画面下部、幅いっぱい・高さ 56pt・角丸。ラベルは「回す」の 2 文字のみ。説明文は置かない |
| その他 | ヘッダ・チュートリアル・確率表記なし。タブは図鑑 / 履歴への遷移のみ |

**状態 B: 演出中（performing）**

- 「回す」ボタンは無効化（二重抽選防止）
- **画面のどこをタップしてもスキップ**して状態 C へ即遷移する。スキップ用のボタンやヒント文は置かない（ラベルを増やさないことが学習容易性 1 位の方針）

**状態 C: 結果表示（revealed）**

- 結果カード領域に stretch-card が描画される（本機能では種目名 + 絵文字 + レア度バッジだけの暫定表示）
- 下部ボタンは「もう 1 回」に変わり、押すと状態 A を経ずに即座に次の抽選（状態 B）へ入る

### 3. 抽選アルゴリズム

```swift
// GachaDrawer.swift  — 副作用なしの純粋関数
struct DrawContext {
    let catalog: StretchCatalog
    let ownedItemIDs: Set<String>      // practice-record 由来（図鑑登録済み）
    let drawnTodayItemIDs: Set<String> // 当日すでに抽選で出た種目
}

struct DrawTuning {
    static let ownedWeight = 1          // 入手済み種目の相対重み
    static let unownedWeight = 2        // 未入手種目の相対重み（= 入手済みの 2 倍）
}

enum GachaDrawer {
    static func draw(_ context: DrawContext,
                     using rng: inout some RandomNumberGenerator) -> StretchItem
}
```

**手順（この順序で適用する）**

1. **レア度抽選**
   - `catalog.rarityWeights`（N 60 / R 27 / SR 10 / UR 3、合計 100）で累積和による重み付き選択を行う。
   - 候補が 0 件のレア度は事前に除外し、残った重みの合計で正規化する（stretch-catalog のバリデータが全 4 レア度に 1 件以上を保証するため通常は発生しない防御的処理）。
   - **この段は未入手・同日重複の影響を一切受けない**。レア度の体感確率をデータ（JSON の重み）だけで決められる状態を保つため。
2. **同日重複回避**
   - 選ばれたレア度の候補 `candidates = catalog.items(rarity:)` から、`drawnTodayItemIDs` に含まれるものを除いて `pool` を作る。
   - `pool` が空（そのレア度を当日すべて引き切った）なら **解除して `pool = candidates` に戻す**。レア度の再抽選はしない。
3. **未入手補正つき選択**
   - `pool` の各要素に重みを与える: `ownedItemIDs` に含まれれば 1、含まれなければ 2。
   - 累積和による重み付き選択で 1 件を確定して返す。

**計算量**: レア度 4 件の走査 + 同レア度内 最大 12 件の走査。全体で最大 26 要素の線形処理 1 回。カタログが 100 件に増えても同じ実装で問題にならない。

**乱数**: 本番は `SystemRandomNumberGenerator`。テストは SplitMix64 ベースの `SeededRandomGenerator`（`RandomNumberGenerator` 準拠、`init(seed: UInt64)`）を注入する。暗号用途ではないため `SystemRandomNumberGenerator` で十分であり、`SecRandomCopyBytes` 等は使わない。

### 4. 確率の具体値（検算）

**全種目未入手・当日 1 回目（補正が効かない初期状態）**

| レア度 | レア度重み | 件数 | 1 件あたりの出現率 | レア度合計 |
|---|---|---|---|---|
| N | 60 | 12 | 5.000% | 60% |
| R | 27 | 8 | 3.375% | 27% |
| SR | 10 | 4 | 2.500% | 10% |
| UR | 3 | 2 | 1.500% | 3% |
| 計 | 100 | 26 | — | **100%** |

検算: 12×5.000 + 8×3.375 + 4×2.500 + 2×1.500 = 60 + 27 + 10 + 3 = **100** ✓
ご褒美カード（UR 2 枚）の合計出現率は **3%**。

**未入手補正が効いた例（N 12 件のうち 4 件を入手済み、当日ドローなし）**

- 同レア度内の重み合計 = 未入手 8×2 + 入手済み 4×1 = 16 + 4 = **20**
- 未入手 1 件あたり = 60% × 2/20 = **6.000%**
- 入手済み 1 件あたり = 60% × 1/20 = **3.000%**
- 検算: 8×6.000 + 4×3.000 = 48 + 12 = **60%** ✓（レア度合計は補正で変わらない）

**同日重複回避が効いた例（当日 SR 4 件のうち 3 件を既に引いている）**

- `pool` = 残り 1 件のみ → SR が選ばれた場合その 1 件が確定（レア度合計 10% は不変）
- 当日 SR 4 件すべてを引き切った後は解除され、`pool` = 4 件全部に戻る（未入手補正は引き続き適用）

### 5. データモデル（永続化）

同日重複回避はアプリ再起動をまたいで機能する必要があるため、当日のドロー状態のみを SwiftData に持つ。実施記録（practice-record）とは別物であり、相互に参照しない。

```swift
// DailyDrawState.swift
@Model
final class DailyDrawState {
    @Attribute(.unique) var dayKey: String   // 例 "2026-08-18"（端末ローカル暦）
    var drawnItemIDs: [String]               // 当日出た種目 ID（重複なし・出現順）
    var updatedAt: Date

    init(dayKey: String, drawnItemIDs: [String] = [], updatedAt: Date) { ... }
}
```

- **テーブルには常に 0 行または 1 行しか置かない**。日付が変わったら行を追加せず、既存行の `dayKey` を上書きして `drawnItemIDs` を空にする。履歴として貯めない（履歴は practice-record の責務）。
- `dayKey` は `Calendar.current.dateComponents([.year, .month, .day], from:)` から組み立てる（`DateFormatter` は使わない）。日付境界は端末ローカルの午前 0 時。
- 現在時刻は `DateProviding`（`() -> Date`）として注入し、テストで日付をまたげるようにする。

```swift
// DailyDrawStore.swift — SwiftData 読み書きの薄いラッパ
@MainActor
final class DailyDrawStore {
    init(context: ModelContext, now: @escaping () -> Date)
    func loadDrawnTodayIDs(validAgainst catalog: StretchCatalog) -> Set<String>
    func recordInMemory(itemID: String)   // メモリ上の状態だけ更新（I/O なし）
    func flush()                          // SwiftData へ save
}
```

### 6. 未入手判定の依存ポート

practice-record は未実装のため、本機能側でポートを定義する。

```swift
// OwnershipProviding.swift
protocol OwnershipProviding {
    /// 図鑑に登録済み（＝1 回以上実施完了した）種目 ID
    func ownedItemIDs() -> Set<String>
}

/// practice-record 実装までの既定実装。常に空集合を返す
struct EmptyOwnershipProvider: OwnershipProviding {
    func ownedItemIDs() -> Set<String> { [] }
}
```

空集合が返る間は全種目が「未入手（重み 2）」となり、同レア度内は均等抽選に **正しく縮退する**。practice-record 実装時に `GachaViewModel` の初期化引数へ実装を差し替えるだけで補正が有効になる（gacha-draw 側のロジック変更は不要）。

### 7. 演出仕様

抽選は**演出の前に確定させる**。レア度によって演出の長さと表現が変わるため、演出開始時点で結果を知っている必要がある。

**N / R（合計 1.200 秒）**

| 区間 | 内容 |
|---|---|
| 0.00 – 0.35s | カプセルが縮んで小刻みに揺れる（`scaleEffect` + `rotationEffect`） |
| 0.35 – 0.85s | 回転しながら拡大 |
| 0.85 – 1.05s | 開封フラッシュ（`opacity`） |
| 1.05 – 1.20s | 結果カードへクロスフェード |

検算: 0.35 + 0.50 + 0.20 + 0.15 = **1.20 秒** ✓

**SR / UR（合計 1.800 秒）**

| 区間 | 内容 |
|---|---|
| 0.00 – 0.45s | カプセルが揺れる |
| 0.45 – 0.90s | レア度カラーへの色味変化（`foregroundStyle` の補間） |
| 0.90s 時点 | `UIImpactFeedbackGenerator(style: .medium)` を **1 回だけ** 発火 |
| 0.90 – 1.50s | 回転しながら拡大 |
| 1.50 – 1.70s | 開封フラッシュ |
| 1.70 – 1.80s | 結果カードへクロスフェード |

検算: 0.45 + 0.45 + 0.60 + 0.20 + 0.10 = **1.80 秒** ✓

**共通ルール**

- ハプティクスは **SR / UR のみ**。N / R では一切鳴らさない（q2 回答）。
- スキップで 0.90s 地点に到達しなかった場合、ハプティクスは発火しない。
- 演出中の画面タップでいつでも即座に状態 C へ遷移する（アニメーションタスクをキャンセル）。
- 60fps 維持のため、アニメーション対象は `scaleEffect` / `rotationEffect` / `opacity` / 色補間に限定する。`blur` / `shadow` / `mask` の動的変化、`TimelineView`、`CADisplayLink` は使わない。画像アセットを持たないためデコードも発生しない。
- `accessibilityReduceMotion` が true の場合、レア度によらず **0.30 秒のクロスフェードのみ**に短縮する（SR / UR のハプティクスは 0.15s 時点で発火）。

### 8. 状態機械

```swift
enum GachaPhase: Equatable {
    case idle
    case performing(GachaOutcome)
    case revealed(StretchItem)
}

struct GachaOutcome: Equatable {
    let item: StretchItem
    let isHighlighted: Bool   // rarity == .sr || rarity == .ur
    let duration: Double      // 1.2 / 1.8 / 0.3(Reduce Motion)
}

@Observable
@MainActor
final class GachaViewModel {
    private(set) var phase: GachaPhase = .idle
    func spin()      // idle / revealed のときのみ有効。performing 中は無視
    func skip()      // performing のときのみ有効。即 revealed へ
    func onRevealed()// 演出完走・スキップ双方の合流点。ここで flush()
}
```

`spin()` / `skip()` は同期メソッドで、時間経過はビュー側の `.task { try? await Task.sleep(for: .seconds(outcome.duration)) }` が駆動する。**テストは実時間を待たずにメソッド直接呼び出しで状態遷移を検証する**（壁時計時間をアサートしない）。

### 9. 処理フロー

```
[ガチャ画面 onAppear]
   ├─ StretchCatalog.shared に触れて読み込みを済ませる（ウォームアップ / 150ms 予算）
   └─ DailyDrawStore.loadDrawnTodayIDs()  ← SwiftData fetch 1 本
         ├─ 行なし          → 空集合
         ├─ dayKey ≠ 今日   → 行を上書きリセットして空集合
         └─ dayKey = 今日   → drawnItemIDs のうち catalog に存在する id だけを採用
   ▼
[「回す」タップ]
   ├─ phase == .performing なら無視（二重抽選防止）
   ├─ ownership.ownedItemIDs() を取得
   ├─ GachaDrawer.draw(context:using:)          ← 同期・O(26)・目標 1ms 未満
   ├─ store.recordInMemory(itemID:)             ← メモリのみ。ここでは I/O しない
   ├─ レア度から duration / isHighlighted を決定
   └─ phase = .performing(outcome)
   ▼
[演出 1.2s / 1.8s]  ← 画面タップでいつでもスキップ
   ▼
[phase = .revealed(item)]
   ├─ store.flush()                             ← SwiftData save 1 回（演出終了後）
   └─ 結果カード領域へ item を引き渡す（stretch-card）
   ▼
[「もう 1 回」] → 「回す」タップと同じ経路へ
```

**演出中にメインスレッドの I/O を一切走らせない**ことを設計上の固定点とする（60fps 維持）。演出中にアプリが強制終了した場合、その 1 回分の当日ドロー記録が失われるが、影響は重複回避が 1 件分緩むだけであり、回復処理は設けない（L1 妥協特性「運用性」）。

## 非機能要件

| 項目 | 値 | 根拠・備考 |
|---|---|---|
| コールドスタート → 結果カード表示 | **3.0 秒以内**（ヒトの反応時間を除く機械時間） | L1 最優先 2 位。内訳は下表 |
| 　T1: プロセス起動 → ガチャ画面が操作可能 | 1.00 秒以内（うちカタログ読み込み 150ms、当日状態 fetch 50ms） | |
| 　T2: タップ → 結果カード表示 | 最大 1.81 秒（抽選 0.01 + 演出 1.80） | SR/UR の最長ケース |
| 　合計（最悪ケース） | 1.00 + 1.81 = **2.81 秒**（3.0 秒に対し 190ms の余裕） | |
| 演出時間 | N/R **1.200 秒**、SR/UR **1.800 秒**、Reduce Motion **0.300 秒** | q2 回答 |
| 演出スキップ後の結果表示 | タップと同一フレーム内で状態遷移（待ち時間 0） | |
| フレームレート | 演出中 60fps 維持 | 測定は Instruments で目視。自動テストではアサートしない（運用性は妥協特性） |
| 抽選 1 回の所要時間 | 実機設計目標 1ms 未満 | O(26) の線形処理 1 回 |
| 　同上・テストのアサート閾値 | **100,000 回の抽選が 2 秒以内**（1 回あたり 20µs 相当の上限） | シミュレータ / CI の実行環境差を吸収する余裕を持った上限 |
| レア度分布の許容誤差 | シード固定 100,000 回で各レア度が期待値の **相対 ±20% 以内** | UR（期待 3,000 件）で標準偏差の約 11 倍。統計的に安定して通る幅 |
| SwiftData クエリ本数 | 画面初期化時 **fetch 1 本**。ガチャ 1 回あたり **fetch 0 本 / save 1 回** | 演出中に I/O を発生させない |
| `DailyDrawState` の行数 | 常に **1 行以下**（日をまたいでも増えない） | 履歴は持たない設計 |
| ディスク書き込み量 | 1 回あたり 1KB 未満（種目 ID 最大 26 件の文字列配列） | |
| ネットワークリクエスト数 | **0 件** | L1 制約: サーバー・外部 API 禁止 |
| メモリ増分 | 1MB 未満（カタログ常駐分を除く） | 保持するのは ID 集合 2 つと状態 1 つ |
| 1 日の抽選回数制限 | **なし**（無制限） | L1「1 日に何回でも回せる」 |
| 追加アセット数 | **0 個**（画像・音源・フォントを追加しない） | シェイプ + 絵文字のみで構成 |
| 種目追加時に本機能で変更するファイル数 | **0 ファイル** | 件数・重みはすべてカタログ側。テストで実証する |
| 想定同時ユーザー数 | 1（自分のみ） | L1 妥協特性: スケーラビリティ |
| 実装完了時期 | MVP（2 週間）内 ※**L1 の仮置き値に基づく** | L1「期限・マイルストーン」が【仮置き】 |

## 非機能優先順位との対応

### 1 位: 学習容易性（説明書なしで初回起動 60 秒以内に最初のガチャ → 実施開始）

- **画面上の操作対象を「回す」ボタン 1 つに絞る**。設定・確率表示・履歴リンク・チュートリアル導線をガチャ画面に置かない。覚えることを増やさない。
- **60 秒の内訳を設計上確保する**: 注意書きの確認 約 10 秒 + ガチャ画面の認識 約 5 秒 + 演出 最大 1.8 秒 + 結果カードの読了 約 20 秒 ≒ **37 秒**で実施開始に到達する。演出をこれ以上長くしないことが要件（q2 回答の「これ以上長くしない」に一致）。
- **スキップを学習不要にする**: スキップ操作を「画面のどこでもタップ」にし、専用ボタンやヒント文を置かない。偶然触れても意図どおりに動く。
- **確率を説明しない**: 課金がないため提供確率の開示義務がなく、確率表・排出率画面を持たない。レア度は色とバッジだけで伝える。
- **失敗状態を作らない**: エラーダイアログ・リトライ導線を持たない（カタログ破損は stretch-catalog 側で `fatalError`、それ以外の失敗経路が存在しない）。

### 2 位: パフォーマンス（コールドスタート → 結果 3 秒以内、演出 60fps）

- 上表の時間予算（T1 1.00s + T2 最大 1.81s = 2.81s）を設計値として固定し、190ms を余裕として残す。
- **演出中に I/O を 1 回も走らせない**: 当日ドロー状態の更新はメモリ上で行い、SwiftData の `save()` は演出完了後に 1 回だけ実行する。ownership の取得も演出開始前に済ませる。
- **アニメーションを GPU で完結するプロパティに限定**: `scaleEffect` / `rotationEffect` / `opacity` / 色補間のみ。`blur` / `shadow` の動的変化、画像デコード、レイアウト再計算を伴うアニメーションを使わない。
- **抽選を同期処理にする**: `async` にせず、タップハンドラ内で完結させる。待ち合わせ・スレッド跨ぎを作らない（最大 26 要素の線形処理でありその必要がない）。
- カタログ読み込みは画面の `onAppear` でウォームアップし、タップ後の経路から I/O を排除する。

### 3 位: 保守性（週末開発でも壊さず拡張できる）

- **抽選ロジックを純粋関数に隔離する**: `GachaDrawer.draw(_:using:)` は状態を持たず、カタログ・入手済み集合・当日集合・乱数生成器をすべて引数で受ける。SwiftUI / SwiftData / 時刻に依存しないため、確率の検証がユニットテストだけで完結する。
- **調整値を 1 箇所に集約する**: 未入手倍率は `DrawTuning`、演出秒数は `GachaAnimation` にまとめ、コード中に数値を散らさない。レア度の重みは JSON 側（stretch-catalog）に残したまま触らない。
- **種目追加でコードを触らせない**: 件数・レア度別内訳をコードに焼き込まない。種目を 1 件追加してもガチャ側は 0 ファイル変更で動くことをテストで実証する。
- **テストは範囲・上限でアサートする**: 分布は相対 ±20%、抽選速度は 100,000 回 2 秒以内という余裕を持った上限で書く。「特定シードで特定の種目が出る」ような実装順序に依存する厳密アサートは書かない（実装を少し変えるたびにテストが落ちる脆い制約になるため）。
- 依存の向きを一方向に保つ: gacha-draw → stretch-catalog / `OwnershipProviding` のみ。practice-record・stretch-card から gacha-draw を参照させない。

### 妥協特性で簡略化すること

| 妥協特性 | 本機能で作らないもの |
|---|---|
| スケーラビリティ | 抽選は毎回全候補を線形走査する素朴な実装で通す。累積和テーブルのキャッシュ、事前計算した確率テーブル、インデックス最適化をしない。当日ドロー状態は 1 行固定でページングもクエリ最適化も不要 |
| 互換性・相互運用性 | `DailyDrawState` はこのアプリ専用スキーマ。エクスポート・インポート・他形式変換・マイグレーション機構を持たない。日付は端末ローカル暦のみ扱い、タイムゾーン変更時の再計算・UTC 併記をしない |
| 運用性 | 抽選結果のログ出力、fps 計測基盤、アナリティクス、クラッシュレポート、確率検証用のデバッグ画面を持たない。演出中クラッシュ時の記録復旧も行わない。不具合は自分が使って気づいたら直す |

## セキュリティ

本機能は完全ローカル・単一ユーザーで、ネットワークもテキスト入力も扱わない。攻撃面は「永続化した当日ドロー状態の読み戻し」に限定される。

### 認証・認可

- **不要（実装しない）**。アカウント・ログインを持たず単一端末・単一ユーザーのローカル完結（L1 のスコープ外事項）。ガチャ画面に権限による出し分けは存在しない。
- カタログを書き換える経路を作らない。本機能はカタログを読み取り専用で参照するのみで、`StretchItem` を保持・改変しない。

### 入力検証

- ユーザー入力はボタンタップと画面タップのみ。テキスト入力・数値入力・URL 受け取り（URL スキーム / ユニバーサルリンク）を一切持たない。
- **永続化データを「信頼しない入力」として扱う**: `DailyDrawState.drawnItemIDs` の読み戻し時に、カタログに存在しない ID を破棄してから使う。破損・古い ID が混ざっても重複回避の精度が落ちるだけでクラッシュしない。
- `dayKey` が今日と一致しない場合は無条件でリセットする。不正な文字列が入っていてもリセット経路に落ちる。
- 状態機械側で二重抽選を防ぐ: `phase == .performing` の間は `spin()` を無視し、連打で複数の抽選・複数の save が走らないようにする。

### データ保護

- 保存するのは **種目 ID の配列と日付文字列のみ**。個人情報・端末識別子・位置情報・利用統計を一切保存しない。App Privacy「データ収集なし」申告（appstore-release-prep）と矛盾しない状態を維持する。
- SwiftData のストアは iOS の Data Protection（既定の `NSFileProtectionCompleteUntilFirstUserAuthentication`）下に置かれ、追加の暗号化は行わない（保存内容に秘匿性がないため）。
- **ネットワークを使わない**: `URLSession` / `Network` / `CFNetwork` を import しない。App Transport Security 設定を緩めない。
- ログ出力を残さない（`print` / `os_log` を使わない）。抽選結果を外部へ送らない。

### 乱数の取り扱い

- 抽選は**セキュリティ用途ではない**（課金・景品・順位付けに一切影響しない）ため、本番では `SystemRandomNumberGenerator` を用い、暗号学的乱数 API（`SecRandomCopyBytes`）や検証可能乱数の仕組みは導入しない。この判断を実装コメントに明記する。
- テスト用の `SeededRandomGenerator` は **テストターゲットからのみ使う**（アプリターゲットに固定シードの経路を残さない）。

### 依存関係

- 外部ライブラリ 0。`SwiftUI` / `SwiftData` / `Foundation` / `UIKit`（ハプティクスの `UIImpactFeedbackGenerator` のみ）で完結する（L1 制約: 外部ライブラリ原則ゼロ）。

## 実装方針

### 使用技術

- Swift 5.9+ / SwiftUI（iOS 17 以上）、`@Observable` マクロによる状態管理
- SwiftData（当日ドロー状態 1 モデルのみ）
- ハプティクスは `UIKit` の `UIImpactFeedbackGenerator`（`style: .medium`）
- テストは XCTest（標準）

### 既存実装との整合

- **stretch-catalog は仕様確定済み（status: issued_local）** であり、本機能はその読み取り専用 API（`StretchCatalog.shared` / `rarityWeights` / `items(rarity:)`）にそのまま乗る。カタログ側のコード・JSON は変更しない。
- **practice-record は未着手**のため、入手済み ID の供給を `OwnershipProviding` プロトコルとして切り出し、既定は `EmptyOwnershipProvider`（空集合）とする。本機能単体でビルド・テスト・実機動作が成立する状態を成果物とする。practice-record 実装時は `GachaViewModel` の初期化引数を差し替えるだけでよい。
- **stretch-card は未着手**のため、結果表示は「種目名 + 絵文字 + レア度バッジ」だけの暫定ビュー `PlaceholderResultView` とする。差し替え位置をコメントで明示し、stretch-card 側がここを置き換える。暫定ビューでレイアウトを作り込まない。
- **safety-notice は未着手**。ガチャ画面は初回注意書きの有無を前提にしない実装とし、safety-notice がルート側で被せる形になる。本機能から注意書きの表示制御を行わない。
- Xcode プロジェクト（`stretch-gacha/`）と `StretchGachaApp.swift` は stretch-catalog の実装時に作成済みの想定。存在しない場合は同機能の実装方針に従った最小構成を作成する。

### 変更対象ファイル

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

### 実装手順

1. **`SeededRandomGenerator.swift`**: SplitMix64 を `RandomNumberGenerator` 準拠で実装。`init(seed: UInt64)`。まずこれを作ることで以降のロジックがすべてテスト可能になる。
2. **`GachaDrawer.swift`**: `DrawContext` / `DrawTuning` と `draw(_:using:)` を実装。§3 の 3 手順を上から順に、それぞれ独立した private ヘルパ（`selectRarity` / `applyDailyDedup` / `selectItemWithOwnershipBoost`）に分けて実装し、各ヘルパを個別にテストできるようにする。
3. **`OwnershipProviding.swift`**: プロトコルと `EmptyOwnershipProvider` を実装。
4. **`DailyDrawState.swift` / `DailyDrawStore.swift`**: モデル定義と、fetch → 日付判定 → リセット / 採用の分岐、`recordInMemory` / `flush` を実装。カタログに無い ID の破棄をここで行う。`StretchGachaApp.swift` の `.modelContainer(for: DailyDrawState.self)` を追加。
5. **`GachaAnimation.swift`**: 1.20 / 1.80 / 0.30 秒と各区間の比率を定数化。マジックナンバーをビュー側に書かない。
6. **`GachaViewModel.swift`**: `GachaPhase` / `GachaOutcome` と `spin()` / `skip()` / `onRevealed()` を実装。依存（catalog / ownership / store / rng ファクトリ）はイニシャライザ注入。
7. **`GachaView.swift`**: 待機・演出・結果の 3 状態を描画。演出は `.task(id:)` 内の `Task.sleep` で進め、`skip()` でキャンセル。`contentShape(Rectangle())` + `onTapGesture` を画面全体に敷いてスキップを受ける。`accessibilityReduceMotion` を参照して短縮演出に切り替える。SR/UR のハプティクスを規定タイミングで 1 回発火。
8. **`PlaceholderResultView.swift`**: 種目名・絵文字・レア度バッジのみ。「stretch-card 実装時にこのビューを置き換える」旨をファイル冒頭コメントに明記。
9. **`GachaDrawTests.swift`**: 「受け入れ条件」の各項目に 1:1 対応するテストを実装。分布テストは in-memory の `ModelContainer`（`isStoredInMemoryOnly: true`）とシード固定 RNG で行う。
10. **仕上げ確認**: `Gacha/` 配下が `URLSession` / `Network` を import していないこと、ビルド警告 0 件であること、実機で演出が引っかからないことを Instruments で確認する。

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

## 仮置き依存

| # | L1 の仮置き値 | 本書での依存箇所 | 仮置きが覆った場合の影響 |
|---|---|---|---|
| 1 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 演出を画像・音源アセットゼロ（SwiftUI のシェイプ + 絵文字 1 文字）に限定し、レア度差分を「色味変化 + ハプティクス」だけで表現すると決めた判断。および演出パターンをレア度 2 系統（N/R / SR/UR）に留めた判断 | 期間が延びる場合、演出の作り込み（レア度 4 段階それぞれの専用演出、パーティクル表現）を検討する余地がある。`GachaAnimation` と `GachaView` の変更のみで対応でき、抽選ロジック・永続化には波及しない |
| 2 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 非機能要件の「実装完了時期: MVP（2 週間）内」 | MVP 期間が変わっても本機能の設計値（時間予算・確率・クエリ本数）は変わらない |
| 3 | 配布・審査「当面は Xcode 直接インストール。4 週間後に App Store 公開を判断」 | 提供確率の開示 UI（排出率表示画面）を持たないと決めた判断。課金がないため開示義務がないという前提に立っている | 公開判断が前倒しになっても、無償かつ App 内課金なしである限り開示 UI は不要。将来課金を導入する場合のみ再検討が必要だが、L1 で収益化は将来も含めスコープ外と確定しているため、実質的に覆らない |

## 実装記録

---

修正箇所は 2 つだけです。

- **受け入れ条件**: 「コールドスタート → ガチャ画面操作可能 1.5 秒以内」の 1 項目を、エンドツーエンド 3.0 秒以内の上位条件 + T1 1.19 秒以下の従属条件に置き換え（1.19 + 1.81 = 3.00 秒で予算内。設計値 T1 1.00 秒・余裕 190ms とも矛盾しない）
- **変更履歴**: 1 行追記

非機能要件表・§7 演出秒数・確率の検算はいずれも指摘対象外かつ新しい上限と整合するため、変更していません。
