# 機能仕様: practice-record

## 変更履歴

- 2026-08-18 初版作成

## 概要と提供価値

stretch-timer がカウントダウンを完走したときに実施を 1 件記録し、その記録から **図鑑登録（入手済み種目）・実施履歴・連続日数** の 3 つを導出する機能。記録は SwiftData でローカルにのみ保存し、実施記録以外の情報は一切持たない。

本機能は 3 つの役割を同時に果たす。

1. **記録の唯一の書き手**: stretch-timer が定義済みの `PracticeRecording` ポートを実装し、完了イベントを 1 行の `PracticeRecord` として永続化する。
2. **図鑑登録の供給元**: gacha-draw が定義済みの `OwnershipProviding` ポートを実装し、「1 回以上実施完了した種目 ID の集合」を返す。これにより gacha-draw の未入手 2 倍補正が実運用で有効になり、stretch-collection の入手済み判定もここに乗る。
3. **履歴画面の提供**: L1 の 3 画面（ガチャ / 図鑑 / 履歴）のうち「履歴」を実装し、連続日数と時系列の実施履歴を表示する。あわせてタブ構成（`RootTabView`）を導入する。

提供価値は 2 つ。

1. **やった事実が積み上がって見える**: 実施のたびに履歴が伸び、連続日数が増える。義務感ではなく「積み上がっているものを切らしたくない」という手応えが継続の動機になる（L1 の成功指標「4 週間、週 4 日以上」を直接支える）。
2. **収集欲を実際に駆動する**: 図鑑登録が発生することで、gacha-draw の未入手補正と stretch-collection のシルエット解除が動き出す。ガチャ → 実施 → 図鑑が 1 本の輪としてつながる最後のピース。

記録処理はユーザー操作を一切要求しない（完了したら自動で記録される）。連続日数・履歴の整形はすべて `Calendar` にも SwiftUI にも依存しない純粋関数に隔離し、境界値をユニットテストで検証できる形にする。

## スコープ（やること / やらないこと）

### やること

- 実施記録モデル `PracticeRecord`（SwiftData `@Model`）の定義と永続化
- 日付キー生成 `DayKey`（端末ローカル暦の `"yyyy-MM-dd"`。gacha-draw の `DailyDrawState.dayKey` と同じ表現）
- 日付キー → 通し日番号の純粋変換 `DayNumber`（`Calendar` 非依存。曜日算出・表示ラベル生成を含む）
- 連続日数の算出 `StreakCalculator`（**猶予 1 日**の定義。q1 回答）
- メモリ索引 `PracticeIndex`（入手済み ID 集合・実施日集合・履歴エントリ）とその構築純粋関数
- 履歴のセクション整形 `HistorySectionBuilder`（日付降順・時刻降順）
- 記録ストア `PracticeStore`（SwiftData 読み書き + 索引保持 + 2 ポートの実装）
- `PracticeRecording` / `OwnershipProviding` への準拠アダプタ（`Timer/` `Gacha/` のプロトコル宣言を変更しないための橋渡し）
- 履歴画面 `HistoryView`（連続日数 + 時系列リスト + 空状態）
- タブ構成 `RootTabView`（ガチャ / 履歴の 2 タブ。図鑑タブの追加は stretch-collection の責務）
- `StretchGachaApp` の変更（`ModelContainer` へ `PracticeRecord` を登録、ルートを `RootTabView` へ、`PracticeStore` を Environment へ注入）
- `GachaView` / `StretchTimerView` から `PracticeStore` を受け渡す最小変更
- 上記すべてのユニットテスト（連続日数の境界値・日付変換・索引・整形・副作用回数・性能）

### やらないこと

- **図鑑画面そのもの・シルエット表現・コンプ率**（stretch-collection / collection-progress の責務）。本機能は入手済み ID 集合を返すところまで
- **タイマーの実行・完了判定**（stretch-timer の責務）。本機能は完了イベントを受け取るだけで、タイマーの状態機械に触れない
- **抽選ロジック・演出**（gacha-draw の責務）。`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` に変更を加えない
- **新規入手（図鑑初登録）の演出**: `PracticeRecording.recordCompletion` の戻り値が `Void` で確定しており、返すには stretch-timer 側のポート定義と完了画面（「✅ 完了！」）の変更が必要になるため MVP 不採用。将来の拡張候補としてコメントに残すのみ
- **二重記録の防止ロジック**: stretch-timer の再入ガード（`finished` 到達時に 1 回だけ記録）が担保済み。検査点を 2 箇所に分散させないため本機能で再実装しない
- **履歴の削除・編集・手動追加 UI**、実施の取り消し
- **履歴の検索・フィルタ・並べ替え・期間切り替え（週 / 月表示）・カレンダー表示・グラフ**
- **最長連続記録・通算実施回数・部位別集計などの統計表示**（画面の情報量を増やさない。数値による動機付けは collection-progress の判断に委ねる）
- **履歴行のタップによる詳細遷移**（種目詳細は図鑑の責務）
- **記録のエクスポート / インポート / iCloud 同期 / バックアップ / 他端末移行**（L1 妥協特性: 互換性・相互運用性）
- **リマインダー通知・週次サマリ通知**（通知権限を一切要求しない方針を stretch-timer から継承）
- 古い記録の自動削除・アーカイブ・保持期間の設定
- サーバー・外部 API・アナリティクス送信（L1 制約）

## 機能仕様の詳細

### 1. 責務境界

| 相手 | 方向 | 受け渡すもの |
|---|---|---|
| stretch-timer | 受け取る | 完了イベント `recordCompletion(itemID:completedAt:)` を 1 回。中断時は呼ばれない |
| gacha-draw | 渡す | `OwnershipProviding.ownedItemIDs() -> Set<String>`（**メモリ索引から返す。fetch 0 本**） |
| stretch-collection | 渡す | 同じ `ownedItemIDs()` / `isOwned(_:)`。未入手の表現方法は図鑑側の責務 |
| stretch-catalog | 受け取る | `StretchCatalog.shared.item(id:)`（履歴行の種目名・絵文字・レア度の解決）、`totalCount` |
| stretch-card | 参照しない | 履歴行は 1 行 44pt の簡易表示であり、カードを使わない |
| safety-notice | 受け取る | 相互作用なし（ルートに被さる形は safety-notice 側の責務） |

依存の向きは **practice-record → stretch-catalog / 各ポートのプロトコル宣言** の一方向。gacha-draw・stretch-timer から practice-record の型を参照させない（両者はプロトコル越しにしか本機能を知らない）。

### 2. データモデル（永続化）

```swift
// PracticeRecord.swift
@Model
final class PracticeRecord {
    @Attribute(.unique) var id: UUID     // 行の一意キー。表示には使わない
    var itemID: String                   // StretchItem.id（例 "neck-02"）
    var completedAt: Date                // 完了時刻（壁時計。表示と並べ替えに使う）
    var dayKey: String                   // 記録時に確定した端末ローカル暦の日付 "2026-08-18"

    init(id: UUID = UUID(), itemID: String, completedAt: Date, dayKey: String) { ... }
}
```

- **1 実施完了 = 1 行**。更新・削除は行わない（追記専用）。
- `dayKey` を **記録時に確定して保存する**。以後タイムゾーンが変わっても過去の行を再計算しない（q2 回答の「過去記録の再計算はしない」に対応）。判定に使うのはあくまで保存済みの `dayKey` であり、`completedAt` から日付を導出し直さない。
- SwiftData のモデルは本機能で **1 つだけ**追加する。gacha-draw の `DailyDrawState` とは相互参照しない（当日ドロー状態は抽選の重複回避用であり、実施記録とは別物）。

### 3. 日付の扱い（q2 回答: 端末ローカル暦の午前 0 時）

#### 3.1 日付キーの生成

```swift
// DayKey.swift
enum DayKey {
    /// 端末ローカル暦の「その日」を表す文字列 "yyyy-MM-dd"
    static func make(from date: Date, calendar: Calendar = .current) -> String

    /// 形式検証。^\d{4}-\d{2}-\d{2}$ かつ 月 1...12・日 1...31
    static func isValid(_ key: String) -> Bool
}
```

- 生成は `calendar.dateComponents([.year, .month, .day], from: date)` から `String(format: "%04d-%02d-%02d", ...)` で組み立てる。**`DateFormatter` を使わない**（ロケール・カレンダー設定による出力揺れを避けるため。gacha-draw の `DailyDrawState.dayKey` と同じ手法）。
- 日付境界は端末ローカルの午前 0 時。午前 4 時等へずらす特別処理は作らない（q2 回答）。就寝前の実施が 0 時をまたぐケースは §3.3 の猶予が吸収する。

#### 3.2 通し日番号への変換（`Calendar` 非依存）

連続日数の判定を `Calendar` の日付加減算で行うと、ループ内で暦計算が走り、タイムゾーン変更時の挙動も読みにくくなる。**日付キーを 1970-01-01 を 0 とする整数（通し日番号）へ 1 回だけ変換し、以後は整数演算だけで扱う**。

```swift
// DayNumber.swift
enum DayNumber {
    /// "2026-08-18" -> 1970-01-01 を 0 とする通し日番号。形式不正なら nil
    static func from(dayKey: String) -> Int?

    /// 通し日番号 -> 曜日記号（0=日 … 6=土 の索引で "日月火水木金土" を引く）
    static func weekdaySymbol(_ n: Int) -> String

    /// 履歴のセクション見出し文字列
    static func sectionTitle(_ n: Int, today: Int) -> String
}
```

- 変換は標準的な civil→days 変換（うるう年・400 年周期を含む純粋な整数演算）で実装する。`Calendar` / `DateComponents` をこの関数の内側で使わない。
- 曜日は `((n % 7) + 7 + 4) % 7`（1970-01-01 が木曜であることに由来する +4 の補正）で 0=日曜として求める。
- `sectionTitle` は `n == today` → 「今日」、`n == today - 1` → 「昨日」、それ以外 → 「8月18日(火)」の 3 分岐のみ。

**検証可能な既知値**（テストで厳密にアサートする。経路差で揺れない）

| 入力 | 期待 |
|---|---|
| `from("2026-08-19") - from("2026-08-18")` | 1 |
| `from("2025-12-31") + 1 == from("2026-01-01")` | true（年またぎ） |
| `from("2026-03-01") - from("2026-02-28")` | 1（2026 は平年） |
| `from("2028-02-29") - from("2028-02-28")` | 1（2028 はうるう年） |
| `from("2028-03-01") - from("2028-02-29")` | 1 |
| `weekdaySymbol(from("2026-08-18")!)` | "火" |
| `weekdaySymbol(from("2026-08-19")!)` | "水" |
| `from("2026-13-01")` / `from("abc")` / `from("2026-08-1")` | nil |

#### 3.3 連続日数の定義（q1 回答: 猶予あり・抜けは連続 1 日まで）

```swift
// StreakCalculator.swift
enum StreakCalculator {
    /// practiceDays: 実施が 1 件以上あった日の通し日番号の集合
    /// today: 判定時点（端末ローカル暦の今日）の通し日番号
    static func streak(practiceDays: Set<Int>, today: Int) -> Int
}
```

**規則（この順で適用する）**

1. `today` 以前の実施日のうち最大のものを `last` とする。存在しなければ **0**。（`today` より後の日付を持つ記録は無視する）
2. `today - last - 1 >= 2` なら **0**。`last` と `today` の間に挟まる日はすべて抜けであり、それが 2 日以上連続した時点でリセットする。**当日（`today`）はまだ終わっていないため抜けとして数えない**。
3. `last` から遡る。カーソルの 1 日前に実施があればそこへ移り、無ければ 2 日前を見る（**抜け 1 日を許容**）。2 日前にも無ければ打ち切る。
4. 移動した回数 + 1 を返す。**数えるのは「実施した日」の数だけ**で、猶予で許容した抜け日はカウントに加えない。

```swift
var count = 1
var cursor = last
while true {
    if practiceDays.contains(cursor - 1) { cursor -= 1; count += 1 }
    else if practiceDays.contains(cursor - 2) { cursor -= 2; count += 1 }   // 抜け 1 日を許容
    else { break }
}
return count
```

**境界値の一覧（`T` = today。テストにそのまま落とす）**

| # | 実施日 | 期待 | 説明 |
|---|---|---|---|
| 1 | なし | 0 | 記録 0 件 |
| 2 | T | 1 | 今日だけ |
| 3 | T, T−1 | 2 | 連続 2 日 |
| 4 | T−1 | 1 | 今日はまだ未実施でも切れない |
| 5 | T−2 | 1 | 抜けは昨日 1 日のみ。今日は抜けに数えない |
| 6 | T−3 | 0 | T−1・T−2 の 2 日連続抜けでリセット |
| 7 | T, T−2, T−3 | 3 | 昨日 1 日の抜けを越えてつながる |
| 8 | T, T−1, T−3, T−4 | 4 | 途中 1 日の抜けを越えてつながる |
| 9 | T, T−1, T−4 | 2 | T−2・T−3 の 2 日連続抜けで打ち切り |
| 10 | T−3, T−1, T（= 月・水・木、火が抜け） | 3 | **q1 回答の例と一致** |
| 11 | T に 3 件 | 1 | 同一日の複数実施は 1 日として数える |
| 12 | T, T+1 | 1 | 未来日の記録は無視 |

- 計算量は O(連続日数)。1 ステップは `Set<Int>` の照会 1〜2 回のみ。
- `Calendar`・`Date`・SwiftUI・SwiftData・乱数のいずれにも依存しない。

#### 3.4 日付が変わったときの再計算

索引は起動時と記録時にしか更新されないため、アプリを開いたまま日をまたぐと連続日数の表示が古くなる。履歴画面の `onAppear` と `scenePhase == .active` への復帰時に `today` を取り直し、**変化していれば連続日数とセクション見出しのみ再計算する**（fetch 0 本・O(実施日数)）。記録本体は触らない。

### 4. メモリ索引と記録ストア

#### 4.1 索引（値型・純粋構築）

gacha-draw の受け入れ条件「ガチャ 1 回あたりの fetch が 0 本」を維持するため、**入手済み判定を毎回 SwiftData に問い合わせない**。起動時に 1 度だけ全件を読み、値型のスナップショットとしてメモリに保持する。

```swift
// PracticeEntry.swift
struct PracticeEntry: Equatable {
    let itemID: String
    let completedAt: Date
    let dayNumber: Int
}

// PracticeIndex.swift
struct PracticeIndex: Equatable {
    let entries: [PracticeEntry]        // completedAt 降順
    let ownedItemIDs: Set<String>
    let practiceDays: Set<Int>

    /// 純粋関数。SwiftData の型を受け取らず、値型の配列から組み立てる
    static func build(from rows: [(itemID: String, completedAt: Date, dayKey: String)],
                      knownItemIDs: Set<String>) -> PracticeIndex

    static let empty: PracticeIndex
}
```

**構築時の防御的処理**（永続化データを「信頼しない入力」として扱う）

| 条件 | 扱い |
|---|---|
| `dayKey` が `DayNumber.from` で変換できない | その行を索引から除外（保存済みの行は削除しない） |
| `itemID` が `knownItemIDs`（カタログの全 ID）に無い | その行を索引から除外。`ownedItemIDs` にも含めない |
| 同一 `itemID` が複数行 | `ownedItemIDs` では 1 要素に畳まれる |
| 同一 `dayNumber` が複数行 | `practiceDays` では 1 要素に畳まれる |

索引が SwiftData の `@Model` インスタンスを保持しないことで、`ModelContext` の寿命に引きずられず、`PracticeIndex` / `StreakCalculator` / `HistorySectionBuilder` のテストが永続化層なしで完結する。

#### 4.2 ストア

```swift
// PracticeStore.swift
@Observable
@MainActor
final class PracticeStore {

    private(set) var streakDays: Int = 0
    private(set) var sections: [HistorySection] = []

    init(context: ModelContext,
         catalog: StretchCatalog = .shared,
         now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current)      // init 内で loadIndex() を 1 回呼ぶ

    func loadIndex()                          // SwiftData fetch 1 本。起動時のみ
    func record(itemID: String, completedAt: Date)   // insert 1 + save 1、索引を更新
    func ownedItemIDs() -> Set<String>        // 索引を返す。fetch 0 本
    func isOwned(_ itemID: String) -> Bool    // O(1)
    func refreshForCurrentDay()               // 日付が変わっていれば streak / 見出しを再計算
}
```

- `loadIndex()` は `FetchDescriptor<PracticeRecord>`（`completedAt` 降順）で **1 本**だけ実行し、値型へ写してから `PracticeIndex.build` を呼ぶ。
- `record(itemID:completedAt:)` は `dayKey = DayKey.make(from: completedAt)` を確定して `insert` → `save` を 1 回。続けて索引をメモリ上で更新（`ownedItemIDs.insert` / `practiceDays.insert` / `entries` の先頭挿入）し、連続日数とセクションを再計算する。**fetch は行わない**。
- 保存に失敗した場合（ディスク不足等）はメモリ索引を巻き戻し、UI 上は記録されなかったことになる。リトライ・エラーダイアログ・ログは持たない（L1 妥協特性「運用性」）。

#### 4.3 ポートへの準拠

`OwnershipProviding`（`Gacha/`）と `PracticeRecording`（`Timer/`）はいずれもアクター隔離のない宣言で確定済みである。`PracticeStore` は `@MainActor` のため直接準拠させると隔離の不一致による警告・エラーになり、受け入れ条件「ビルド警告 0 件」を割る。**プロトコル宣言側（他機能のファイル）を変更せず、`Record/` 配下にアダプタを置いて吸収する。**

```swift
// PracticeAdapters.swift
struct StoreOwnershipProvider: OwnershipProviding {
    let store: PracticeStore
    func ownedItemIDs() -> Set<String> {
        MainActor.assumeIsolated { store.ownedItemIDs() }
    }
}

struct StorePracticeRecorder: PracticeRecording {
    let store: PracticeStore
    func recordCompletion(itemID: String, completedAt: Date) {
        MainActor.assumeIsolated { store.record(itemID: itemID, completedAt: completedAt) }
    }
}
```

呼び出し元はいずれも `@MainActor` のビューモデル（`GachaViewModel.spin()` / `StretchTimerViewModel.tick()`）であり、`assumeIsolated` の前提は構造的に満たされる。この判断理由をアダプタのファイル冒頭コメントに明記する。

### 5. 画面仕様

#### 5.1 タブ構成（`RootTabView`）

L1 の「画面はガチャ・図鑑・履歴の 3 つまで」を実現するタブを本機能で導入する。

| タブ | 内容 | 実装 |
|---|---|---|
| ガチャ | `GachaView` | 既存（gacha-draw）。既定の選択タブ |
| 履歴 | `HistoryView` | 本機能で新規 |
| （図鑑） | — | **本機能では追加しない**（stretch-collection の責務。`RootTabView` に 1 タブ足すだけで済む形にする） |

- ラベルは「ガチャ」「履歴」の 2 文字ずつ + SF Symbols（`sparkles` / `list.bullet`）。**アセットは追加しない**。
- 起動時の選択は必ずガチャタブ。したがって gacha-draw の受け入れ条件「ガチャ画面が起動時のルート画面として表示され」は維持される（タブに載っただけで `GachaView` 自体の実装は変更しない）。
- タブ選択状態を永続化しない（起動のたびにガチャから始まる方が、L1 最優先の学習容易性に沿う）。
- stretch-timer の画面は `fullScreenCover` で提示されるためタブバーの上に全面表示され、タイマー画面のレイアウト予算（セーフエリア 647pt）は **変わらない**。

#### 5.2 タブバー導入に伴うガチャ画面の縦配分の再検算

タブバー（設計基準機 iPhone SE 第 2/3 世代・ホームインジケータなしで **49pt**）が加わるため、ガチャ画面・履歴画面の利用可能高さが縮む。**この差分は本機能が持ち込むものであり、ここで明示的に再検算する。**

利用可能高さ = セーフエリア高 647 − タブバー 49 = **598pt**

**ガチャ画面（stretch-card `.result` を載せる側）**

| 区間 | 従来（647pt 前提） | 本機能導入後（598pt 前提） |
|---|---|---|
| 画面上余白 | 16 | 16 |
| カード | 最大 543 | **最大 494** |
| カード〜フッター間 | 16 | 16 |
| フッターボタン | 56 | 56 |
| 画面下余白 | 16 | 16 |
| 合計 | 647 | **598** |

検算: 16 + 494 + 16 + 56 + 16 = **598** ✓

カード内の固定部は stretch-card §4.3 のまま（種目名 2 行で 265pt、1 行で 236pt）なので、

- 手順スクロール領域 = 494 − 265 = **229pt**（種目名 2 行時）／ 494 − 236 = **258pt**（1 行時）

| 手順のケース | 高さ | 229pt に対して |
|---|---|---|
| 4 手順 × 1 行（同梱データの典型） | 126 | 収まる |
| 6 手順 × 1 行 | 194 | 収まる |
| 4 手順 × 2 行 | 222 | 収まる |
| 5 手順 × 2 行 | 280 | スクロール |
| 6 手順 × 4 行（カタログ規約の最大） | 626 | スクロール |

**stretch-card の受け入れ条件（レア度バッジ・部位チップ・種目名・実施時間・フッターが常時可視／手順のみスクロール／規約最大でも全文へ到達可能）は 229pt でも引き続き満たされる。** 変わるのは stretch-card の非機能要件表に記載された数値のみであり、本書導入後は **278pt → 229pt（2 行時）／307pt → 258pt（1 行時）** と読み替える（§「実装方針 / 既存実装との整合」に申し送りとして再掲）。

**タブバー導入で `Card/` 配下を変更しないための前提**: カードは親から与えられた高さに追従する実装であること（画面高さ由来の固定値 543pt を `CardMetrics` に持たない）。もし実装が 543pt を定数として保持していた場合に限り、その定数を親追従へ改める **1 箇所のみ** `Card/` を変更する。それ以外の `Card/` の変更は行わない。

#### 5.3 履歴画面（`HistoryView`）

上から順に。

| # | 要素 | 内容 |
|---|---|---|
| 1 | 連続日数 | 「🔥」+ 数字 40pt bold（`.monospacedDigit`）+ 「日」16pt。中央寄せ。記録が 1 件以上あるときのみ表示 |
| 2 | 区切り線 | 1pt。`Color(.separator)` |
| 3 | リスト | 日付セクション（降順）+ 実施行（時刻降順）。`List`（遅延生成）で描画 |

**セクション見出し**: 「今日 / 2 回」「昨日 / 1 回」「8月18日(火) / 3 回」。件数はセクション内の行数そのもので、新しい指標を導入しない。

**行**: 「14:32 ／ 🙆 ／ 首の横倒し ／ [N]」。時刻・絵文字・種目名・レア度バッジの 4 要素。

- 時刻は `calendar.dateComponents([.hour, .minute], from:)` から `String(format: "%02d:%02d", ...)` で作る（**24 時間表記固定**。`DateFormatter` を使わない。stretch-card が `DateComponentsFormatter` を避けたのと同じ理由）。
- レア度バッジの色は `RarityStyle.accent(for:)` / `badgeForeground(for:)` を参照する。**`Record/` にレア度色を再定義しない**。
- 種目名・絵文字・レア度は `StretchCatalog.shared.item(id:)` で解決する（辞書引き O(1)、fetch 0 本）。カタログに存在しない `itemID` は §4.1 の索引構築時点で除外済みのため、行の描画側に分岐を持たない。
- **行はタップできない**。詳細・削除・スワイプ操作を持たない（`onDelete` を付けない）。
- テキストはすべて `Text(verbatim:)` で描画する（stretch-card と同じ方針）。

**空状態**（記録 0 件）: 絵文字 1 文字（📖）+ 1 行「ガチャを回してストレッチをすると、ここに記録が残ります」。連続日数ブロックは表示しない。エラー表示・リトライ導線は持たない。

**レイアウトメトリクス（設計基準: iPhone SE 375×667・縦画面固定）**

| 区間 | 高さ |
|---|---|
| 画面上余白 | 16 |
| 連続日数ブロック（数字 40pt・行高 48 + 上下余白 12 × 2） | 72 |
| 区切り線 | 1 |
| リスト領域 | 509 |
| 合計（利用可能高さ） | **598** |

検算: 16 + 72 + 1 + 509 = **598** ✓（セーフエリア 647 − タブバー 49）

行高 44pt・セクション見出し 28pt のため、1 日 3 件のセクションは 28 + 44×3 = 160pt。リスト領域 509pt にはおよそ **3 日分**がスクロールなしで収まる。連続日数ブロックは常時可視で、リストのみがスクロールする。

**Dynamic Type**: 連続日数の数字は `.xxxLarge` で頭打ち（固定部が伸びてリストが消えるのを防ぐ）。リスト行と見出しは上限を設けず AX5 まで追随する（スクロール領域内のため）。stretch-card §4.5 と同じ考え方。

**アクセシビリティ**:

- 連続日数は `accessibilityElement(children: .ignore)` で 1 要素にまとめ、ラベル「連続日数」・値「3 日」。🔥 は読み上げない。
- 行は `.combine` で 1 要素にまとめ、「14 時 32 分、首の横倒し、レア度 N」の順に読む。絵文字は `.accessibilityHidden(true)`。
- セクション見出しは標準の `Section` ヘッダとしてそのまま読まれる。

### 6. 処理フロー

```
[アプリ起動]
   ├─ ModelContainer(for: DailyDrawState.self, PracticeRecord.self)
   ├─ PracticeStore(context:) → loadIndex()
   │     └─ fetch 1 本（PracticeRecord 全件・completedAt 降順）
   │           ├─ 値型スナップショットへ写す
   │           ├─ PracticeIndex.build(rows:knownItemIDs:)   ← 不正 dayKey / 未知 itemID を除外
   │           ├─ StreakCalculator.streak(practiceDays:today:)
   │           └─ HistorySectionBuilder.build(entries:today:)
   └─ RootTabView（既定選択 = ガチャ）に .environment(store)
   ▼
[ガチャ画面 onAppear]
   └─ GachaViewModel(ownership: StoreOwnershipProvider(store: store), ...)
         └─ 「回す」タップ時の ownedItemIDs() は索引を返す（**fetch 0 本**）
   ▼
[タイマー完了（stretch-timer の finished 遷移）]
   └─ StorePracticeRecorder.recordCompletion(itemID:completedAt:)   ← 1 回だけ
         ├─ dayKey = DayKey.make(from: completedAt)
         ├─ context.insert(PracticeRecord(...))    ← insert 1
         ├─ context.save()                          ← save 1（設計目標 10ms 未満）
         └─ 索引をメモリ更新 → streak / sections を再計算（fetch 0 本）
   ▼
[履歴タブ]
   ├─ onAppear / scenePhase == .active → refreshForCurrentDay()（日付が変わっていれば再計算のみ）
   └─ store.streakDays / store.sections をそのまま描画（**fetch 0 本**）

--- 中断経路 ---
[タイマーで「やめる」] → recordCompletion は呼ばれない → 記録・図鑑登録・連続日数のいずれも変化しない
```

**記録処理が走るのは stretch-timer の `finished` 遷移時のみ**で、ティックは既に停止している。ガチャ演出中・カウントダウン中にディスク I/O が発生しない構造を維持する。

## 非機能要件

| 項目 | 値 | 根拠・備考 |
|---|---|---|
| 起動時の索引読み込み | SwiftData **fetch 1 本**。設計目標 **50ms 以内**（想定 7,300 件） | gacha-draw の T1 予算に組み込む（下 2 行） |
| 　T1（プロセス起動 → ガチャ画面が操作可能） | 既存設計値 1.00 秒 + 本機能 0.05 秒 = **1.05 秒** | gacha-draw の検収上限 1.19 秒に対し 140ms の余裕 |
| 　コールドスタート → 結果カード表示（E2E） | 1.05 + 1.81 = **2.86 秒** | gacha-draw の上位条件 3.0 秒に対し 140ms の余裕 |
| 　同上・テストのアサート閾値 | **10,000 件の記録からの索引構築が 2 秒以内** | 想定最大 7,300 件の 1.37 倍。実行環境差を吸収する余裕を持った上限 |
| 抽選 1 回あたりの practice-record 由来 fetch | **0 本**（`ownedItemIDs()` はメモリ索引） | gacha-draw の「ガチャ 1 回あたり fetch 0 本」を維持する |
| 記録 1 回のクエリ | **fetch 0 本 / insert 1 / save 1**。実機設計目標 10ms 未満 | 完了遷移時に 1 回だけ |
| 　同上・テストのアサート閾値 | in-memory コンテナで **1,000 回の記録が 10 秒以内** | 1 回 10ms 相当の余裕を持った上限 |
| 履歴画面の表示 | **fetch 0 本**（索引から描画） | |
| 連続日数の算出 | O(連続日数)。実機設計目標 1ms 未満 | 1 ステップは `Set<Int>` 照会 1〜2 回 |
| 　同上・テストのアサート閾値 | **365 日分の実施日集合に対する算出 10,000 回が 2 秒以内** | 1 回 200µs 相当の上限 |
| 1 セッション所要時間への追加 | 完了時の save 1 回分のみ（10ms 未満）→ 合計 **117.82 秒**（規約最大 90 秒の種目・最悪経路） | stretch-timer §8 の 117.81 秒 + 0.01。180 秒に対し 62.18 秒の余裕 |
| 記録の行数 | 1 実施 = 1 行。上限なし。想定 1 日最大 20 行・1 年 **7,300 行** | 削除・アーカイブを持たない |
| ディスク使用量 | 1 行 **200B 未満**、想定 1 年で **1.5MB 未満**（7,300 × 200B = 1.46MB） | 保存するのは UUID・ID 文字列・日時・日付文字列のみ |
| メモリ増分 | 索引 **2MB 未満**（想定 7,300 件） | 値型スナップショット + 集合 2 つ |
| ネットワークリクエスト数 | **0 件** | L1 制約: サーバー・外部 API 禁止 |
| 通知権限の要求回数 | **0 回**（`UserNotifications` を import しない） | stretch-timer の方針を継承 |
| 追加アセット数 | **0 個**（画像・音源・カラーセット・フォントを追加しない） | タブアイコンは SF Symbols |
| 常時アクセス可能な画面数 | **2**（ガチャ / 履歴）。図鑑の追加後に 3 | L1「画面は 3 つまで」 |
| タブバー高さ（設計基準機） | **49pt** | ガチャ画面のカード最大高さが 543 → **494pt**、手順領域が 278 → **229pt** に変わる（§5.2） |
| 履歴画面のリスト領域（設計基準機） | **509pt 以上** | §5.3 の検算 |
| 常時可視を保証する要素 | 連続日数・タブバー | リストのみスクロールする |
| 対応最小画面 | 375×667pt（iPhone SE 第 2/3 世代）・縦画面固定 | L1: iPhone のみ・縦固定 |
| 種目追加時に本機能で変更するファイル数 | **0 ファイル** | 件数・ID をコードに焼き込まない。テストで実証する |
| 想定同時ユーザー数 | 1（自分のみ） | L1 妥協特性: スケーラビリティ |
| 実装完了時期 | MVP（2 週間）内 ※**L1 の仮置き値に基づく** | L1「期限・マイルストーン」が【仮置き】 |

## 非機能優先順位との対応

### 1 位: 学習容易性（説明書なしで初回起動 60 秒以内に最初のガチャ → 実施開始）

- **60 秒の予算に 0 秒を追加する**: 初回の導線（注意書き → ガチャ → カード → はじめる）に履歴画面は一切登場しない。タブの既定選択をガチャに固定し、起動直後に履歴が出ることがない。stretch-timer §「1 位」の内訳 37.8 秒は変わらない。
- **記録の操作を 0 にする**: 「記録する」ボタン・保存確認ダイアログ・実施メモの入力を作らない。タイマーを完走したら自動で記録される。ユーザーが覚える操作が増えない。
- **履歴画面の操作対象を 0 にする**: 行はタップできず、検索・フィルタ・期間切り替え・削除スワイプを持たない。**見るだけの画面**にすることで、説明が要らない状態を保つ。
- **数字を 1 つだけ大きく出す**: 連続日数を 40pt で 1 つだけ置き、最長記録・通算回数・コンプ率を並べない。読み解きの必要な表示を増やさない（コンプ率は collection-progress の判断に委ねる）。
- **日付の表現を人間の言葉に寄せる**: セクション見出しを「今日 / 昨日 / 8月18日(火)」とし、`2026-08-18` のような機械表現を画面に出さない。
- **連続日数の定義がユーザーの実感と噛み合う**: q1 の猶予 1 日により、L1 の成功状態（週 4 日以上）でも連続日数が頻繁に 0 に戻らない。「続いている」という手応えが機能する。
- **失敗状態を作らない**: エラーダイアログ・リトライ導線を持たない。記録 0 件は空状態であってエラーではなく、次に何をすればよいかを 1 行で示す。

### 2 位: パフォーマンス（コールドスタート → 結果 3 秒以内、演出 60fps）

- **T1 への追加を 50ms に固定する**: 起動時の fetch は 1 本のみ。設計値 T1 = 1.05 秒・E2E = 2.86 秒で、gacha-draw の検収上限（T1 1.19 秒 / E2E 3.0 秒）に 140ms の余裕を残す。
- **抽選経路から I/O を排除する**: 入手済み判定をメモリ索引で返し、`ownedItemIDs()` を fetch 0 本にする。gacha-draw の「ガチャ 1 回あたり fetch 0 本」という既存の受け入れ条件を割らない。
- **演出中・カウントダウン中に書き込みを起こさない**: 記録はタイマーの `finished` 遷移時（ティック停止後）に save 1 回だけ。60fps を要求される区間に I/O が重ならない。
- **履歴の描画で永続化層に触れない**: `@Query` を使わず、索引から `sections` を組み立てて `List` に渡す。画面遷移のたびに fetch が走らない。
- **日付計算をループから追い出す**: 連続日数の判定を `Set<Int>` の整数演算だけで行い、`Calendar` の日付加減算をループ内で呼ばない。暦変換は索引構築時に 1 件 1 回だけ。
- **重い描画機能を使わない**: `TimelineView` / `Canvas` / `blur` / `shadow` を使わない。連続日数の数字は `.monospacedDigit` で桁変動によるレイアウト再計算を防ぐ。

### 3 位: 保守性（週末開発でも壊さず拡張できる）

- **判定ロジックを純粋関数に隔離する**: `DayNumber` / `StreakCalculator` / `PracticeIndex.build` / `HistorySectionBuilder` は SwiftUI・SwiftData・`Date`・乱数に依存しない。連続日数の 12 ケースがすべて永続化層なしのユニットテストで検証できる。
- **SwiftData に触る場所を 1 箇所に集める**: `PracticeStore` だけが `ModelContext` を持つ。他のファイルは値型しか扱わない。
- **他機能のコードをほぼ触らない**: 変更は `StretchGachaApp.swift` / `Gacha/GachaView.swift` / `Timer/StretchTimerView.swift` の 3 ファイルのみで、いずれも「Environment から store を取り出してビューモデルに渡す」1〜2 行。`GachaViewModel` / `GachaDrawer` / `DailyDrawStore` / `TimerEngine` / `StretchTimerViewModel` / `Card/` 配下は変更しない。
- **プロトコル宣言を動かさない**: 隔離の不一致はアダプタ 2 つ（`Record/` 配下）で吸収し、`OwnershipProviding` / `PracticeRecording` の宣言に手を入れない。他機能の受け入れ条件に波及させない。
- **日付表現を gacha-draw と揃える**: `dayKey` の形式と生成手法（`Calendar.dateComponents` ベース、`DateFormatter` 不使用）を `DailyDrawState` と同一にし、日付の扱いを 2 通り持たない。
- **レア度色を再定義しない**: 履歴行のバッジは `RarityStyle` を参照する。色の定義箇所は stretch-card の 1 箇所のまま。
- **図鑑タブの追加口を用意する**: `RootTabView` に 1 タブ足すだけで stretch-collection が載る形にし、タブ導入の再設計を後段に発生させない。
- **テストは範囲・上限でアサートする**: 性能は「10,000 件 2 秒以内」「365 日分 × 10,000 回 2 秒以内」「1,000 回 10 秒以内」という余裕を持った上限で書く。「索引構築が 42ms」のような環境差で揺れる厳密値はアサートしない。一方、連続日数・日付変換・曜日・セクション見出しのように経路差で揺れない値は厳密にアサートする。

### 妥協特性で簡略化すること

| 妥協特性 | 本機能で作らないもの |
|---|---|
| スケーラビリティ | 全件をメモリに常駐させる素朴な実装で通す。ページング、部分読み込み、集計テーブル、インデックス最適化、古い記録のアーカイブ・自動削除を持たない。連続日数は毎回線形に遡って求め、キャッシュ層を作らない |
| 互換性・相互運用性 | 記録はこのアプリ専用スキーマ。エクスポート / インポート、CSV・HealthKit 等への変換、iCloud 同期、他端末移行、スキーマのマイグレーション機構を持たない。日付は端末ローカル暦のみ扱い、タイムゾーン変更時に過去記録を再計算しない |
| 運用性 | 記録の失敗ログ、書き込み成否のアナリティクス、バックアップ・復旧手段、記録の整合性チェック用デバッグ画面を持たない。保存に失敗した実施は静かに記録されないだけで、通知もリトライもしない。不具合は自分が使って気づいたら直す |

## セキュリティ

本機能は完全ローカル・単一ユーザーで、ネットワークもテキスト入力も扱わない。攻撃面は「永続化した実施記録の読み戻し」と「他機能へ渡す集合の内容」に限定される。

### 認証・認可

- **不要（実装しない）**。アカウント・ログインを持たない単一端末・単一ユーザー構成（L1 のスコープ外事項）。履歴画面に権限による出し分けは存在しない。
- **書き換え経路を絞る**: 公開 API は追記（`record`）と読み取り（`ownedItemIDs` / `isOwned` / `streakDays` / `sections`）のみ。更新・削除の API を公開せず、`PracticeRecord` の配列を外部へ露出しない（外へ出すのは値型のスナップショットのみ）。
- カタログを書き換える経路を作らない。`StretchCatalog` は読み取り専用で参照する。

### 入力検証

- ユーザー入力はボタンタップとタブ切り替え、リストのスクロールのみ。テキスト入力・数値入力・URL スキーム / ユニバーサルリンクの受け口を持たない。
- **永続化データを「信頼しない入力」として扱う**（§4.1）。
  - `dayKey` は `DayNumber.from(dayKey:)` が形式・値域（月 1...12 / 日 1...31）を検査し、変換できない行は索引から除外する。不正な文字列で連続日数が壊れたりクラッシュしたりしない。
  - `itemID` はカタログの全 ID 集合と突き合わせ、存在しない ID の行は索引から除外する。図鑑の分母（カタログ）に無い種目が「入手済み」として漏れ出さない。
  - 除外はメモリ上の判断に留め、保存済みの行を削除しない（破壊的操作を行わない）。
- **`completedAt` の未来日を無視する**: 端末時刻を先に進めて戻したような記録があっても、`StreakCalculator` は `today` 以前の実施日のみを対象にする（§3.3 規則 1）。連続日数が未来の記録で水増しされない。
- **表示テキストを書式として解釈させない**: 履歴行の種目名は `Text(verbatim:)` で描画する。`LocalizedStringKey` を受けるイニシャライザを `Record/` 配下で使わない（stretch-card と同じ方針）。
- 二重記録の防止は stretch-timer の再入ガードに委ね、本機能では再実装しない（検査点を 2 箇所に分散させない）。

### データ保護

- **保存するのは UUID・種目 ID・完了時刻・日付文字列の 4 つだけ**。氏名・メールアドレス・端末識別子・位置情報・利用統計・自由記述メモを一切保存しない。App Privacy「データ収集なし」申告（appstore-release-prep）と矛盾しない状態を維持する。
- SwiftData のストアは iOS の Data Protection（既定の `NSFileProtectionCompleteUntilFirstUserAuthentication`）下に置かれ、追加の暗号化は行わない（保存内容に秘匿性がないため）。
- **ネットワークを使わない**: `URLSession` / `Network` / `CFNetwork` を import しない。App Transport Security 設定を緩めない。
- **ログ出力を残さない**: `Record/` 配下に `print` / `os_log` / `debugPrint` を書かない。記録内容を外部へ送らない。
- 実施履歴は健康関連の生活パターンを示し得るが、端末外へ出る経路（共有・エクスポート・同期・通知）を 1 つも作らないことで保護する。スクリーンショット制限は設けない（本人の端末で本人のみが見るため）。
- iCloud 同期を有効化しない（`ModelConfiguration` に CloudKit を設定しない）。記録が端末外へ複製されない。

### 依存関係

- 外部ライブラリ 0。`SwiftUI` / `SwiftData` / `Foundation` で完結する（L1 制約: 外部ライブラリ原則ゼロ）。`UIKit` も使わない（ハプティクスは stretch-timer の責務）。

### コンテンツ安全性（法務制約の技術的担保）

- 履歴画面に固定の日本語文言を追加するのは「今日 / 昨日 / 日 / 回 / 連続日数 / ガチャを回してストレッチをすると、ここに記録が残ります」のみ。医学的効能・専門家監修・健康状態の評価を示唆する文言を書かない。
- 記録の解釈（「よく続いています」「不足しています」等の評価コメント）を一切表示しない。数字を出すだけに留める。
- 全体向けの注意書きは safety-notice の責務であり、履歴画面に重複して置かない。

## 実装方針

### 使用技術

- Swift 5.9+ / SwiftUI（iOS 17 以上）、`@Observable` マクロによる状態管理
- SwiftData（`PracticeRecord` 1 モデルのみ追加）
- 日付は `Calendar.current`（`dayKey` の生成と時刻表示のみ）+ 純粋な整数演算（連続日数の判定）
- テストは XCTest（標準）

### 既存実装との整合

- **stretch-catalog（status: issued_local）**: `StretchCatalog.shared.item(id:)` / `totalCount` を読み取り専用で利用する。**`Catalog/` 配下と `StretchCatalog.json` は変更しない**。`itemID` はカタログの安定キーであり、リネーム・削除しない運用ルール（stretch-catalog §1）が本機能の記録の前提になる。
- **gacha-draw（status: issued_local）**: `OwnershipProviding` に `StoreOwnershipProvider` で準拠し、`EmptyOwnershipProvider` から差し替える。差し替えるのは `GachaView` が `GachaViewModel` を生成する箇所の **引数 1 つのみ**で、`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` / `SeededRandomGenerator` には一切変更を加えない。`EmptyOwnershipProvider` はプレビュー・テスト用に残す。
  - **タブバー導入の影響**を §5.2 のとおり再検算済み。ガチャ画面のカード最大高さが 543 → 494pt になるが、gacha-draw の受け入れ条件（E2E 3.0 秒 / T1 1.19 秒 / 演出秒数 / fetch 本数）はいずれも維持される。
- **stretch-card（status: issued_local）**: `Card/` 配下は原則 **0 ファイル変更**。`RarityStyle` を履歴行のバッジで参照するのみ。
  - **申し送り**: stretch-card の非機能要件表「手順スクロール領域の高さ（設計基準機）278pt 以上／307pt」は、本機能のタブバー導入後は **229pt／258pt** に読み替える（§5.2 の検算による）。同機能の受け入れ条件（常時可視・手順のみスクロール・規約最大でも全文到達可能）は 229pt で引き続き満たされるため、受け入れ条件の変更は不要。
  - 例外として、`CardMetrics` にカードの最大高さ 543pt が定数として存在した場合のみ、親追従へ改める 1 箇所を変更する。
- **stretch-timer（status: issued_local）**: `PracticeRecording` に `StorePracticeRecorder` で準拠し、`NoopPracticeRecorder` から差し替える。変更するのは `Timer/StretchTimerView.swift` が `StretchTimerViewModel` を生成する箇所（Environment から store を取り出し `recorder` 引数に渡す）**のみ**で、`TimerEngine` / `TimerClock` / `TimerMetrics` / `CompletionFeedback` / `StretchTimerViewModel` のロジックは変更しない。`NoopPracticeRecorder` はプレビュー・テスト用に残す。
  - タイマー画面は `fullScreenCover` でタブバーの上に全面表示されるため、stretch-timer のレイアウト予算（セーフエリア 647pt・カード 439pt・手順領域 200pt）は変わらない。
- **stretch-collection（未着手）**: `ownedItemIDs()` / `isOwned(_:)` を提供する。図鑑画面・シルエット表現・グリッドレイアウトは作らない。`RootTabView` に図鑑タブを 1 つ足すのが同機能の追加作業になる。
- **collection-progress（後回し）**: コンプ率の算出に必要な値（入手済み ID 集合とカタログの `totalCount`）は本機能とカタログで揃っているため、同機能はストアの API を変えずに実装できる。本機能では表示しない。
- **safety-notice（未着手）**: 相互作用なし。注意書きはルート側で `RootTabView` に被せる形になる（表示制御は safety-notice の責務）。
- Xcode プロジェクト（`stretch-gacha/`）は先行機能の実装時に作成済みの想定。

### 変更対象ファイル

```
stretch-gacha/
├── StretchGacha/
│   ├── Record/
│   │   ├── PracticeRecord.swift          [新規] @Model（id / itemID / completedAt / dayKey）
│   │   ├── PracticeEntry.swift           [新規] メモリ上の値型スナップショット
│   │   ├── DayKey.swift                  [新規] Date → "yyyy-MM-dd" 生成 + 形式検証
│   │   ├── DayNumber.swift               [新規] dayKey → 通し日番号 / 曜日 / セクション見出し
│   │   ├── StreakCalculator.swift        [新規] 連続日数（猶予 1 日）
│   │   ├── PracticeIndex.swift           [新規] 索引構築（純粋・防御的処理）
│   │   ├── HistorySectionBuilder.swift   [新規] 日付セクション整形（純粋）
│   │   ├── PracticeStore.swift           [新規] SwiftData 読み書き + 索引保持
│   │   ├── PracticeAdapters.swift        [新規] 2 ポートへの準拠アダプタ
│   │   ├── HistoryView.swift             [新規] 履歴画面（連続日数 + リスト + 空状態）
│   │   └── HistoryRowView.swift          [新規] 1 行（時刻 / 絵文字 / 種目名 / レア度バッジ）
│   ├── RootTabView.swift                 [新規] ガチャ / 履歴の 2 タブ
│   ├── StretchGachaApp.swift             [変更] PracticeRecord を container に登録、
│   │                                             ルートを RootTabView に、.environment(store)
│   ├── Gacha/
│   │   └── GachaView.swift               [変更] Environment から store を取り、
│   │                                             GachaViewModel の ownership 引数に渡す（1〜2 行）
│   └── Timer/
│       └── StretchTimerView.swift        [変更] Environment から store を取り、
│                                                 StretchTimerViewModel の recorder 引数に渡す（1〜2 行）
└── StretchGachaTests/
    └── PracticeRecordTests.swift         [新規] 日付変換・連続日数・索引・整形・副作用回数・性能
```

### 実装手順

1. **`DayKey.swift`**: `make(from:calendar:)` と `isValid(_:)` を実装。`DateFormatter` を使わない旨と、gacha-draw の `DailyDrawState.dayKey` と同一表現である旨をコメントに残す。
2. **`DayNumber.swift`**: `from(dayKey:)`（civil→days の整数演算）、`weekdaySymbol(_:)`、`sectionTitle(_:today:)` を実装。`Calendar` をこのファイルで import しない。§3.2 の既知値がそのままテストになる。
3. **`StreakCalculator.swift`**: §3.3 の 4 規則を上から順に実装する。リセット判定（`today - last - 1 >= 2`）と遡り（1 日前 → 2 日前）をそれぞれ独立した式に分け、境界値テストから個別に確認できる形にする。猶予 1 日という定義の根拠（q1 回答・L1 の「週 4 日以上」との整合）をコメントに明記する。
4. **`PracticeRecord.swift` / `PracticeEntry.swift`**: モデルと値型を定義。`StretchGachaApp.swift` の `.modelContainer(for:)` に `PracticeRecord.self` を追加する。
5. **`PracticeIndex.swift`**: `build(from:knownItemIDs:)` を実装。不正 `dayKey` の除外・未知 `itemID` の除外・重複の畳み込みをそれぞれ独立した処理に分ける。SwiftData の型を引数に取らない（値型のタプル配列を受ける）ことを構造的な固定点にする。
6. **`HistorySectionBuilder.swift`**: エントリを `dayNumber` 降順にグループ化し、各グループ内を `completedAt` 降順に並べる。見出し文字列は `DayNumber.sectionTitle` を使う。
7. **`PracticeStore.swift`**: `loadIndex()`（fetch 1 本）/ `record(itemID:completedAt:)`（insert 1 + save 1 + 索引のメモリ更新）/ `ownedItemIDs()` / `isOwned(_:)` / `refreshForCurrentDay()` を実装。`init` で `loadIndex()` を 1 回だけ呼ぶ。テスト用に `now` と `calendar` を注入できるようにする。
8. **`PracticeAdapters.swift`**: `StoreOwnershipProvider` / `StorePracticeRecorder` を実装。`MainActor.assumeIsolated` を使う理由（プロトコル宣言を他機能側で変更しないため。呼び出し元は必ず `@MainActor`）をファイル冒頭コメントに明記する。
9. **`HistoryRowView.swift` / `HistoryView.swift`**: §5.3 の 3 要素と空状態を実装。テキストはすべて `Text(verbatim:)`。レア度色は `RarityStyle` を参照。`onDelete` / `NavigationLink` / 検索バーを置かない。`onAppear` と `scenePhase` の `.active` で `refreshForCurrentDay()` を呼ぶ。§5.3 のアクセシビリティ修飾を付ける。
10. **`RootTabView.swift` / `StretchGachaApp.swift`**: 2 タブ（既定選択 = ガチャ）を実装し、ルートを差し替える。`PracticeStore` をルートで 1 つ生成して `.environment(store)` で配下に配る。図鑑タブの追加位置をコメントで明示する。
11. **`GachaView.swift` / `StretchTimerView.swift` の差し替え**: それぞれ `@Environment(PracticeStore.self)` から store を取り出し、`GachaViewModel` の `ownership` / `StretchTimerViewModel` の `recorder` に渡す。他の行に触れない。Preview 用に `PracticeStore` の in-memory 生成ヘルパを用意する。
12. **`PracticeRecordTests.swift`**: 「受け入れ条件」の各項目に 1:1 対応するテストを実装。連続日数は §3.3 の 12 ケースをデータ駆動テストにする。永続化を伴うテストは in-memory の `ModelContainer`（`isStoredInMemoryOnly: true`）で行い、時刻は注入した `now` で固定する。実時間を待つテストを 1 つも書かない。
13. **仕上げ確認**: `Record/` 配下が `URLSession` / `Network` / `CFNetwork` / `UserNotifications` を import していないこと、`print` / `os_log` が無いこと、Assets.xcassets への追加が 0 件であること、ビルド警告 0 件であることを確認する。iPhone SE 実機でタブバー導入後のガチャ画面（カードとフッターが収まるか）、履歴の表示、日をまたいだときの連続日数、ライト / ダーク、Dynamic Type AX5 を目視確認する。

## 受け入れ条件

### 記録と図鑑登録

- [ ] タイマーを完走すると `PracticeRecord` が **1 行**追加され、`itemID` が実施した種目の `id`、`completedAt` が完了時刻、`dayKey` が完了時刻の端末ローカル暦の日付と一致する
- [ ] タイマーを「やめる」で中断した場合、`PracticeRecord` が **0 行**追加され、入手済み集合・連続日数・履歴のいずれも変化しない
- [ ] 完了 1 回につき `context.save()` が **ちょうど 1 回**発生し、`recordCompletion` が 2 回呼ばれれば 2 行になる（本機能側で重複排除を行わない）
- [ ] `ownedItemIDs()` が「1 回以上完了記録がある種目 ID」の集合を返し、同一種目を 3 回実施しても要素数が 1 のままである
- [ ] `ownedItemIDs()` の呼び出しで SwiftData の fetch が **0 本**である（索引から返している）
- [ ] `isOwned(_:)` が `ownedItemIDs()` の内容と常に一致する

### 日付変換（`DayKey` / `DayNumber`）

- [ ] `DayKey.make(from:)` が `"yyyy-MM-dd"` 形式（ゼロ埋め）を返し、`DateFormatter` を使っていない
- [ ] `DayNumber.from("2026-08-19") - DayNumber.from("2026-08-18") == 1`
- [ ] `DayNumber.from("2025-12-31") + 1 == DayNumber.from("2026-01-01")`（年またぎ）
- [ ] `DayNumber.from("2026-03-01") - DayNumber.from("2026-02-28") == 1`（平年）
- [ ] `DayNumber.from("2028-02-29") - DayNumber.from("2028-02-28") == 1` かつ `DayNumber.from("2028-03-01") - DayNumber.from("2028-02-29") == 1`（うるう年）
- [ ] `DayNumber.from` が `"2026-13-01"` / `"2026-08-1"` / `"abc"` / `""` に対して `nil` を返す
- [ ] `DayNumber.weekdaySymbol` が `"2026-08-18"` → 「火」、`"2026-08-19"` → 「水」を返す
- [ ] `DayNumber.sectionTitle` が当日 → 「今日」、前日 → 「昨日」、それ以外 → 「8月18日(火)」形式を返す
- [ ] `DayNumber.swift` が `Calendar` / `DateComponents` / `DateFormatter` を使っていない（純粋な整数演算のみ）

### 連続日数（`StreakCalculator`）

- [ ] `StreakCalculator` が `Set<Int>` と `Int` のみに依存し、SwiftUI・SwiftData・`Date`・`Calendar`・乱数を参照しない（import と引数で確認できる）
- [ ] 実施日なし → **0**
- [ ] 実施日 {T} → **1**
- [ ] 実施日 {T, T−1} → **2**
- [ ] 実施日 {T−1} → **1**（今日未実施でも切れない）
- [ ] 実施日 {T−2} → **1**（抜けは昨日 1 日のみ。当日は抜けに数えない）
- [ ] 実施日 {T−3} → **0**（T−1・T−2 の 2 日連続抜けでリセット）
- [ ] 実施日 {T, T−2, T−3} → **3**
- [ ] 実施日 {T, T−1, T−3, T−4} → **4**
- [ ] 実施日 {T, T−1, T−4} → **2**（T−2・T−3 の 2 日連続抜けで打ち切り）
- [ ] 実施日 {T−3, T−1, T}（月・水・木で火が抜け、木が今日）→ **3**（q1 回答の例と一致）
- [ ] 同一日に 3 件の記録があっても、その日は 1 日として数えられる
- [ ] `T+1`（未来日）の記録が存在しても連続日数に加算されない
- [ ] アプリを起動したまま日付が変わった状態で `refreshForCurrentDay()` を呼ぶと、連続日数が新しい `today` を基準に再計算される（fetch 0 本）

### 索引と防御的処理

- [ ] `PracticeIndex.build` が SwiftData の型を引数に取らず、値型のみから索引を構築する
- [ ] `dayKey` が不正な行（`"2026-13-45"` 等）が保存されていても、クラッシュせずその行だけが索引から除外される
- [ ] カタログに存在しない `itemID` の行が保存されていても、クラッシュせずその行が履歴に表示されず `ownedItemIDs()` にも含まれない
- [ ] 索引から除外された行が SwiftData から削除されていない（行数が減らない）
- [ ] `entries` が `completedAt` の降順に並んでいる

### 履歴画面

- [ ] 履歴タブに、連続日数と、日付セクション（降順）・実施行（時刻降順）のリストが表示される
- [ ] 実施行に 時刻（`HH:mm` の 24 時間表記）・絵文字・種目名・レア度バッジ の 4 要素が表示される
- [ ] セクション見出しが「今日」「昨日」「8月18日(火)」の形式で、その日の件数を伴う
- [ ] 記録が 0 件のとき空状態（絵文字 + 1 行の案内）が表示され、連続日数ブロックが表示されない
- [ ] 履歴画面の表示で SwiftData の fetch が **0 本**である
- [ ] 履歴行がタップできず、削除スワイプ（`onDelete`）・詳細遷移・検索・フィルタ・並べ替えの UI が存在しない
- [ ] 履歴行のテキストがすべて `Text(verbatim:)` で描画され、`LocalizedStringKey` を受ける `Text` イニシャライザが `Record/` 配下に存在しない
- [ ] 履歴行のレア度バッジが `RarityStyle` を参照しており、`Record/` 配下にレア度色の定数が存在しない

### タブ構成と他機能との整合

- [ ] 起動直後に表示されるのがガチャ画面であり、タブが「ガチャ」「履歴」の **2 つ**である（図鑑タブは追加されていない）
- [ ] タブ選択状態が永続化されず、再起動のたびにガチャタブが選択される
- [ ] `Gacha/` 配下の変更が `GachaView.swift` のみであり、`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` / `SeededRandomGenerator` が変更されていない
- [ ] `Timer/` 配下の変更が `StretchTimerView.swift` のみであり、`TimerEngine` / `TimerClock` / `TimerMetrics` / `CompletionFeedback` / `StretchTimerViewModel` / `PracticeRecording` が変更されていない
- [ ] `Catalog/` 配下と `StretchCatalog.json` が変更されていない
- [ ] `Card/` 配下の変更が 0 ファイルである（カードの最大高さ定数を親追従へ改める場合に限り 1 箇所のみ許容し、その場合も他の変更を伴わない）
- [ ] gacha-draw の受け入れ条件「ガチャ 1 回あたりの fetch が 0 本・save が 1 回」が、`OwnershipProviding` を本機能の実装へ差し替えた後も維持される
- [ ] gacha-draw の未入手 2 倍補正が、実際に入手済み種目が存在する状態で有効に働く（入手済み 1 件あたりの出現割合が未入手の約 1/2 になる）
- [ ] stretch-timer の受け入れ条件「完了時に `recordCompletion` が 1 回」「中断時は 0 回」が、本機能の実装へ差し替えた後も維持される

### 性能・規模

- [ ] 起動時の索引読み込みで SwiftData の fetch が **1 本**であり、以後の記録・抽選・履歴表示で fetch が **0 本**である
- [ ] **10,000 件**の記録からの索引構築（連続日数とセクション整形を含む）が **2 秒以内**に完了する（テスト実行環境での上限値。実機での設計目標は想定 7,300 件で 50ms 以内）
- [ ] **365 日分**の実施日集合に対する連続日数の算出 **10,000 回**が **2 秒以内**に完了する（テスト実行環境での上限値）
- [ ] in-memory コンテナで **1,000 回**の `recordCompletion` が **10 秒以内**に完了する（テスト実行環境での上限値。実機での設計目標は 1 回 10ms 未満）
- [ ] **【手動計測】** 実機のコールドスタートからガチャ画面が操作可能になるまで（T1）が **1.19 秒以下**である（gacha-draw の既存条件。本機能の設計値は 1.05 秒）
- [ ] **【手動計測】** 実機のコールドスタートから結果カード表示までのエンドツーエンドが **3.0 秒以内**である（gacha-draw の既存条件。本機能の設計値は 2.86 秒）
- [ ] **【手動計測】** 1 セッション（コールドスタート → ガチャ → カード読了 → 実施 → 完了確認）が **3 分以内**に収まる

### 構造・依存

- [ ] `Record/` 配下のソースが `URLSession` / `Network` / `CFNetwork` / `UserNotifications` を import していない
- [ ] `Record/` 配下に `print` / `os_log` / `debugPrint` によるログ出力が存在しない
- [ ] `ModelConfiguration` に CloudKit（iCloud 同期）が設定されていない
- [ ] 画像・音源・カラーセットを 1 つも追加していない（Assets.xcassets への追加が 0 件）
- [ ] 種目名・部位名・レア度名の文字列リテラルが `Record/` 配下に存在しない（`StretchCatalog` と `displayName` 経由でのみ取得している）
- [ ] カタログに種目を 1 件追加したフィクスチャで、`Record/` 配下のコードを 1 行も変更せずに、その種目の記録・図鑑登録・履歴表示が成立する
- [ ] 記録の削除・編集・エクスポートを行う公開 API が存在しない
- [ ] 本機能の実装によりビルド警告が 0 件である

### 表示確認

- [ ] **【表示確認】** iPhone SE（375×667）縦画面で、タブバー導入後もガチャ結果画面のレア度バッジ・部位チップ・種目名・実施時間・フッター（「はじめる」「もう 1 回」）が常時可視であり、手順のみがスクロールする
- [ ] **【表示確認】** iPhone SE 縦画面で履歴画面の連続日数が常時可視であり、リストのみがスクロールする
- [ ] **【表示確認】** タイマー画面（`fullScreenCover`）がタブバーの上に全面表示され、stretch-timer のレイアウト（残り秒数・進捗バー・カード・「やめる」の常時可視）が変わっていない
- [ ] **【表示確認】** ライトモード / ダークモードの両方で、連続日数・セクション見出し・行のテキスト・レア度バッジが識別できる
- [ ] **【表示確認】** Dynamic Type を AX5 にしても、連続日数ブロックが固定部に収まり、リストが画面外へ押し出されない
- [ ] **【表示確認】** VoiceOver で連続日数が「連続日数、3 日」の 1 要素として読まれ、続いてセクション見出し・「14 時 32 分、首の横倒し、レア度 N」の順に読み上げられ、🔥 と種目の絵文字が読み上げられない

## 仮置き依存

| # | L1 の仮置き値 | 本書での依存箇所 | 仮置きが覆った場合の影響 |
|---|---|---|---|
| 1 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 新規入手（図鑑初登録）の演出、履歴の検索・フィルタ・期間切り替え・カレンダー表示・グラフ、最長連続記録・通算実施回数の表示、記録の削除・編集 UI を作らないと決めた判断 | 期間が延びる場合、まず新規入手の演出を検討する余地がある。ただし `PracticeRecording.recordCompletion` の戻り値が `Void` で確定しているため、stretch-timer 側のポート定義と完了画面の変更を伴い、本機能単独では完結しない。履歴の検索・統計表示は `HistoryView` と純粋関数の追加のみで収まり、`PracticeRecord` のスキーマ・連続日数の定義には波及しない |
| 2 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 非機能要件の「実装完了時期: MVP（2 週間）内」 | MVP 期間が変わっても本機能の設計値（連続日数の定義、T1 への追加 50ms、fetch 本数、レイアウト予算 494 / 509pt）は変わらない |
| 3 | 期限・マイルストーン「4 週間の自己利用で継続できたら App Store 公開を判断」 | 記録の保持を無制限とし、古い記録のアーカイブ・自動削除・保持期間設定を作らないと決めた判断（4 週間で数十件、1 年でも 7,300 件規模という見積りに基づく） | 自己利用期間が大幅に延びても、想定 1 年 7,300 行・1.5MB 未満であり索引構築の上限（10,000 件 2 秒以内）に収まる。数年規模で使い続ける場合のみ、索引の部分読み込みかアーカイブの検討が必要になるが、`PracticeStore` の内部変更で収まり、純粋関数群と `PracticeRecord` のスキーマには波及しない |
| 4 | 配布・審査「当面は Xcode 直接インストール。4 週間後に App Store 公開を判断」 | 記録の iCloud 同期・バックアップ・他端末移行・エクスポートを持たないと決めた判断。App Privacy「データ収集なし」申告と整合する状態を維持する判断 | 公開判断が前倒しになっても、端末外へ出さない構成は「データ収集なし」申告と整合し、審査上の追加対応は生じない。逆に将来 iCloud 同期を導入する場合は、記録が端末外へ複製されるため App Privacy の申告内容と L1 の「個人情報は収集しない」制約側の再判断が必要になる |

## 実装記録
