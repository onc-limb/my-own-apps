---
feature: stretch-timer
spec: veronica-docs/stretch-gacha/features/stretch-timer/spec.md
generated_at: 2026-08-18
---

# stretch-timer: ガチャ結果カードから 1 タップで開始するストレッチ実施タイマー

## 背景

stretch-gacha は「ガチャで引いたストレッチをその場でやり切る」ことを価値の中心に置いたアプリで、L1 の非機能優先順位は 1 位が学習容易性（説明書なしで初回起動 60 秒以内に最初のガチャ → 実施開始）、2 位がパフォーマンス、3 位が保守性である。

現状、gacha-draw が結果カードを表示するところまでは実装済み（stretch-catalog / stretch-card / gacha-draw が issued_local）だが、引いた種目を実際に「何秒やるか」はユーザー任せになっている。ストップウォッチアプリへの切り替え・秒数の暗算・数え間違いが発生し、初回起動 60 秒以内に実施開始へ到達する導線の最後の 1 タップが欠けている。

また、実施中に手順を読み続けられること（画面が自動ロックしないこと）、途中で他アプリへ移っても残り時間が失われないことが、「やり切れる状態」を維持するうえで必要になる。本機能はこの欠落を埋める。

## ゴール

- 結果カードのフッターの「はじめる」1 タップで、`StretchItem.durationSeconds` 秒の単一の通しカウントダウンを開始し、0 到達時に画面表示とハプティクスで完了を知らせる。
- 実施中もカードを画面に残し、手順を読みながら身体を動かせる状態を保つ（自動ロック抑止、手順のみスクロール）。
- バックグラウンド往復で残り秒を 1 秒も失わない（一時停止時に残り秒を確定保持し、復帰時に `deadline` を引き直す）。
- 通知権限を一切要求せず、音を鳴らさず、何も永続化しない。
- 残り時間・進捗・完了判定を単調クロック注入の純粋関数に隔離し、状態遷移と境界値をすべて実時間待ちなしのユニットテストで検証できる形にする。
- 完了イベントは `PracticeRecording` ポートへ 1 回渡すだけとし、practice-record 実装時に `Timer/` 配下のロジック変更が発生しない構造にする。

## スコープ（やること / やらないこと）

### やること

- 残り時間・進捗・完了判定の純粋計算 `TimerEngine`（`duration` / `remaining` / `displaySeconds` / `progress` / `isFinished`）
- 単調クロックの抽象 `TimerClock`（本番 `MonotonicTimerClock` = `ContinuousClock` ベース / テスト `TestTimerClock` はテストターゲット側に配置）
- 状態機械 `StretchTimerViewModel`（running ⇄ paused → finished / 中断）
- タイマー画面 `StretchTimerView`（残り秒数 + 進捗バー + カード + 「やめる」）
- 完了時のハプティクス（`UINotificationFeedbackGenerator(.success)` を 1 回）
- 実施中の自動ロック抑止（`UIApplication.shared.isIdleTimerDisabled`）と、`onDisappear` を最終合流点とする確実な解除
- バックグラウンド遷移での一時停止・復帰での自動再開（`scenePhase` 監視）
- 実施完了の記録ポート `PracticeRecording` 定義と、practice-record 未実装時の既定実装 `NoopPracticeRecorder`（何もしない）
- 定数集約 `TimerMetrics`（ティック間隔 0.1 秒・秒数クランプ 1...600・a11y 更新刻み 10 秒・レイアウト値）
- `GachaView` の結果カードのフッターに「はじめる」/「もう 1 回」の 2 ボタンを置き、`fullScreenCover` でタイマー画面をモーダル表示する変更
- `StretchCatalog.json` のうち、前後半で対象が切り替わる **13 件の `steps` 文言のみ**を残り秒数基準の表現へ更新
- 上記すべてのユニットテスト（残り時間・進捗・状態遷移・境界値・副作用回数・防御的処理・性能）

### やらないこと

- **セグメント分割（左右の中間合図）**: カタログのスキーマ追加を伴うため MVP 不採用。将来の `segments` フィールド案をコメントで残すのみ
- **完了音・BGM**: 音源アセットを持たず、`AVFoundation` / `AudioToolbox` を import しない
- **ローカル通知・通知権限要求**: `UserNotifications` を import しない
- **手動の一時停止 / 再開ボタン**: 画面上の操作対象は「やめる」1 つのみ。一時停止はバックグラウンド遷移に対する自動処理だけ
- **秒数の変更 UI**（延長・短縮・カスタム秒数）、セット数・インターバル・連続実施モード
- **実施記録・図鑑登録・連続日数の算出**（practice-record の責務）
- **カードのレイアウト**（stretch-card の責務）。`Card/` 配下を 1 行も変更しない
- **抽選・演出**（gacha-draw の責務）。`GachaViewModel` / `GachaDrawer` / `GachaAnimation` / `DailyDrawStore` / `SeededRandomGenerator` に変更を加えない
- タイマー状態の永続化・アプリ強制終了からの復元
- 実施中のカウントダウン読み上げ（1 秒ごとの VoiceOver 割り込み）、音声ガイド
- Live Activity / Dynamic Island / ウィジェット / Apple Watch 連携
- サーバー・外部 API・アナリティクス送信（L1 制約）
- 図鑑（stretch-collection）からのタイマー起動

## 実装方針の要約

**使用技術**: Swift 5.9+ / SwiftUI（iOS 17 以上）、`@Observable`。時間計測は `ContinuousClock`（単調増加）、`Date` は完了時刻の記録にのみ使用。ティックは `Timer.publish(every:on:in:)` + `onReceive`。`UIKit` は `isIdleTimerDisabled` と `UINotificationFeedbackGenerator` のみ。SwiftData は import しない。テストは XCTest。外部ライブラリ 0。

**計算の隔離**: `TimerEngine` は副作用なしの純粋関数群。`duration(for:)` は `durationSeconds` を **1...600 にクランプ**（信頼しない入力として扱い、無限カウント・ゼロ除算を構造的に排除）。`displaySeconds` は切り上げ（`ceil`）で、59.0 ちょうどは 59、59.0 超は 60。`progress` は `duration > 0` ガード + 0...1 クリップ。

**時間の支配**: `TimerClock` を注入し、テストは `TestTimerClock.advance(by:)` で論理時間を進める。実時間を待つテストを 1 つも書かない。残りは毎ティック `deadline − clock.nowSeconds()` から再計算するため、ティック遅延が累積しない。

**状態機械**: `TimerPhase = running / paused / finished`。`init` で `deadline` を設定し running・抑止 ON。`pause()` は残り秒を確定保持して抑止 OFF、`resume()` は保持した残り秒から `deadline` を引き直して抑止 ON（滞在時間に依存せず誤差 0）。`running` 中の `resume()`、`paused` 中の `tick()`、`finished` 到達後の全イベントは無視。`finished` 遷移時のハプティクスと記録は再入ガードで 1 回だけ。`abort()` は記録もハプティクスもなし。

**副作用のポート化**: `CompletionFeedback` / `PracticeRecording` をプロトコル化し、自動ロック抑止も `init` の `setIdleTimerDisabled: @escaping (Bool) -> Void` 経由に統一。テストからスパイで発火回数・ON/OFF 状態を検証できる。

**画面**: ガチャ画面から `fullScreenCover` で提示するモーダル（タブもナビゲーション階層も増やさず、L1 の 3 画面制約を維持）。上から 残り秒数（64pt bold・`.monospacedDigit` + 「秒」20pt）/ 進捗バー（高さ 6pt、塗りは `RarityStyle.accent(for:)`）/ `StretchCardView(item:style:.detail)` / 「やめる」（高さ 56pt・枠線のみ）。`finished` では上 2 要素が「✅ 完了！」に、フッターが「閉じる」に切り替わる（アニメーションなし）。iPhone SE（375×667）で 16+88+16+439+16+56+16 = 647pt の予算に収める。

**パフォーマンス**: ティック 0.1 秒（10Hz、90 秒でも 900 回）。`paused` / `finished` では publisher を切断。カウントダウン中に I/O・非同期・レイアウト再計算を発生させない（触るのは数値 3 つのみ、`item` は不変でカードは再構築されない）。`TimelineView` / `Canvas` / `CADisplayLink` / `blur` / `shadow` を使わない。

**アクセシビリティ**: 残り秒数と進捗バーを 1 要素にまとめ、ラベル「残り時間」・値「45 秒」。`accessibilityValue` の更新は 10 秒刻みに間引く。進捗バーは `.accessibilityHidden(true)`。完了表示は `accessibilityLabel("完了")`。

**カタログ**: 前後半で対象が切り替わる 13 件（neck-02 / neck-05 / shoulder-02 / shoulder-03 / shoulder-04 / shoulder-05 / lowback-02 / lowback-03 / upperback-04 / legs-01 / legs-02 / legs-03 / eyeswrist-01）の `steps` 文言のみを「残り30秒になったら反対側へ」の形（切り替え秒数は `durationSeconds / 2`）に更新。スキーマ・`id` / `durationSeconds` / `rarity` / `bodyPart` / `kind` / `emoji` は変更 0 件。`CatalogValidator` の規約（2〜6 要素・各 60 文字以内・禁止語なし）を維持。

**変更対象ファイル**:

```
stretch-gacha/
├── StretchGacha/
│   ├── Timer/
│   │   ├── TimerEngine.swift              [新規]
│   │   ├── TimerClock.swift               [新規]
│   │   ├── TimerMetrics.swift             [新規]
│   │   ├── CompletionFeedback.swift       [新規]
│   │   ├── PracticeRecording.swift        [新規]
│   │   ├── StretchTimerViewModel.swift    [新規]
│   │   └── StretchTimerView.swift         [新規]
│   ├── Gacha/
│   │   └── GachaView.swift                [変更] フッター 2 ボタン化 + fullScreenCover
│   └── Resources/
│       └── StretchCatalog.json            [変更] 13 件の steps 文言のみ
└── StretchGachaTests/
    └── StretchTimerTests.swift            [新規]
```

**実装手順**: ① `TimerClock` → ② `TimerEngine` → ③ `TimerMetrics` → ④ ポート 2 つ + 既定実装 → ⑤ `StretchTimerViewModel`（遷移表どおり・再入ガード・抑止の集約）→ ⑥ `StretchTimerView`（`scenePhase` 監視・publisher の接続/切断・a11y 修飾）→ ⑦ `GachaView` の変更（`HStack(spacing: 12)` で 195pt + 128pt、`@State private var timerItem: StretchItem?`）→ ⑧ カタログ文言更新 → ⑨ 受け入れ条件に 1:1 対応するテスト → ⑩ 仕上げ確認（禁止 import 0・ログ 0・アセット追加 0・ビルド警告 0、実機での目視確認）。

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
- [ ] `StretchCatalog.json` の変更が対象 13 件の `steps` 文言のみであり、`id` / `durationSeconds` / `rarity` / `bodyPart` / `kind` / `emoji` の差分が 0 件である
- [ ] 対象 13 件それぞれの `steps` のいずれかの要素に「残り」を含む切り替え指示が存在し、指示された秒数が `durationSeconds / 2` と一致する
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

## 参照

- 機能仕様ドキュメント: `veronica-docs/stretch-gacha/features/stretch-timer/spec.md`
  - §1 責務境界 / §2 画面構成と L1 の 3 画面制約
  - §3.1 秒数の決定（`TimerEngine` の関数定義）/ §3.2 表示規則 / §3.3 左右のある種目の扱い（対象 13 件の一覧）
  - §4 状態機械（`TimerPhase`・`StretchTimerViewModel` の初期化引数・遷移表・再入防止）
  - §5.1 タイマー画面 / §5.2 レイアウトメトリクス（647pt の予算検算）/ §5.3 ガチャ結果画面のフッター変更 / §5.4 更新頻度と描画 / §5.5 バックグラウンド・自動ロック / §5.6 完了フィードバック / §5.7 アクセシビリティ
  - §6 データモデル（永続化なし・`PracticeRecording` の定義）/ §7 処理フロー / §8 1 セッション 3 分以内の検算
  - 「非機能要件」「非機能優先順位との対応」「セキュリティ」「実装方針」「受け入れ条件」「仮置き依存」各節
- 関連機能仕様: stretch-catalog（`StretchItem` / `CatalogValidator`）、stretch-card（§4.3 `.detail` メトリクス / §4.7 読み上げ規則 / `RarityStyle`）、gacha-draw（時間予算・フッタースロット）、practice-record（未着手・`PracticeRecording` の実装先）
