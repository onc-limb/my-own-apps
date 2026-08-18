# 機能仕様: stretch-timer

## 変更履歴

- 2026-08-18 初版作成
- 2026-08-18 L3 指摘対応: `displaySeconds` のコメントを受け入れ条件と一致する記述へ修正、スコープの状態機械記述から `ready` を削除、`StretchTimerViewModel.init` に自動ロック抑止セッタの注入口を追加、遷移表に `running` 中の `resume()`（無視）を追記

## 概要と提供価値

stretch-card が表示した `StretchItem` について、カード下部の「はじめる」1 タップで `durationSeconds` 秒のカウントダウンを開始し、0 になったら画面表示とハプティクスで完了を知らせる機能。実施中もカードがそのまま画面に残るため、手順を読みながら身体を動かせる。

タイマーは **単一の通しカウントダウン**（例: 60 秒の種目は 60 → 0 の 1 本）とし、左右のある種目の切り替え合図は出さない（q1 回答）。切り替えタイミングは `StretchCatalog.json` の手順テキストに「残り 30 秒になったら反対側へ」の形で残り秒数基準で明記する運用ルールで担保する。カタログのスキーマは変更しない。

提供価値は 2 つ。

1. **時間を測る手間をなくす**: ストップウォッチアプリへの切り替え・秒数の暗算・数え間違いを排除する。「はじめる」から完了まで画面遷移も操作もなく、L1 最優先の学習容易性（初回起動 60 秒以内に実施開始）の最後の 1 タップを担う。
2. **やり切れる状態を維持する**: 実施中は自動ロックを抑止し、手順を常時可視に保つ。バックグラウンドへ回れば一時停止し、戻れば残り秒から再開する（q3 回答 (a)）。通知権限は一切求めない。

タイマーは何も永続化しない。残り時間の算出は単調増加クロックを注入した純粋関数で行い、状態遷移・境界値をすべてユニットテストで検証できる形にする。

## スコープ（やること / やらないこと）

### やること

- 残り時間・進捗・完了判定の純粋計算 `TimerEngine`
- 単調クロックの抽象 `TimerClock`（本番 `ContinuousClock` / テスト `TestTimerClock`）
- 状態機械 `StretchTimerViewModel`（running ⇄ paused → finished / 中断）
- タイマー画面 `StretchTimerView`（残り秒数 + 進捗バー + カード + 「やめる」）
- 完了時のハプティクス（`UINotificationFeedbackGenerator(.success)` を 1 回）
- 実施中の自動ロック抑止（`UIApplication.shared.isIdleTimerDisabled`）と、画面離脱時の確実な解除
- バックグラウンド遷移での一時停止・復帰での自動再開（`scenePhase` 監視）
- 実施完了の記録ポート `PracticeRecording` 定義と、practice-record 未実装時の既定実装（何もしない）
- `GachaView` の結果カードのフッターに「はじめる」/「もう 1 回」の 2 ボタンを置き、タイマー画面をモーダル表示する変更
- `StretchCatalog.json` のうち、前後半で対象が切り替わる **13 件の手順テキストのみ**を残り秒数基準の表現へ更新（§3.3）
- 上記すべてのユニットテスト（残り時間・進捗・状態遷移・境界値・防御的処理・性能）

### やらないこと

- **セグメント分割（左右の中間合図）**: q1 でカタログのスキーマ追加を伴うため MVP 不採用。将来の拡張候補としてカタログの `segments` フィールド案をコメントに残すのみで、実装しない
- **完了音・BGM**: q2 で不採用。音源アセットを持たず、`AVFoundation` / `AudioToolbox` を import しない（gacha-draw の決定を維持）
- **ローカル通知・通知権限要求**: q3 で不採用。`UserNotifications` を import しない
- **手動の一時停止 / 再開ボタン**: 画面上の操作対象を「やめる」1 つに保つ。一時停止はバックグラウンド遷移に対する自動処理のみ
- **秒数の変更 UI**（延長・短縮・カスタム秒数）、セット数・インターバル・連続実施モード
- **実施記録・図鑑登録・連続日数の算出**（practice-record の責務）。本機能は完了イベントをポートへ 1 回渡すところまで
- **カードのレイアウト**（stretch-card の責務）。`StretchCardView(item:style:.detail)` をそのまま使い、`Card/` 配下を 1 行も変更しない
- **抽選・演出**（gacha-draw の責務）。`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` に変更を加えない
- タイマー状態の永続化・アプリ強制終了からの復元
- 実施中のカウントダウン読み上げ（VoiceOver の 1 秒ごとの割り込み）、音声ガイド
- Live Activity / Dynamic Island / ウィジェット / Apple Watch 連携
- サーバー・外部 API・アナリティクス送信（L1 制約）

## 機能仕様の詳細

### 1. 責務境界

| 相手 | 方向 | 受け渡すもの |
|---|---|---|
| stretch-catalog | 受け取る | `StretchItem.durationSeconds`（カウント秒数）、`StretchItem.id`（記録キー）、手順テキスト |
| stretch-card | 受け取る | `StretchCardView(item:style:.detail)`。実施中の手順表示に再利用する |
| gacha-draw | 受け取る | 結果カードのフッタースロット。ここに「はじめる」を置き、タイマー画面をモーダル表示する |
| practice-record | 渡す | 完了イベント（`itemID` と完了時刻）を `PracticeRecording` 経由で 1 回。未実装の間は何もしない既定実装で動く |
| stretch-collection | 参照しない | 図鑑からタイマーを起動しない（MVP では図鑑は閲覧のみ） |

依存の向きは **stretch-timer → stretch-catalog / stretch-card / `PracticeRecording`** の一方向。stretch-card・gacha-draw から stretch-timer を参照させない（`GachaView` がタイマー画面を提示する 1 箇所のみが例外で、そこは呼び出し側にあたる）。

### 2. 画面構成と L1 の 3 画面制約

タイマーは **ガチャ画面から `fullScreenCover` で提示するモーダル**とする。タブを増やさず、ナビゲーション階層も作らない。L1 の「画面はガチャ・図鑑・履歴の 3 つまで」は **常時アクセスできる画面の数**の制約であり、結果カードから 1 タップで開いて 1 タップで閉じるモーダルはこれに加算しない。ユーザーが覚える遷移は「はじめる → やる → 閉じる」の 1 本道のみ。

### 3. カウントダウンの仕様

#### 3.1 秒数の決定

```swift
// TimerEngine.swift — 副作用なし・純粋
enum TimerEngine {

    /// 実施秒数。カタログ規約（20...90）の外側でもクラッシュ・無限カウントを起こさない
    static func duration(for item: StretchItem) -> Int {
        min(max(item.durationSeconds, 1), 600)
    }

    /// 残り秒数（実数）。0 以下は 0 に丸める
    static func remaining(deadline: Double, now: Double) -> Double {
        max(0, deadline - now)
    }

    /// 画面に出す整数秒。切り上げ（ceil）で求める。
    /// 残り 59.0 秒ちょうどは 59、59.0 を超えていれば 60 と表示する（例: 59.4 → 60）
    static func displaySeconds(remaining: Double) -> Int {
        Int(remaining.rounded(.up))
    }

    /// 進捗（0.0 = 開始直後、1.0 = 完了）
    static func progress(remaining: Double, duration: Int) -> Double {
        guard duration > 0 else { return 1 }
        return min(max(1 - remaining / Double(duration), 0), 1)
    }

    static func isFinished(remaining: Double) -> Bool { remaining <= 0 }
}
```

`deadline` / `now` は **単調増加クロックの秒数**であり、壁時計（`Date`）ではない。端末の時刻変更・タイムゾーン変更でカウントが飛ばないようにするため。

```swift
// TimerClock.swift
protocol TimerClock {
    /// 任意の原点からの単調増加秒数
    func nowSeconds() -> Double
}

struct MonotonicTimerClock: TimerClock {   // 本番。ContinuousClock ベース
    func nowSeconds() -> Double
}

final class TestTimerClock: TimerClock {   // テスト専用。手動で進める
    func advance(by seconds: Double)
    func nowSeconds() -> Double
}
```

#### 3.2 表示規則

| 項目 | 規則 |
|---|---|
| 数字 | `displaySeconds(remaining:)` の整数を 64pt で表示。単位「秒」を 20pt で右に併記 |
| 開始時 | 60 秒の種目なら「60 秒」から始まる（`ceil(60.0) == 60`） |
| 進捗バー | 画面幅いっぱい・高さ 6pt・角丸。`progress` に比例して左から伸びる |
| 完了時 | 数字は「0 秒」を経て完了表示に切り替わる |
| 分表記 | **使わない**。カタログ規約上限は 90 秒であり、秒のみの整数表示で全域を覆える（`DurationLabel` は総時間の表示用であって、カウントダウンには使わない） |

#### 3.3 左右のある種目の扱い（q1 の運用ルール）

タイマーは中間合図を出さないため、切り替え点は手順テキストに **残り秒数基準**で書く。「前半 30 秒」ではなく「残り 30 秒になったら」と書くのは、画面の数字と直接照合できるようにするため。

対象は前後半で対象が切り替わる **13 件**（同梱 26 件のうち）。

| # | id | 秒 | 切り替え |
|---|---|---|---|
| 1 | neck-02 | 60 | 左右 |
| 2 | neck-05 | 60 | 左右 |
| 3 | shoulder-02 | 40 | 前まわし / 後ろまわし |
| 4 | shoulder-03 | 60 | 左右 |
| 5 | shoulder-04 | 60 | 左右 |
| 6 | shoulder-05 | 60 | 上下の持ち替え |
| 7 | lowback-02 | 60 | 左右 |
| 8 | lowback-03 | 60 | 左右 |
| 9 | upperback-04 | 60 | 左右 |
| 10 | legs-01 | 60 | 左右 |
| 11 | legs-02 | 60 | 左右 |
| 12 | legs-03 | 60 | 左右 |
| 13 | eyeswrist-01 | 60 | 手のひら側 / 甲側 |

`neck-03`（首まわし・40 秒）は左右方向の連続動作で秒数指定の切り替え点を持たないため対象外。`shoulder-01` / `eyeswrist-02` 等の反復系も対象外。

書き換え例（`neck-02` / 60 秒）:

```json
"steps": [
  "背すじを伸ばして座る",
  "右手を頭の左側に添える",
  "右にゆっくり倒してキープ",
  "残り30秒になったら反対側へ"
]
```

- 変更するのは `steps` の文言のみ。`id` / `durationSeconds` / `rarity` / `bodyPart` / `emoji` / `kind` は変更しない（`id` は practice-record の安定キーであり変更禁止）。
- 変更後も `CatalogValidator` の規約（`steps` 2〜6 要素・各要素 1〜60 文字・禁止語なし）を満たすこと。上の例は 4 要素・最長 13 文字で規約内。
- 残り秒数は `durationSeconds` の **ちょうど半分**を基準にする（60 秒 → 残り 30 秒、40 秒 → 残り 20 秒）。13 件はすべて偶数秒のため端数は生じない。

将来 `segments` フィールドでの厳密なセグメント分割を導入する場合は、カタログのスキーマ拡張 → `TimerEngine` の分割対応 → 手順テキストの再修正の順になる。MVP ではその足場だけをコメントで残す。

### 4. 状態機械

```swift
enum TimerPhase: Equatable {
    case running        // カウントダウン中
    case paused         // バックグラウンド等で一時停止中
    case finished       // 0 秒に到達（完了表示）
}

@Observable
@MainActor
final class StretchTimerViewModel {

    let item: StretchItem
    private(set) var phase: TimerPhase = .running
    private(set) var remaining: Double        // 残り秒数（実数）
    var displaySeconds: Int { TimerEngine.displaySeconds(remaining: remaining) }
    var progress: Double { TimerEngine.progress(remaining: remaining, duration: duration) }

    init(item: StretchItem,
         clock: TimerClock = MonotonicTimerClock(),
         feedback: CompletionFeedback = HapticCompletionFeedback(),
         recorder: PracticeRecording = NoopPracticeRecorder(),
         now: @escaping () -> Date = Date.init,
         // 自動ロック抑止のセッタ。テストからスパイに差し替えて ON / OFF の状態を検証する
         setIdleTimerDisabled: @escaping (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 })

    func tick()                 // 0.1 秒ごとにビューから呼ばれる
    func pause()                // scenePhase != .active
    func resume()               // scenePhase == .active
    func abort()                // 「やめる」タップ。記録しない
    func onDisappear()          // 自動ロック抑止を必ず解除する合流点
}
```

**遷移表**

| 現在 | イベント | 次 | 副作用 |
|---|---|---|---|
| （生成） | `init` | running | `deadline = clock.now + duration`、自動ロック抑止 ON |
| running | `tick()` かつ 残り > 0 | running | `remaining` 更新のみ |
| running | `tick()` かつ 残り ≤ 0 | finished | ハプティクス 1 回・記録ポート 1 回・自動ロック抑止 OFF |
| running | `pause()` | paused | 残り秒を確定して保持、tick 停止、自動ロック抑止 OFF |
| running | `resume()` | running | 無視（`deadline` を引き直さず、`remaining` も変えない） |
| paused | `resume()` | running | `deadline = clock.now + 保持していた残り秒`、tick 再開、自動ロック抑止 ON |
| paused | `tick()` | paused | 無視（`remaining` を変えない） |
| running / paused | `abort()` | （画面を閉じる） | 記録しない・ハプティクスなし・自動ロック抑止 OFF |
| finished | `tick()` / `pause()` / `resume()` | finished | 無視。ハプティクスと記録は再発火しない |

**再入防止**: `finished` への遷移時のハプティクスと記録は、`phase` が `finished` でないことを条件に 1 回だけ実行する。`tick()` が連続で呼ばれても 2 回発火しない。

**一時停止で残り秒を確定して保持する**理由: `deadline` を保持したままにすると、バックグラウンド滞在時間の分だけ復帰時に残りが減る。残り秒を保持し、復帰時に `deadline` を引き直すことで、滞在時間に関係なく残り秒が保存される（誤差 0）。

### 5. 画面仕様

#### 5.1 タイマー画面（`StretchTimerView`）

上から順に。

| # | 要素 | 内容 |
|---|---|---|
| 1 | 残り秒数 | 中央寄せ。数字 64pt bold（等幅数字 `.monospacedDigit`）+ 「秒」20pt |
| 2 | 進捗バー | 幅いっぱい・高さ 6pt・角丸 3pt。トラック `Color(.tertiarySystemFill)`、塗り `RarityStyle.accent(for: item.rarity)` |
| 3 | カード | `StretchCardView(item: item, style: .detail)`（フッターなし）。手順・注意がここに出る |
| 4 | フッター | 「やめる」。幅いっぱい・高さ 56pt・角丸。枠線のみの副次スタイル（塗りつぶさない） |

- ヘッダ・タイトルバー・閉じる × ボタンを置かない。操作対象は「やめる」1 つだけ。
- 進捗バーの色を `RarityStyle.accent(for:)` から取ることで、レア度の色定義を 1 箇所に保つ（stretch-card の方針に追随）。
- `finished` 状態では 1 と 2 が「✅ 完了！」（32pt）に置き換わり、フッターが「閉じる」（塗りつぶしの主ボタン）に変わる。カードはそのまま残る。
- 完了表示への切り替えにアニメーションを付けない（即時差し替え）。`.animation` / `withAnimation` をビューに書かない。

#### 5.2 レイアウトメトリクス（設計基準: iPhone SE 第 2/3 世代 375×667・縦画面固定）

セーフエリア高 647pt（ステータスバー 20pt を除く）で予算を組む。

| 区間 | 高さ |
|---|---|
| 画面上余白 | 16 |
| 残り秒数ブロック（数字 64pt・行高 76 + 余白 6 + バー 6） | 88 |
| バー〜カード間 | 16 |
| カード（`.detail`） | 最大 439 |
| カード〜フッター間 | 16 |
| フッターボタン | 56 |
| 画面下余白 | 16 |
| 合計 | **647** |

検算: 16 + 88 + 16 + 439 + 16 + 56 + 16 = **647** ✓（セーフエリア高と一致）

**カード内の固定部（`.detail`・種目名 2 行の最悪ケース）** — stretch-card §4.3 の `.detail` メトリクスによる

| 要素 | 高さ |
|---|---|
| カード上下パディング（20 × 2） | 40 |
| ヘッダ行（レア度バッジ / 部位チップ） | 24 |
| 余白 | 12 |
| 絵文字（40pt フォント） | 48 |
| 余白 | 8 |
| 種目名（20pt × 最大 2 行、行高 26） | 52 |
| 余白 | 6 |
| 実施時間 | 20 |
| 余白 | 14 |
| 区切り線 | 1 |
| 余白 | 14 |
| 固定部 合計 | **239** |

検算: 40+24+12+48+8+52+6+20+14+1+14 = **239** ✓
→ 手順スクロール領域 = 439 − 239 = **200pt**（種目名が 1 行なら固定部 213pt、手順領域 226pt）

**手順の収容**（stretch-card §4.3 と同じ計算式: 手順 n 件・各 k 行で `24nk + 10(n−1)`、テキスト幅 263pt ＝ 本文 17pt で 1 行約 15 文字）

| ケース | 高さ | 200pt に対して |
|---|---|---|
| 4 手順 × 1 行（同梱データの典型） | 24×4 + 10×3 = **126** | 収まる |
| 5 手順 × 1 行 | 24×5 + 10×4 = **160** | 収まる |
| 6 手順 × 1 行 | 24×6 + 10×5 = **194** | 収まる |
| 4 手順 × 2 行 | 24×8 + 10×3 = **222** | スクロール |
| 6 手順 × 4 行（カタログ規約の最大） | 24×24 + 10×5 = **626** | スクロール |

§3.3 の書き換え後も手順の各行は 15 文字前後（最長 13 文字の例で 1 行）に収まるため、同梱データでは **手順が全件スクロールなしで可視**になる。規約上限のケースでも、残り秒数・進捗バー・「やめる」は常時可視のまま手順だけがスクロールする。

**カードの実施時間チップ（総時間）とカウントダウン（残り時間）が同一画面に並ぶ**点は許容する。`Card/` に 3 つ目のスタイルを足して要素を隠すより、カードを無変更で再利用する方が保守性（L1 3 位）に沿うため。両者は数字の大きさ（64pt 対 15pt）と位置で区別できる。

#### 5.3 ガチャ結果画面のフッター変更

stretch-card のフッタースロットに 2 ボタンを横並びで置く。フッターの高さは **56pt のまま**変えないため、stretch-card が確保したカード最大 543pt・手順領域 278pt の予算は変わらない。

| 要素 | 幅 | スタイル |
|---|---|---|
| 「はじめる」 | 195pt | 塗りつぶし（主） |
| 間隔 | 12pt | — |
| 「もう 1 回」 | 128pt | 枠線のみ（副） |

検算: 195 + 12 + 128 = **335pt** ＝ カード幅（375 − 20×2）✓
どちらも高さ 56pt で、最小タップ領域 44×44pt を満たす。

#### 5.4 更新頻度と描画

- ティック間隔は **0.1 秒**（10Hz）。`Timer.publish(every: 0.1, on: .main, in: .common)` を `onReceive` で受け、`viewModel.tick()` を呼ぶ。
- ティックは「再計算の契機」でしかなく、残り時間は毎回 `deadline − clock.nowSeconds()` から算出する。ティックの取りこぼしや遅延が累積しない。
- `paused` / `finished` の間は publisher を止める（`autoconnect` せず、状態に応じて接続・切断する）。バッテリーと CPU を無駄に使わない。
- 最大 90 秒の種目でティックは **900 回**。1 回の処理は減算と 2 つの整数化のみ（O(1)）。
- `TimelineView` / `Canvas` / `CADisplayLink` を使わない。進捗バーは `GeometryReader` + `RoundedRectangle` の幅指定のみで描く。
- 進捗バーにアニメーション修飾を付けない（10Hz の離散更新で十分滑らかに見える）。この結果、**Reduce Motion への個別対応が不要**になる。

#### 5.5 バックグラウンド・自動ロック

| 事象 | 挙動 |
|---|---|
| `scenePhase` が `.active` 以外（`.inactive` / `.background`）になる | `pause()`。コントロールセンターの引き下げなど一過性の遷移でも止める（止まりすぎる方が安全側） |
| `scenePhase` が `.active` に戻る | `resume()`。残り秒から自動的に再開する。確認ダイアログ・カウントインを挟まない（q3 回答） |
| `running` の間 | `UIApplication.shared.isIdleTimerDisabled = true` |
| `paused` / `finished` / 画面離脱 | `isIdleTimerDisabled = false` |
| 画面の `onDisappear` | 状態にかかわらず `isIdleTimerDisabled = false` を実行する（解除漏れをここで必ず回収する） |

自動ロック抑止の解除漏れは電池を減らし続ける不具合になるため、「設定する箇所は複数・解除する最終合流点は `onDisappear` 1 箇所」という構造にする。

#### 5.6 完了フィードバック（q2 の決定）

```swift
// CompletionFeedback.swift
protocol CompletionFeedback {
    func notifySuccess()
}

struct HapticCompletionFeedback: CompletionFeedback {
    func notifySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
```

- 完了時に **1 回だけ** 発火する。中断時・一時停止時・再開時には発火しない。
- 音は鳴らさない。`AVFoundation` / `AudioToolbox` を import せず、音源アセットを追加しない（gacha-draw の「フィードバックはハプティクスのみ」を維持）。
- プロトコルにしているのは、テストから発火回数を数えられるようにするため。

#### 5.7 アクセシビリティ

- 残り秒数と進捗バーを `accessibilityElement(children: .ignore)` で 1 要素にまとめ、ラベル「残り時間」、値を「45 秒」の形で提供する。
- **`accessibilityValue` の更新は 10 秒刻みに間引く**（残り 60 / 50 / 40 / 30 / 20 / 10 / 0 秒）。1 秒ごとに更新すると VoiceOver が読み上げを繰り返し、手順の読み上げを妨げるため。
- 進捗バー自体は装飾として `.accessibilityHidden(true)`。
- カード内の読み上げは stretch-card §4.7 の規則をそのまま使う（本機能で追加・変更しない）。
- 「やめる」「閉じる」は標準の `Button` で、ラベルがそのまま読まれる。
- 完了表示「✅ 完了！」は `accessibilityLabel("完了")` とし、絵文字を読み上げさせない。

### 6. データモデル（永続化）

**なし。** 本機能は SwiftData のモデルを 1 つも定義せず、`ModelContext` を参照せず、`SwiftData` を import しない。

- タイマーの状態（残り秒・フェーズ）はビューモデルのメモリ上にのみ存在する。
- 実施中にアプリが強制終了された場合、そのセッションは失われる。復元処理を設けない（L1 妥協特性「運用性」）。中断扱いとなり記録もされないため、データの不整合は発生しない。
- 完了イベントの永続化は practice-record の責務であり、本機能はポートを呼ぶだけ。

```swift
// PracticeRecording.swift
protocol PracticeRecording {
    /// 実施完了を記録する。中断時には呼ばれない
    func recordCompletion(itemID: String, completedAt: Date)
}

/// practice-record 実装までの既定実装。何もしない
struct NoopPracticeRecorder: PracticeRecording {
    func recordCompletion(itemID: String, completedAt: Date) {}
}
```

practice-record 実装時は `StretchTimerViewModel` の初期化引数に実装を差し込むだけでよく、`Timer/` 配下のロジック変更は発生しない。

### 7. 処理フロー

```
[ガチャ結果カードのフッター「はじめる」タップ]
   └─ GachaView: timerItem = item  →  .fullScreenCover で StretchTimerView 提示
   ▼
[StretchTimerView 表示 / ViewModel init]
   ├─ duration = TimerEngine.duration(for: item)      ← 1...600 にクランプ
   ├─ deadline = clock.nowSeconds() + Double(duration)
   ├─ phase = .running
   ├─ isIdleTimerDisabled = true
   └─ 0.1 秒ティックを開始
   ▼
[0.1 秒ごと] tick()
   ├─ remaining = max(0, deadline − clock.nowSeconds())
   ├─ 残り > 0 → 表示更新のみ（I/O なし）
   └─ 残り ≤ 0 → ↓
   ▼
[finished]
   ├─ ティック停止
   ├─ isIdleTimerDisabled = false
   ├─ feedback.notifySuccess()                        ← 1 回だけ
   ├─ recorder.recordCompletion(itemID:completedAt:)  ← 1 回だけ
   └─ 完了表示 + フッター「閉じる」
   ▼
[「閉じる」] → モーダルを閉じてガチャ結果画面へ戻る（カードはそのまま）

--- 割り込み経路 ---
[scenePhase ≠ .active] → pause(): 残り秒を確定保持・ティック停止・抑止 OFF
[scenePhase = .active] → resume(): deadline を引き直してティック再開・抑止 ON
[「やめる」タップ]     → abort(): 記録なし・ハプティクスなし・抑止 OFF・即モーダルを閉じる
[onDisappear]          → isIdleTimerDisabled = false（最終合流点）
```

**カウントダウン中に I/O・非同期処理・レイアウト再計算を発生させない**ことを設計上の固定点とする。ティックが触るのは 3 つの数値（`remaining` / `displaySeconds` / `progress`）だけで、カードは `item` が不変のため再構築されない。

### 8. 1 セッション 3 分以内の検算

L1 の「1 回の利用は 3 分以内で完結」に対する最悪ケース（コールドスタート・SR/UR の最長演出・スキップなし・カタログ最大秒数 90）。

| 区間 | 秒 | 出典 |
|---|---|---|
| T1: プロセス起動 → ガチャ画面が操作可能 | 1.00 | gacha-draw 非機能要件 |
| T2: 「回す」タップ → 結果カード表示 | 1.81 | gacha-draw（抽選 0.01 + 演出 1.80） |
| カード読了 → 「はじめる」タップ | 20.00 | gacha-draw の 60 秒内訳の割り当て |
| 実施（カタログ規約の最大秒数） | 90.00 | カタログ規約 `durationSeconds ≤ 90` |
| 完了確認 → 「閉じる」 | 5.00 | 本書の設計値 |
| 合計 | **117.81** | |

検算: 1.00 + 1.81 + 20.00 + 90.00 + 5.00 = **117.81 秒**（1 分 58 秒）。180 秒に対し **62.19 秒の余裕** ✓
同梱データの最大秒数 60 で計算すると 87.81 秒。

## 非機能要件

| 項目 | 値 | 根拠・備考 |
|---|---|---|
| 1 セッション所要時間 | **180 秒以内**（規約最大 90 秒の種目・最悪経路で 117.81 秒） | L1「1 回の利用は 3 分以内」。§8 の検算 |
| カウントダウンのティック間隔 | **0.1 秒**（10Hz） | 90 秒の種目で最大 900 ティック |
| 1 ティックあたりの処理 | O(1)。実機設計目標 **50µs 未満** | 減算 1 回 + 整数化 2 回。I/O・確保なし |
| 　同上・テストのアサート閾値 | `TimerEngine` の残り時間・進捗計算 **100,000 回が 2 秒以内**（1 回 20µs 相当の上限） | シミュレータ / CI の実行環境差を吸収する余裕を持った上限 |
| 論理時間の計測精度 | 注入クロックで **誤差 0**（`deadline − now` の実数演算のみ） | テストは厳密値でアサートできる |
| 実機での計測誤差 | 60 秒の実施あたり **±1.0 秒以内** | 単調クロック基準。手動計測で確認。ティック遅延が累積しない構造 |
| バックグラウンド復帰時の残り秒の誤差 | **0 秒**（滞在時間に依存しない） | 一時停止時に残り秒を確定保持する（§4） |
| フレームレート | カウントダウン中 60fps 維持 | 描画対象は数字 1 つと矩形 1 つ。測定は Instruments で目視（運用性は妥協特性） |
| 「はじめる」タップからカウント開始までの追加待ち時間 | **0 秒**（I/O・非同期・デコードなし） | 画面遷移アニメーションは OS 標準の `fullScreenCover` に委ねる |
| SwiftData クエリ本数 | **0 本**（`SwiftData` を import しない） | タイマーは永続化層に触れない |
| ディスク読み書き回数 | **0 回** | |
| ネットワークリクエスト数 | **0 件** | L1 制約: サーバー・外部 API 禁止 |
| 通知権限の要求回数 | **0 回**（`UserNotifications` を import しない） | q3 回答 (a) |
| 完了ハプティクスの発火回数 | 完了 1 回につき **ちょうど 1 回**。中断時は **0 回** | q2 回答 |
| 追加アセット数 | **0 個**（画像・音源・カラーセット・フォントを追加しない） | 音を鳴らさないため音源も持たない |
| メモリ増分 | 1MB 未満（保持するのは `StretchItem` 1 件と数値 3 つ） | |
| 自動ロック抑止の適用範囲 | `running` の間のみ true。画面離脱後は必ず false | 電池消費を実施中に限定する |
| タイマー画面の手順スクロール領域（設計基準機） | **200pt 以上**（種目名 2 行時）／ 226pt（1 行時） | §5.2 の検算 |
| 常時可視を保証する要素 | 残り秒数・進捗バー・レア度バッジ・部位チップ・種目名・「やめる」 | 手順のみスクロールする |
| ガチャ結果画面のフッター高さ | **56pt を維持**（2 ボタン横並び 195 + 12 + 128 = 335pt） | stretch-card のカード 543pt・手順領域 278pt の予算を変えない |
| 対応最小画面 | 375×667pt（iPhone SE 第 2/3 世代）・縦画面固定 | L1: iPhone のみ・縦固定 |
| カタログ側の変更範囲 | `steps` の文言のみ **13 件**。スキーマ・`id`・`durationSeconds` は変更 0 件 | §3.3 |
| 種目追加時に本機能で変更するファイル数 | **0 ファイル** | 秒数・件数をコードに焼き込まない。テストで実証する |
| 想定同時ユーザー数 | 1（自分のみ） | L1 妥協特性: スケーラビリティ |
| 実装完了時期 | MVP（2 週間）内 ※**L1 の仮置き値に基づく** | L1「期限・マイルストーン」が【仮置き】 |

## 非機能優先順位との対応

### 1 位: 学習容易性（説明書なしで初回起動 60 秒以内に最初のガチャ → 実施開始）

- **60 秒の内訳に収める**: 注意書きの確認 約 10 秒 + ガチャ画面の認識 約 5 秒 + 演出 最大 1.8 秒 + 結果カードの読了 約 20 秒 + 「はじめる」タップ 1 秒 ≒ **37.8 秒**で実施開始に到達する（検算: 10 + 5 + 1.8 + 20 + 1 = 37.8 ✓、60 秒に対し 22.2 秒の余裕）。タイマー側で説明画面・準備画面・カウントインを挟まないことが要件。
- **操作対象を 1 つに絞る**: タイマー画面のボタンは「やめる」だけ。一時停止・スキップ・延長・秒数変更を置かない。バックグラウンド時の一時停止は自動で行い、ユーザーに操作を覚えさせない。
- **数字を 1 つだけ大きく出す**: 残り秒数を 64pt で中央に置き、進捗バーで残量を補助的に示す。分秒表記・経過時間・セット数など、読み解きの必要な表示を増やさない。
- **切り替え合図を画面の数字と一致させる**: 手順テキストを「残り 30 秒になったら反対側へ」と残り秒数基準で書くことで、ユーザーは画面の数字と手順を突き合わせるだけでよい（「前半」「後半」のような換算を挟ませない）。
- **失敗状態を作らない**: エラーダイアログ・権限要求ダイアログ・リトライ導線を持たない。通知権限を求めないのは、許可ダイアログが 60 秒の予算を直接削るため。
- **中断に確認を挟まない**: 「やめる」1 タップで即座に抜ける。確認ダイアログは操作を 1 段増やし、L1 の「1 タップで抜けられる」に反する。

### 2 位: パフォーマンス（コールドスタート → 結果 3 秒以内、60fps）

- **gacha-draw の時間予算に 0 秒を追加する**: タイマーはカード表示後の操作から始まるため、「コールドスタート → 結果カード表示 3.0 秒」の経路に一切登場しない。`GachaView` への変更もフッターのボタン構成とモーダル提示のみで、演出経路・抽選経路に手を入れない。
- **カウントダウン中に I/O と非同期を発生させない**: `SwiftData` / `URLSession` / `Task.sleep` を使わない。ティックが触るのは数値 3 つのみ。
- **ティック遅延を累積させない**: 残りは毎回クロックから再計算するため、`remaining -= 0.1` の積み上げによるドリフトが構造的に起きない。
- **重い描画機能を使わない**: `TimelineView` / `Canvas` / `blur` / `shadow` を使わない。進捗バーは矩形の幅指定のみ。数字は `.monospacedDigit` で桁変動によるレイアウト再計算を防ぐ。
- **不要なティックを止める**: 一時停止中・完了後は publisher を切断する。60 秒の種目で 600 ティック、90 秒でも 900 ティックに収まる。
- **カードを再構築させない**: `item` は不変で、残り時間の変化はカードのビュー階層に伝播しない。

### 3 位: 保守性（週末開発でも壊さず拡張できる）

- **計算を純粋関数に隔離する**: `TimerEngine` は SwiftUI・SwiftData・システム時刻・乱数に依存せず、引数だけで結果が決まる。残り時間・表示秒・進捗・完了判定の検証がユニットテストで完結する。
- **時間をテストで支配する**: クロックを `TimerClock` として注入し、`TestTimerClock.advance(by:)` で論理時間を進める。壁時計時間を待つテストを 1 つも書かない。
- **副作用をポートに切り出す**: ハプティクス（`CompletionFeedback`）と記録（`PracticeRecording`）をプロトコル化し、発火回数をテストで数えられるようにする。practice-record 実装時の差し込み口も同じ場所になる。
- **定数を 1 箇所に集約する**: ティック間隔・レイアウトの余白・フォントサイズ・クランプ上下限を `TimerMetrics` にまとめ、ビューにマジックナンバーを書かない。レア度色は `RarityStyle` を参照し、再定義しない。
- **他機能のコードを触らない**: `Card/` は 0 ファイル変更、`Gacha/` は `GachaView` 1 ファイルのみ。カタログは `steps` の文言だけを変更し、スキーマ・Swift コードには触れない。
- **テストは範囲・上限でアサートする**: 性能は「100,000 回 2 秒以内」、実機誤差は「60 秒あたり ±1.0 秒」という余裕を持った上限で書く。「ティックが正確に 0.1 秒間隔」「実測 59.98 秒」のような環境差で揺れる厳密値はアサートしない。一方、注入クロックでの残り秒・表示秒・進捗のように経路差で揺れない値は厳密にアサートする。
- **セグメント分割の足場を残す**: 将来 `segments` を導入する場合の変更範囲（カタログのスキーマ → `TimerEngine` → 手順テキスト）をコメントに明記し、MVP では実装しない。

### 妥協特性で簡略化すること

| 妥協特性 | 本機能で作らないもの |
|---|---|
| スケーラビリティ | タイマーは同時に 1 本しか動かない前提で書く。複数タイマーの管理、キュー、バックグラウンド実行基盤、連続実施モードを持たない。ティックは素朴な `Timer.publish` で通し、高精度スケジューラや `DispatchSourceTimer` の調整を入れない |
| 互換性・相互運用性 | HealthKit へのワークアウト記録、Live Activity、Apple Watch、ショートカット連携、実施時間のエクスポートを持たない。タイマーの状態は他アプリ・他デバイスへ一切共有しない |
| 運用性 | 実測誤差の計測基盤、ティック遅延のログ、タイマー動作のアナリティクス、クラッシュレポート、デバッグ用の秒数早送り機能を持たない。中断・強制終了からの状態復元も行わない。不具合は自分が使って気づいたら直す |

## セキュリティ

本機能は完全ローカル・単一ユーザーで、ネットワーク・永続化・テキスト入力のいずれも扱わない。攻撃面は「`StretchItem.durationSeconds` をどう解釈するか」と「OS 権限の要求範囲」に限定される。

### 認証・認可

- **不要（実装しない）**。アカウント・ログインを持たない単一端末・単一ユーザー構成（L1 のスコープ外事項）。タイマーに権限による出し分けは存在しない。
- **OS 権限を 1 つも要求しない**: 通知（`UNUserNotificationCenter.requestAuthorization`）・マイク・カメラ・位置情報・HealthKit のいずれの権限ダイアログも出さない。使用するのは権限不要な `isIdleTimerDisabled` とハプティクスのみ。要求しない権限は Info.plist の使用目的文字列も追加しない。
- **書き換え経路を作らない**: `StretchTimerView` / `StretchTimerViewModel` は `StretchItem` を `let` で受け取り、保持も変更もしない。カタログへ書き戻す API を公開しない。

### 入力検証

- ユーザー入力はボタンタップのみ。テキスト入力・数値入力・URL スキーム / ユニバーサルリンクの受け口を持たない。
- **`durationSeconds` を「信頼しない入力」として扱う**: `TimerEngine.duration(for:)` で **1 秒以上 600 秒以下**にクランプする。0 や負値でも即座に完了扱いにならず 1 秒として動き、異常に大きな値でも 600 秒で頭打ちになる。無限カウント・ゼロ除算（`progress` の `duration > 0` ガード）・自動ロック抑止の無期限継続が構造上発生しない。
- **状態機械で再入を防ぐ**: `finished` 到達後の `tick()` / `pause()` / `resume()` を無視し、ハプティクスと記録が 2 回以上発火しないようにする。「やめる」の連打でもモーダルを閉じる処理が二重に走らない。
- 手順・注意・種目名の描画は stretch-card に委譲するため、`Text(verbatim:)` による書式解釈の抑止はそちらの担保がそのまま効く。タイマー側で `StretchItem` の文字列を独自に描画しない。

### データ保護

- **何も保存しない**: SwiftData・UserDefaults・ファイル・キーチェーンのいずれにも書き込まない。残り秒数はプロセスのメモリ上にのみ存在し、画面を閉じれば消える。
- 記録ポートへ渡すのは `item.id`（例 `"neck-02"`）と完了時刻のみ。実施中の詳細（中断位置・一時停止回数・所要時間）を渡さない。個人情報・端末識別子・位置情報・利用統計を扱わない。App Privacy「データ収集なし」申告（appstore-release-prep）と矛盾しない状態を維持する。
- **ネットワークを使わない**: `URLSession` / `Network` / `CFNetwork` を import しない。App Transport Security 設定を緩めない。
- **ログ出力を残さない**: `Timer/` 配下に `print` / `os_log` / `debugPrint` を書かない。実施内容を外部へ送らない。
- 実施中の画面に秘匿情報が無いため、スクリーンショット・画面録画の制限は設けない。

### 端末リソースの保護

- **自動ロック抑止を最小範囲に限定する**: `running` の間だけ `isIdleTimerDisabled = true` にし、一時停止・完了・中断・画面離脱のすべてで false に戻す。最終的な解除は `onDisappear` の 1 箇所に集約し、どの経路で画面を抜けても必ず通るようにする。解除漏れによる電池の持続的な消耗を構造的に防ぐ。
- タイマーの publisher を `paused` / `finished` で停止し、バックグラウンドで CPU を使い続けない。バックグラウンド実行モード（`UIBackgroundModes`）を Info.plist に追加しない。

### 依存関係

- 外部ライブラリ 0。`SwiftUI` / `Foundation` / `UIKit`（`UIApplication.isIdleTimerDisabled` と `UINotificationFeedbackGenerator` のみ）で完結する（L1 制約: 外部ライブラリ原則ゼロ）。

### コンテンツ安全性（法務制約の技術的担保）

- タイマー画面に固定の日本語文言を追加しない。画面に出る文字は残り秒数・「秒」・「やめる」・「完了！」・「閉じる」と `StretchItem` 由来のテキストのみ。医学的効能・専門家監修を示唆する文言を書かない。
- §3.3 のカタログ手順テキスト更新でも、追加するのは切り替えタイミングの指示（「残り 30 秒になったら反対側へ」）のみで、効能・強度・回数の推奨を書かない。更新後も `CatalogValidator` の禁止語チェック（治る・治療・効能・医学・監修・診断・処方）を通す。
- 全体向けの注意書き（「痛みが出たら中止する・無理をしない」）は safety-notice の責務であり、タイマー画面に重複して置かない。「やめる」がいつでも押せることが、無理をしないための導線として機能する。

## 実装方針

### 使用技術

- Swift 5.9+ / SwiftUI（iOS 17 以上）、`@Observable` マクロによる状態管理
- 時間計測は `ContinuousClock`（単調増加）。`Date` は完了時刻の記録にのみ使う
- ティックは `Timer.publish(every:on:in:)` + `onReceive`
- `UIKit` は `UIApplication.isIdleTimerDisabled` と `UINotificationFeedbackGenerator` にのみ使用
- **SwiftData は使わない**（import しない）
- テストは XCTest（標準）

### 既存実装との整合

- **stretch-catalog（status: issued_local）**: `StretchItem` / `Rarity` を読み取り専用で利用する。**Swift コードとスキーマは変更しない**。`StretchCatalog.json` は §3.3 の 13 件の `steps` 文言のみ更新し、`id` / `durationSeconds` / その他フィールドには触れない。更新後に `CatalogValidator` が違反 0 件を返すことをテストで確認する。
- **stretch-card（status: issued_local）**: `StretchCardView(item:style:.detail)` をそのまま使う。**`Card/` 配下は 1 ファイルも変更しない**。タイマー用の 3 つ目のスタイルや専用イニシャライザを追加しない。進捗バーの色は `RarityStyle.accent(for:)` を参照し、レア度色を再定義しない。
- **gacha-draw（status: issued_local）**: 変更するのは `GachaView` の結果カードのフッター（「はじめる」/「もう 1 回」の 2 ボタン化）と `fullScreenCover` の追加のみ。`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` / `SeededRandomGenerator` には一切変更を加えない。フッター高さを 56pt に据え置くことで、stretch-card のレイアウト予算（カード 543pt・手順領域 278pt）を維持する。
- **practice-record（未着手）**: 完了イベントの受け口を `PracticeRecording` プロトコルとして本機能側で切り出し、既定は `NoopPracticeRecorder` とする。本機能単体でビルド・テスト・実機動作が成立する状態を成果物とする。practice-record 実装時は `StretchTimerViewModel` の初期化引数を差し替えるだけでよい。
- **stretch-collection（未着手）**: 図鑑からのタイマー起動は作らない。`StretchTimerView` は `StretchItem` を受け取るだけなので、将来図鑑から呼びたくなっても本機能のコード変更は不要。
- **safety-notice（未着手）**: 相互作用なし。全体注意書きをタイマー画面に載せない。
- Xcode プロジェクト（`stretch-gacha/`）は stretch-catalog / gacha-draw / stretch-card の実装時に作成済みの想定。

### 変更対象ファイル

```
stretch-gacha/
├── StretchGacha/
│   ├── Timer/
│   │   ├── TimerEngine.swift              [新規] duration / remaining / displaySeconds / progress / isFinished
│   │   ├── TimerClock.swift               [新規] TimerClock + MonotonicTimerClock
│   │   ├── TimerMetrics.swift             [新規] ティック間隔・秒数クランプ・レイアウト定数
│   │   ├── CompletionFeedback.swift       [新規] ポート + HapticCompletionFeedback
│   │   ├── PracticeRecording.swift        [新規] ポート + NoopPracticeRecorder
│   │   ├── StretchTimerViewModel.swift    [新規] @Observable 状態機械
│   │   └── StretchTimerView.swift         [新規] 残り秒数 + 進捗バー + カード + やめる/閉じる
│   ├── Gacha/
│   │   └── GachaView.swift                [変更] フッターを 2 ボタン化し fullScreenCover でタイマーを提示
│   └── Resources/
│       └── StretchCatalog.json            [変更] §3.3 の 13 件の steps 文言のみ
└── StretchGachaTests/
    └── StretchTimerTests.swift            [新規] 計算・状態遷移・境界値・副作用回数・性能
```

### 実装手順

1. **`TimerClock.swift`**: `TimerClock` プロトコルと `MonotonicTimerClock`（`ContinuousClock` の経過秒を `Double` で返す）を実装。テスト用 `TestTimerClock` は **テストターゲット側**に置き、アプリターゲットへ手動で時間を進める経路を残さない。
2. **`TimerEngine.swift`**: §3.1 の 5 関数を実装。それぞれ独立した純粋関数にし、クランプ・`ceil`・進捗のクリップ・ゼロ除算ガードを個別にテストできる形にする。`segments` による将来のセグメント分割は、この型に手順ごとの区間を渡す形で拡張できる旨をコメントに残す。
3. **`TimerMetrics.swift`**: ティック間隔 0.1 秒、秒数クランプ 1...600、`accessibilityValue` の更新刻み 10 秒、§5.2 のレイアウト値（数字 64pt / バー 6pt / 余白 16pt / フッター 56pt）を定数化する。ビューにマジックナンバーを書かない。
4. **`CompletionFeedback.swift` / `PracticeRecording.swift`**: ポート 2 つと既定実装（ハプティクス発火 / 何もしない）を実装。テストからは呼び出し回数を数えるスパイを差し込む。
5. **`StretchTimerViewModel.swift`**: §4 の遷移表どおりに `tick()` / `pause()` / `resume()` / `abort()` / `onDisappear()` を実装。`finished` への遷移時にハプティクスと記録を 1 回だけ実行する再入ガードを入れる。自動ロック抑止の ON / OFF もここに集約し、`onDisappear()` で無条件に OFF にする。抑止の実行は `init` の `setIdleTimerDisabled` クロージャ経由に統一し、テストからスパイへ差し替えられるようにする。
6. **`StretchTimerView.swift`**: §5.1 の 4 要素を上から実装。ティックは `Timer.publish` を `phase` に応じて接続・切断する。`scenePhase` を `@Environment` で監視し、`.active` 以外で `pause()`、`.active` で `resume()` を呼ぶ。`.animation` / `withAnimation` / `TimelineView` / `Canvas` を書かない。§5.7 のアクセシビリティ修飾を付ける。
7. **`GachaView.swift` の変更**: 結果カードのフッターを `HStack(spacing: 12)` の 2 ボタン（「はじめる」195pt / 「もう 1 回」128pt、高さ 56pt）に置き換える。`@State private var timerItem: StretchItem?` を持ち、`.fullScreenCover(item: $timerItem) { StretchTimerView(item: $0) }` を付ける。演出・抽選・カードの描画には触れない。
8. **`StretchCatalog.json` の文言更新**: §3.3 の 13 件について、切り替えを指示する手順を「残り〇秒になったら…」の形に書き換える。切り替え秒数は `durationSeconds / 2`。各要素 60 文字以内・手順 2〜6 要素・禁止語なしを維持する。`CatalogValidator` が違反 0 件を返すことを既存の `CatalogTests` で確認する。
9. **`StretchTimerTests.swift`**: 「受け入れ条件」の各項目に 1:1 対応するテストを実装。時間は `TestTimerClock.advance(by:)` で進め、実時間を待つテストを書かない。ハプティクスと記録はスパイで回数を検証する。カタログ文言の検査は 13 件の id を列挙したデータ駆動テストにする。
10. **仕上げ確認**: `Timer/` 配下が `SwiftData` / `URLSession` / `Network` / `UserNotifications` / `AVFoundation` / `AudioToolbox` を import していないこと、`print` / `os_log` が無いこと、Assets.xcassets への追加が 0 件であること、ビルド警告 0 件であることを確認する。iPhone SE 実機で「60 秒の種目の実測」「バックグラウンド往復」「自動ロックが実施中だけ抑止される」「完了ハプティクスが 1 回」を目視・体感で確認する。

## 受け入れ条件

- [ ] 結果カードのフッターに「はじめる」「もう 1 回」の 2 ボタンが並び、「はじめる」1 タップでタイマー画面が表示されカウントダウンが始まる
- [ ] タイマー画面に、残り秒数・進捗バー・種目のカード（レア度・部位・種目名・実施時間・手順・注意）・「やめる」が表示される
- [ ] `TimerEngine` の全関数が `StretchItem` と数値のみに依存し、SwiftUI・SwiftData・システム時刻・乱数を参照しない（import と引数で確認できる）
- [ ] `TimerEngine.duration(for:)` が `durationSeconds` 60 → 60、0 → 1、−10 → 1、9999 → 600 を返す（1...600 のクランプ）
- [ ] `TimerEngine.displaySeconds(remaining:)` が 60.0 → 60、59.4 → 60、59.0 → 59、0.1 → 1、0.0 → 0 を返す
- [ ] `TimerEngine.progress(remaining:duration:)` が (60.0, 60) → 0.0、(30.0, 60) → 0.5、(0.0, 60) → 1.0 を返し、`duration == 0` でもクラッシュせず 1.0 を返す
- [ ] `TimerEngine.remaining(deadline:now:)` が負値にならず 0 で下げ止まる
- [ ] 注入クロックで 60 秒の種目を開始し 30.0 秒進めると、残りが 30.0・表示が 30・進捗が 0.5 になる
- [ ] 注入クロックで 59.9 秒進めた時点では `running` のままで、60.0 秒進めた時点で `finished` へ遷移する
- [ ] `finished` への遷移時に完了ハプティクスが **ちょうど 1 回**発火し、その後 `tick()` を何回呼んでも追加発火しない
- [ ] `finished` への遷移時に `PracticeRecording.recordCompletion(itemID:completedAt:)` が **ちょうど 1 回**呼ばれ、渡される `itemID` が実施した種目の `id` と一致する
- [ ] 「やめる」（`abort()`）ではハプティクスが **0 回**、`recordCompletion` が **0 回**である
- [ ] `pause()` 後に注入クロックを 300 秒進めてから `resume()` しても、残り秒数が一時停止時点の値と一致する（バックグラウンド滞在時間の影響を受けない）
- [ ] `paused` の間に `tick()` を呼んでも残り秒数が変化しない
- [ ] `running` の間に `resume()` を呼んでも無視され、残り秒数と `phase` が変化しない
- [ ] `finished` 到達後に `pause()` / `resume()` / `tick()` を呼んでも `phase` が `finished` のまま変わらない
- [ ] `running` の間だけ `isIdleTimerDisabled` が true であり、`paused` / `finished` / `abort()` / `onDisappear()` の後は false になる（抑止のセッタを差し替え可能にして状態を検証する）
- [ ] どの経路（完了・中断・スワイプでの画面破棄）で画面を抜けても、`onDisappear()` を通じて `isIdleTimerDisabled` が false に戻る
- [ ] `TimerEngine` の残り時間・表示秒・進捗の計算 **100,000 回が 2 秒以内**に完了する（テスト実行環境での上限値。実機での設計目標は 1 ティック 50µs 未満）
- [ ] ティック間隔の定数が **0.1 秒**であり、`paused` / `finished` の間はティックが停止する（ティック回数を数えられる形で検証する）
- [ ] タイマーが SwiftData を使わない: `Timer/` 配下のソースが `SwiftData` を import していない
- [ ] `Timer/` 配下のソースが `UserNotifications` / `AVFoundation` / `AudioToolbox` を import しておらず、通知権限を要求する呼び出しが存在しない
- [ ] `Timer/` 配下のソースが `URLSession` / `Network` / `CFNetwork` を import していない
- [ ] `Timer/` 配下に `print` / `os_log` / `debugPrint` によるログ出力が存在しない
- [ ] 画像・音源・カラーセットを 1 つも追加していない（Assets.xcassets への追加が 0 件）
- [ ] `Card/` 配下のファイルが 1 つも変更されておらず、タイマー画面が `StretchCardView(item:style: .detail)` をそのまま使っている
- [ ] `Gacha/` 配下の変更が `GachaView.swift` のみであり、`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` が変更されていない
- [ ] 進捗バーの色が `RarityStyle.accent(for:)` を参照しており、`Timer/` 配下にレア度色の定数が存在しない
- [ ] `StretchCatalog.json` の変更が §3.3 の 13 件の `steps` 文言のみであり、`id` / `durationSeconds` / `rarity` / `bodyPart` / `kind` / `emoji` の差分が 0 件である
- [ ] §3.3 の 13 件それぞれの `steps` のいずれかの要素に「残り」を含む切り替え指示が存在し、指示された秒数が `durationSeconds / 2` と一致する
- [ ] 文言更新後の `StretchCatalog.json` に対して `CatalogValidator.validate()` が違反 0 件を返す（`steps` 2〜6 要素・各 60 文字以内・禁止語なしを維持）
- [ ] カタログに種目を 1 件追加したフィクスチャで、`Timer/` 配下のコードを 1 行も変更せずにその種目のタイマーが成立する
- [ ] タイマー画面がモーダル（`fullScreenCover`）として提示され、タブや常時アクセス可能な画面が増えていない（L1 の 3 画面制約を維持）
- [ ] **【手動計測】** 実機で 60 秒の種目を最後まで実施したとき、実測所要時間と 60 秒の差が **±1.0 秒以内**である
- [ ] **【手動計測】** 実機で実施中にホーム画面へ戻り 30 秒以上経ってから復帰したとき、残り秒数が離脱時の値から再開する
- [ ] **【手動確認】** 実施中は画面が自動ロックせず、完了後・中断後は自動ロックが通常どおり働く
- [ ] **【手動確認】** 完了時に成功ハプティクスが 1 回だけ鳴り、音が一切鳴らない
- [ ] **【表示確認】** iPhone SE（375×667）縦画面で同梱 26 件を実施したとき、残り秒数・進捗バー・レア度バッジ・部位チップ・種目名・「やめる」が常時可視であり、手順のみがスクロールする
- [ ] **【表示確認】** ライトモード / ダークモードの両方で、残り秒数・進捗バー・ボタンが識別できる
- [ ] **【表示確認】** Dynamic Type を AX5 にしても、残り秒数とフッターが画面外へ押し出されない
- [ ] **【表示確認】** VoiceOver で残り時間が「残り時間、45 秒」の形で 1 要素として読まれ、読み上げが 1 秒ごとに割り込まない（10 秒刻みで更新される）
- [ ] gacha-draw / stretch-card 側の既存の受け入れ条件（コールドスタート → 結果カード表示 3.0 秒以内、T1 1.19 秒以下、演出秒数 1.2 / 1.8 / 0.3 秒、手順のみスクロール）が本機能の導入後も引き続き満たされる（手動計測で確認する）
- [ ] 1 セッション（コールドスタート → ガチャ → カード読了 → 実施 → 完了確認）が **3 分以内**に収まる（同梱データ最大 60 秒の種目で実測。設計値は規約最大 90 秒でも 117.81 秒）
- [ ] 本機能の実装によりビルド警告が 0 件である

## 仮置き依存

| # | L1 の仮置き値 | 本書での依存箇所 | 仮置きが覆った場合の影響 |
|---|---|---|---|
| 1 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 左右のある種目をセグメント分割せず単一の通しカウントダウンとし、切り替え合図を手順テキストの運用ルールで代替すると決めた判断（q1）。手動の一時停止 / 再開ボタン、延長・秒数変更 UI を持たない判断 | 期間が延びる場合、カタログへの `segments` フィールド追加 → `TimerEngine` のセグメント対応 → 手順テキストの再修正、という順で拡張できる。カタログのスキーマ変更を伴うため本機能単独では完結しない。一時停止ボタンの追加は `StretchTimerView` と `StretchTimerViewModel` の変更のみで収まる |
| 2 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 非機能要件の「実装完了時期: MVP（2 週間）内」 | MVP 期間が変わっても本機能の設計値（ティック 0.1 秒、レイアウト予算 200pt、1 セッション 117.81 秒、クランプ 1...600）は変わらない |
| 3 | 配布・審査「当面は Xcode 直接インストール。4 週間後に App Store 公開を判断」 | 完了通知をローカル通知ではなく画面表示 + ハプティクスに限定し、通知権限を一切要求しないと決めた判断（q2 / q3）。バックグラウンド実行モードを Info.plist に追加しない判断 | 公開判断が前倒しになっても、通知を使わない構成は App Privacy「データ収集なし」申告と整合し、審査上の追加対応も生じないため、この判断は覆らない見込み。逆に将来ローカル通知を導入する場合は、権限ダイアログが L1 最優先の学習容易性（初回 60 秒）を削るため、L1 の非機能優先順位側の再判断が必要になる |

## 実装記録

---

修正は指摘の 3 点に限定しました。

1. **§3.1 `displaySeconds` のコメント**: 「残り 59.4 秒 → 60 と表示しない（ceil で 60 になるのは 59.0 超のみ）」→「切り上げ（ceil）で求める。残り 59.0 秒ちょうどは 59、59.0 を超えていれば 60 と表示する（例: 59.4 → 60）」。実装・受け入れ条件（59.4 → 60 / 59.0 → 59）と一致。
2. **`ready` の除去**: スコープの状態機械記述を「running ⇄ paused → finished / 中断」に統一（§4 の `TimerPhase` に合わせた）。
3. **軽微 2 件**: `init` に `setIdleTimerDisabled: @escaping (Bool) -> Void` を追加（実装手順 5 にも差し替え経路を 1 文追記）、遷移表に「running + `resume()` → running（無視）」の行と、対応する受け入れ条件 1 行を追加。

数値・レイアウト予算・検算値は指摘対象外のため一切変更していません（変更した箇所に数値の再計算を伴うものはありません）。変更履歴に 1 行追記済みです。
