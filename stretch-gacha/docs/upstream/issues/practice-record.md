---
feature: practice-record
spec: veronica-docs/stretch-gacha/features/practice-record/spec.md
generated_at: 2026-08-18
---

# practice-record: ストレッチ実施記録と図鑑登録・連続日数・履歴画面の実装

## 背景

stretch-gacha は「ガチャで種目を引く → タイマーで実施する → 図鑑に溜まる」という 1 本の輪で継続を促すアプリだが、現時点でその輪の最後のピースである **実施記録** が存在しない。

- stretch-timer は完走時に `PracticeRecording.recordCompletion(itemID:completedAt:)` を呼ぶが、実装は `NoopPracticeRecorder`（何もしない）である。
- gacha-draw は未入手種目の出現率を 2 倍にする補正を持つが、`OwnershipProviding` の実装が `EmptyOwnershipProvider`（常に空集合）のため、補正が実運用で効いていない。
- stretch-collection（図鑑）の入手済み判定も、供給元となる集合が無いため着手できない。
- L1 が定める 3 画面（ガチャ / 図鑑 / 履歴）のうち「履歴」が未実装で、タブ構成自体も存在しない。

本 issue は、この 3 つの穴を 1 つの永続化モデル（実施記録 1 行）から埋める。記録は SwiftData でローカルにのみ保存し、実施記録以外の情報は一切持たない。

L1 の成功指標「4 週間、週 4 日以上」を直接支えるのは「やった事実が積み上がって見えること」であり、連続日数と時系列の履歴がその手応えを担う。同時に、図鑑登録が発生することで gacha-draw の未入手補正と stretch-collection のシルエット解除が動き出す。

## ゴール

1. **記録の唯一の書き手になる**: stretch-timer の完了イベントを `PracticeRecord` 1 行として永続化する。ユーザー操作は一切要求しない（完走したら自動で記録される）。
2. **図鑑登録の供給元になる**: `OwnershipProviding.ownedItemIDs()` を「1 回以上実施完了した種目 ID の集合」で実装し、gacha-draw の未入手 2 倍補正を実運用で有効にする。**この呼び出しで SwiftData の fetch を 0 本に保つ**（メモリ索引から返す）。
3. **履歴画面とタブ構成を提供する**: 連続日数（猶予 1 日）と時系列の実施履歴を表示する `HistoryView`、およびガチャ / 履歴の 2 タブを持つ `RootTabView` を導入する。
4. **判定ロジックを純粋関数に隔離する**: 日付変換・連続日数・索引構築・履歴整形を `Calendar` / SwiftUI / SwiftData / `Date` / 乱数に依存しない形で実装し、境界値をユニットテストで検証可能にする。
5. **他機能をほぼ触らない**: 既存コードの変更を `StretchGachaApp.swift` / `Gacha/GachaView.swift` / `Timer/StretchTimerView.swift` の 3 ファイル・各 1〜2 行に留め、プロトコル宣言側を変更しない。

## スコープ（やること / やらないこと）

### やること

- 実施記録モデル `PracticeRecord`（SwiftData `@Model`。`id` / `itemID` / `completedAt` / `dayKey`）の定義と永続化。**1 実施完了 = 1 行の追記専用**
- 日付キー生成 `DayKey`（端末ローカル暦の `"yyyy-MM-dd"`。gacha-draw の `DailyDrawState.dayKey` と同じ表現・同じ生成手法。`DateFormatter` 不使用）
- 日付キー → 通し日番号の純粋変換 `DayNumber`（`Calendar` 非依存の civil→days 整数演算。曜日算出・セクション見出し生成を含む）
- 連続日数の算出 `StreakCalculator`（**猶予 1 日**＝抜けは連続 1 日まで許容。当日は抜けに数えない）
- メモリ索引 `PracticeIndex` / 値型スナップショット `PracticeEntry`（入手済み ID 集合・実施日集合・履歴エントリ）と、その構築純粋関数（不正 `dayKey` / 未知 `itemID` の除外を含む防御的処理）
- 履歴のセクション整形 `HistorySectionBuilder`（日付降順・時刻降順）
- 記録ストア `PracticeStore`（SwiftData 読み書き + 索引保持 + 2 ポートの実装 + 日跨ぎ再計算）
- `PracticeRecording` / `OwnershipProviding` への準拠アダプタ `PracticeAdapters`（`Timer/` `Gacha/` のプロトコル宣言を変更しないための橋渡し。`MainActor.assumeIsolated` で隔離差を吸収）
- 履歴画面 `HistoryView` / `HistoryRowView`（連続日数 + 時系列リスト + 空状態）
- タブ構成 `RootTabView`（ガチャ / 履歴の 2 タブ。既定選択はガチャ）
- `StretchGachaApp` の変更（`ModelContainer` へ `PracticeRecord` を登録、ルートを `RootTabView` へ、`PracticeStore` を Environment へ注入）
- `GachaView` / `StretchTimerView` から `PracticeStore` を受け渡す最小変更（各 1〜2 行）
- タブバー導入（49pt）に伴うガチャ画面の縦配分の再検算と、その反映
- 上記すべてのユニットテスト（連続日数の境界値・日付変換・索引・整形・副作用回数・性能）

### やらないこと

- **図鑑画面そのもの・シルエット表現・コンプ率**（stretch-collection / collection-progress の責務）。本機能は入手済み ID 集合を返すところまで
- **タイマーの実行・完了判定**（stretch-timer の責務）。完了イベントを受け取るだけで状態機械に触れない
- **抽選ロジック・演出**（gacha-draw の責務）。`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` / `SeededRandomGenerator` に変更を加えない
- **新規入手（図鑑初登録）の演出**: `recordCompletion` の戻り値が `Void` で確定しており、stretch-timer 側のポート定義と完了画面の変更を伴うため MVP 不採用（コメントに将来の拡張候補として残すのみ）
- **二重記録の防止ロジック**: stretch-timer の再入ガードが担保済み。検査点を 2 箇所に分散させない
- **履歴の削除・編集・手動追加 UI**、実施の取り消し
- **履歴の検索・フィルタ・並べ替え・期間切り替え（週 / 月表示）・カレンダー表示・グラフ**
- **最長連続記録・通算実施回数・部位別集計などの統計表示**
- **履歴行のタップによる詳細遷移**（種目詳細は図鑑の責務）
- **記録のエクスポート / インポート / iCloud 同期 / バックアップ / 他端末移行**
- **リマインダー通知・週次サマリ通知**（`UserNotifications` を import しない）
- 古い記録の自動削除・アーカイブ・保持期間の設定
- サーバー・外部 API・アナリティクス送信、外部ライブラリの追加

## 実装方針の要約

### 全体構造

```
Record/
├── PracticeRecord.swift          [新規] @Model（id / itemID / completedAt / dayKey）
├── PracticeEntry.swift           [新規] メモリ上の値型スナップショット
├── DayKey.swift                  [新規] Date → "yyyy-MM-dd" 生成 + 形式検証
├── DayNumber.swift               [新規] dayKey → 通し日番号 / 曜日 / セクション見出し
├── StreakCalculator.swift        [新規] 連続日数（猶予 1 日）
├── PracticeIndex.swift           [新規] 索引構築（純粋・防御的処理）
├── HistorySectionBuilder.swift   [新規] 日付セクション整形（純粋）
├── PracticeStore.swift           [新規] SwiftData 読み書き + 索引保持
├── PracticeAdapters.swift        [新規] 2 ポートへの準拠アダプタ
├── HistoryView.swift             [新規] 履歴画面
└── HistoryRowView.swift          [新規] 1 行（時刻 / 絵文字 / 種目名 / レア度バッジ）
RootTabView.swift                 [新規] ガチャ / 履歴の 2 タブ
StretchGachaApp.swift             [変更] container 登録・ルート差し替え・.environment(store)
Gacha/GachaView.swift             [変更] ownership 引数の差し替え（1〜2 行）
Timer/StretchTimerView.swift      [変更] recorder 引数の差し替え（1〜2 行）
StretchGachaTests/PracticeRecordTests.swift  [新規]
```

依存の向きは **practice-record → stretch-catalog / 各ポートのプロトコル宣言** の一方向。gacha-draw・stretch-timer から practice-record の型を参照させない。

### 1. 日付の扱い（端末ローカル暦の午前 0 時）

- `DayKey.make(from:calendar:)` は `calendar.dateComponents([.year, .month, .day], from:)` から `String(format: "%04d-%02d-%02d", ...)` で組み立てる。**`DateFormatter` を使わない**（ロケール・カレンダー設定による出力揺れを避けるため）。
- `dayKey` は **記録時に確定して保存**し、以後タイムゾーンが変わっても過去の行を再計算しない。判定に使うのは保存済みの `dayKey` であり、`completedAt` から導出し直さない。
- `DayNumber.from(dayKey:)` は 1970-01-01 を 0 とする通し日番号へ変換する。うるう年・400 年周期を含む純粋な整数演算で実装し、この関数の内側で `Calendar` / `DateComponents` を使わない。形式不正（`^\d{4}-\d{2}-\d{2}$` 不一致、月 1...12 / 日 1...31 の範囲外）は `nil`。
- 曜日は `((n % 7) + 7 + 4) % 7`（1970-01-01 が木曜であることに由来する +4 補正）で 0=日曜として求め、`"日月火水木金土"` を索引する。
- `sectionTitle(_:today:)` は `n == today` → 「今日」、`n == today - 1` → 「昨日」、それ以外 → 「8月18日(火)」の 3 分岐のみ。
- 日付境界は端末ローカルの午前 0 時。午前 4 時等へずらす特別処理は作らない（0 時をまたぐ実施は連続日数の猶予が吸収する）。

### 2. 連続日数の定義（猶予 1 日）

`StreakCalculator.streak(practiceDays: Set<Int>, today: Int) -> Int` を、以下の規則をこの順で適用する形で実装する。

1. `today` 以前の実施日のうち最大のものを `last` とする。存在しなければ **0**（`today` より後の日付を持つ記録は無視する）。
2. `today - last - 1 >= 2` なら **0**。`last` と `today` の間の抜けが 2 日以上連続した時点でリセットする。**当日はまだ終わっていないため抜けとして数えない**。
3. `last` から遡る。カーソルの 1 日前に実施があればそこへ移り、無ければ 2 日前を見る（**抜け 1 日を許容**）。2 日前にも無ければ打ち切る。
4. 移動した回数 + 1 を返す。**数えるのは「実施した日」の数だけ**で、猶予で許容した抜け日はカウントしない。

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

リセット判定と遡りをそれぞれ独立した式に分け、境界値テストから個別に確認できる形にする。猶予 1 日という定義の根拠（L1 の「週 4 日以上」との整合）をコメントに明記する。計算量は O(連続日数)、1 ステップは `Set<Int>` の照会 1〜2 回。

### 3. メモリ索引と記録ストア

gacha-draw の受け入れ条件「ガチャ 1 回あたりの fetch が 0 本」を維持するため、**入手済み判定を毎回 SwiftData に問い合わせない**。起動時に 1 度だけ全件を読み、値型のスナップショットとしてメモリに保持する。

```swift
struct PracticeEntry: Equatable { let itemID: String; let completedAt: Date; let dayNumber: Int }

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

```swift
@Observable @MainActor
final class PracticeStore {
    private(set) var streakDays: Int = 0
    private(set) var sections: [HistorySection] = []

    init(context: ModelContext, catalog: StretchCatalog = .shared,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current)  // init 内で loadIndex() を 1 回

    func loadIndex()                                  // fetch 1 本。起動時のみ
    func record(itemID: String, completedAt: Date)    // insert 1 + save 1、索引をメモリ更新
    func ownedItemIDs() -> Set<String>                // 索引を返す。fetch 0 本
    func isOwned(_ itemID: String) -> Bool            // O(1)
    func refreshForCurrentDay()                       // 日付が変わっていれば streak / 見出しのみ再計算
}
```

- `loadIndex()` は `FetchDescriptor<PracticeRecord>`（`completedAt` 降順）を **1 本**だけ実行し、値型へ写してから `PracticeIndex.build` を呼ぶ。索引が `@Model` インスタンスを保持しないことで、純粋関数群のテストが永続化層なしで完結する。
- `record(itemID:completedAt:)` は `dayKey` を確定して `insert` → `save` を 1 回。続けて索引をメモリ上で更新し、連続日数とセクションを再計算する。**fetch は行わない**。
- 保存に失敗した場合はメモリ索引を巻き戻す。リトライ・エラーダイアログ・ログは持たない。
- 索引は起動時と記録時にしか更新されないため、`HistoryView` の `onAppear` と `scenePhase == .active` 復帰時に `refreshForCurrentDay()` を呼び、`today` が変化していれば連続日数とセクション見出しのみ再計算する（fetch 0 本）。
- SwiftData に触るのは `PracticeStore` だけ。他のファイルは値型しか扱わない。

### 4. ポートへの準拠（アダプタで隔離差を吸収）

`OwnershipProviding`（`Gacha/`）と `PracticeRecording`（`Timer/`）はアクター隔離のない宣言で確定済みのため、`@MainActor` の `PracticeStore` を直接準拠させると警告・エラーになり「ビルド警告 0 件」を割る。**プロトコル宣言側を変更せず、`Record/` 配下にアダプタを置いて吸収する。**

```swift
struct StoreOwnershipProvider: OwnershipProviding {
    let store: PracticeStore
    func ownedItemIDs() -> Set<String> { MainActor.assumeIsolated { store.ownedItemIDs() } }
}

struct StorePracticeRecorder: PracticeRecording {
    let store: PracticeStore
    func recordCompletion(itemID: String, completedAt: Date) {
        MainActor.assumeIsolated { store.record(itemID: itemID, completedAt: completedAt) }
    }
}
```

呼び出し元はいずれも `@MainActor` のビューモデル（`GachaViewModel.spin()` / `StretchTimerViewModel.tick()`）であり、`assumeIsolated` の前提は構造的に満たされる。この判断理由をファイル冒頭コメントに明記する。`EmptyOwnershipProvider` / `NoopPracticeRecorder` はプレビュー・テスト用に残す。

### 5. 画面

**`RootTabView`**: ガチャ（`GachaView`・既定選択）/ 履歴（`HistoryView`）の 2 タブ。ラベルは 2 文字 + SF Symbols（`sparkles` / `list.bullet`）で、アセットは追加しない。タブ選択状態は永続化せず、起動のたびにガチャから始まる。図鑑タブの追加位置をコメントで明示する。タイマー画面は `fullScreenCover` でタブバーの上に全面表示されるため、stretch-timer のレイアウト予算は変わらない。

**タブバー導入に伴うガチャ画面の縦配分の再検算**（設計基準機 iPhone SE・タブバー 49pt）

利用可能高さ = セーフエリア 647 − タブバー 49 = **598pt**

| 区間 | 従来 | 導入後 |
|---|---|---|
| 画面上余白 | 16 | 16 |
| カード | 最大 543 | **最大 494** |
| カード〜フッター間 | 16 | 16 |
| フッターボタン | 56 | 56 |
| 画面下余白 | 16 | 16 |
| 合計 | 647 | **598** ✓ |

手順スクロール領域は 494 − 265 = **229pt**（種目名 2 行時）／ 494 − 236 = **258pt**（1 行時）。stretch-card の受け入れ条件（レア度バッジ・部位チップ・種目名・実施時間・フッターが常時可視／手順のみスクロール／規約最大でも全文へ到達可能）は 229pt でも引き続き満たされる。**申し送り**: stretch-card の非機能要件表「278pt 以上／307pt」は本機能導入後 **229pt／258pt** に読み替える（受け入れ条件の変更は不要）。

**`HistoryView`**（上から順）

| # | 要素 | 内容 |
|---|---|---|
| 1 | 連続日数 | 「🔥」+ 数字 40pt bold（`.monospacedDigit`）+ 「日」16pt。中央寄せ。記録が 1 件以上あるときのみ |
| 2 | 区切り線 | 1pt。`Color(.separator)` |
| 3 | リスト | 日付セクション（降順）+ 実施行（時刻降順）。`List`（遅延生成） |

- セクション見出し: 「今日 / 2 回」「昨日 / 1 回」「8月18日(火) / 3 回」。件数はセクション内の行数そのもの。
- 行: 「14:32 ／ 🙆 ／ 首の横倒し ／ [N]」の 4 要素。時刻は `dateComponents([.hour, .minute])` + `String(format: "%02d:%02d", ...)` の **24 時間表記固定**（`DateFormatter` 不使用）。種目名・絵文字・レア度は `StretchCatalog.shared.item(id:)` で O(1) 解決（カタログに無い `itemID` は索引構築時点で除外済みのため描画側に分岐を持たない）。レア度色は `RarityStyle.accent(for:)` / `badgeForeground(for:)` を参照し、`Record/` に再定義しない。
- **行はタップできない**。詳細・削除・スワイプ（`onDelete`）を持たない。テキストはすべて `Text(verbatim:)`。
- 空状態（記録 0 件）: 📖 + 1 行「ガチャを回してストレッチをすると、ここに記録が残ります」。連続日数ブロックは表示しない。エラー表示・リトライ導線は持たない。

**レイアウトメトリクス**: 画面上余白 16 + 連続日数ブロック 72 + 区切り線 1 + リスト領域 509 = **598** ✓。行高 44pt・セクション見出し 28pt のため、リスト領域におよそ 3 日分がスクロールなしで収まる。

**Dynamic Type**: 連続日数の数字は `.xxxLarge` で頭打ち。リスト行と見出しは上限を設けず AX5 まで追随する。

**アクセシビリティ**: 連続日数は `accessibilityElement(children: .ignore)` で 1 要素にまとめ、ラベル「連続日数」・値「3 日」（🔥 は読み上げない）。行は `.combine` で 1 要素にまとめ「14 時 32 分、首の横倒し、レア度 N」の順に読む（絵文字は `.accessibilityHidden(true)`）。

### 6. 処理フロー

```
[起動] ModelContainer(for: DailyDrawState.self, PracticeRecord.self)
   └ PracticeStore(context:) → loadIndex()  ← fetch 1 本
        → 値型へ写す → PracticeIndex.build → StreakCalculator → HistorySectionBuilder
   └ RootTabView（既定 = ガチャ）に .environment(store)
[ガチャ] GachaViewModel(ownership: StoreOwnershipProvider(store:)) → ownedItemIDs() は fetch 0 本
[完了]  StorePracticeRecorder.recordCompletion → dayKey 確定 → insert 1 → save 1 → 索引をメモリ更新
[履歴]  onAppear / scenePhase .active → refreshForCurrentDay() → store の値をそのまま描画（fetch 0 本）
[中断]  recordCompletion は呼ばれない → 記録・図鑑登録・連続日数のいずれも変化しない
```

記録処理が走るのは `finished` 遷移時のみで、ティックは既に停止している。ガチャ演出中・カウントダウン中にディスク I/O が発生しない構造を維持する。

### 7. 実装順序

1. `DayKey.swift` → 2. `DayNumber.swift` → 3. `StreakCalculator.swift` → 4. `PracticeRecord.swift` / `PracticeEntry.swift`（+ `.modelContainer(for:)` への登録）→ 5. `PracticeIndex.swift` → 6. `HistorySectionBuilder.swift` → 7. `PracticeStore.swift` → 8. `PracticeAdapters.swift` → 9. `HistoryRowView.swift` / `HistoryView.swift` → 10. `RootTabView.swift` / `StretchGachaApp.swift` → 11. `GachaView.swift` / `StretchTimerView.swift` の引数差し替え → 12. `PracticeRecordTests.swift` → 13. 仕上げ確認。

純粋関数（1〜3、5、6）を先に完成させ、永続化層なしでテストが通る状態を作ってから UI と接続する。

### 8. 非機能目標

| 項目 | 値 |
|---|---|
| 起動時の索引読み込み | fetch **1 本**。設計目標 50ms 以内（想定 7,300 件）。T1 = 1.05 秒 / E2E = 2.86 秒 |
| 抽選 1 回あたりの本機能由来 fetch | **0 本** |
| 記録 1 回 | fetch 0 本 / insert 1 / save 1。設計目標 10ms 未満 |
| 履歴画面の表示 | fetch **0 本** |
| 連続日数の算出 | O(連続日数)。設計目標 1ms 未満 |
| ディスク使用量 | 1 行 200B 未満。想定 1 年 7,300 行で 1.5MB 未満 |
| メモリ増分 | 索引 2MB 未満 |
| ネットワーク / 通知権限要求 / 追加アセット | **0** |
| 外部ライブラリ | 0（`SwiftUI` / `SwiftData` / `Foundation` のみ。`UIKit` も使わない） |

テストは環境差で揺れる厳密値（「索引構築が 42ms」等）をアサートせず、余裕を持った上限でアサートする。一方、連続日数・日付変換・曜日・セクション見出しのように経路差で揺れない値は厳密にアサートする。実時間を待つテストを 1 つも書かない（永続化を伴うテストは `isStoredInMemoryOnly: true`、時刻は注入した `now` で固定）。

### 9. セキュリティ / データ保護の要点

- 保存するのは UUID・種目 ID・完了時刻・日付文字列の 4 つだけ。氏名・メール・端末識別子・位置情報・利用統計・自由記述メモを保存しない（App Privacy「データ収集なし」申告と整合）。
- 公開 API は追記と読み取りのみ。更新・削除の API を公開せず、`PracticeRecord` の配列を外部へ露出しない。`StretchCatalog` は読み取り専用で参照する。
- 永続化データを「信頼しない入力」として検証し、不正行はメモリ上で除外するのみ（保存済みの行を削除しない）。未来日の記録は連続日数に加算しない。
- `URLSession` / `Network` / `CFNetwork` / `UserNotifications` を import しない。`print` / `os_log` / `debugPrint` を書かない。`ModelConfiguration` に CloudKit を設定しない。
- 履歴画面に追加する固定文言は「今日 / 昨日 / 日 / 回 / 連続日数 / ガチャを回してストレッチをすると、ここに記録が残ります」のみ。医学的効能・健康状態の評価を示唆する文言、記録への評価コメントを一切表示しない。

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
- [ ] 実施日 {T−3, T−1, T}（月・水・木で火が抜け、木が今日）→ **3**
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

## 参照

- **機能仕様ドキュメント（本 issue の一次情報源）**: `veronica-docs/stretch-gacha/features/practice-record/spec.md`
  - §1 責務境界 / §2 データモデル / §3 日付の扱い（3.2 既知値の表・3.3 境界値 12 ケース）/ §4 メモリ索引と記録ストア / §5 画面仕様（5.2 縦配分の再検算・5.3 レイアウトメトリクス）/ §6 処理フロー
  - 「非機能要件」「非機能優先順位との対応」「セキュリティ」「実装方針」「受け入れ条件」「仮置き依存」
- **関連機能仕様**
  - stretch-catalog（`StretchCatalog.shared.item(id:)` / `totalCount` を読み取り専用で利用。`Catalog/` と `StretchCatalog.json` は変更しない）
  - gacha-draw（`OwnershipProviding` の実装差し替え先。fetch 0 本・T1 1.19 秒 / E2E 3.0 秒の既存条件を維持する）
  - stretch-timer（`PracticeRecording` の実装差し替え先。二重記録防止の再入ガードは同機能が担保）
  - stretch-card（`RarityStyle` を参照。手順スクロール領域の数値を 278pt → 229pt / 307pt → 258pt に読み替える申し送りあり）
  - stretch-collection / collection-progress（本機能が提供する `ownedItemIDs()` / `isOwned(_:)` の消費側。図鑑タブは `RootTabView` に 1 タブ足すだけで載る形にする）
  - safety-notice（相互作用なし。注意書きは `RootTabView` に被せる形で同機能が制御する）
- **仮置き依存**: L1 の「MVP を 2 週間で実機投入」「4 週間の自己利用で公開判断」「当面は Xcode 直接インストール」に依存する判断（新規入手演出・統計表示・検索/フィルタ・アーカイブ・同期を作らない判断）は spec.md「仮置き依存」表を参照。いずれも覆っても `PracticeRecord` のスキーマと純粋関数群には波及しない。
