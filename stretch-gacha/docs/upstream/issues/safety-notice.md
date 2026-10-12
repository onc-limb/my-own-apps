---
feature: safety-notice
spec: veronica-docs/stretch-gacha/features/safety-notice/spec.md
generated_at: 2026-08-18
---

# safety-notice: 初回起動時の安全注意書き（1 画面・本文 3 行・1 タップで恒久非表示）

## 背景

L1 のコンテンツ / 法務制約として「無理をしない旨の注意書きを初回に表示する」が定められているが、現時点でこれを満たす実装はどこにも存在しない。他機能（stretch-catalog / stretch-card / stretch-timer / practice-record / stretch-collection）はいずれも「全体向けの注意書きは safety-notice の責務であり重複して置かない」と明記しており、本機能がアプリ全体で唯一の置き場所になる。

同時に、L1 最優先 1 位は「説明書なしで初回起動 60 秒以内に最初のガチャ → ストレッチ実施開始まで到達」であり、注意書きがこの予算を削ってはならない。そこで本機能は、モーダル提示ではなく `RootTabView` の上に被せるオーバーレイとして実装する。ユーザーが注意書きを読む約 10 秒の間に、背面で gacha-draw のカタログ読み込み（150ms）と当日ドロー状態の fetch（50ms）が完了するため、解除直後にガチャが操作可能になる。本機能が初回導線に追加する機械時間は判定 0.01 秒 + 解除 0.10 秒の **0.11 秒**のみで、初回起動から最初のストレッチ開始までの合計は **38.97 秒**（60 秒に対し 21.03 秒の余裕）となる。

表示要否は `UserDefaults` に保存した確認済みバージョン番号 **Int 1 個**だけで決まり、判定は純粋関数に隔離する。SwiftData のモデルは追加せず、ネットワークもテキスト入力も持たず、`RootTabView` を 1 行も変更しない。

## ゴール

- 初回起動時に「痛みが出たら中止する・無理をしない」旨の注意書きを **1 画面・本文 3 行**で提示し、「わかりました」1 タップで以後は二度と表示しない。
- L1 の法務制約を、アプリ全体で **1 箇所だけ**の実装（`Safety/` 配下 6 ファイル）で満たす。
- 起動経路への加算を **0.01 秒**、解除を **0.10 秒**に抑え、gacha-draw / practice-record の既存検収上限（T1 1.19 秒 / E2E 3.0 秒）を 1 つも変更しない。
- 他機能への変更を `StretchGachaApp.swift` の **1 ファイル**に限定する（`RootTabView.swift` を含め他は 0 ファイル変更）。
- 判定・永続化・文言・レイアウトをそれぞれ独立した型に分離し、文言変更が `SafetyNoticeText` の修正と `currentVersion` の +1 だけで完結する構造にする。

## スコープ（やること / やらないこと）

### やること

- 表示要否の純粋関数 `SafetyNoticeGate.shouldPresent(acceptedVersion:currentVersion:)` と現行バージョン定数（`currentVersion = 1`）
- 確認済みバージョンの読み書き `SafetyNoticeStore`（`UserDefaults` を注入可能にする）
- 注意書き画面 `SafetyNoticeView`（絵文字 / 見出し / 本文 3 項目 / 「わかりました」）
- 文言定数 `SafetyNoticeText`（画面に出る全文字列を 1 箇所に集約）
- レイアウト定数 `SafetyNoticeMetrics`
- 汎用オーバーレイ `SafetyNoticeGateView<Content>`（中身を `@ViewBuilder` で受け、`RootTabView` を知らない）
- `StretchGachaApp.swift` の変更（ルートを `SafetyNoticeGateView { RootTabView() ... }` で包む数行）
- 注意書き表示中に背面（タブバー・ガチャ画面）へタップと VoiceOver フォーカスが抜けないようにする処理
- 上記すべてのユニットテスト（判定の境界値・防御的処理・文言規約・副作用回数・性能）

### やらないこと

- **チュートリアル・オンボーディング**（L1 が「チュートリアルは兼ねず 1 画面・数行に留める」と明示）。操作説明・画面紹介・ページャ・スキップ導線を持たない
- **同意の記録・監査ログ**（同意日時、同意回数、同意テキストのスナップショット保存）
- **設定画面からの再表示導線**（そもそも設定画面を作らない。L1 の 3 画面制約を守る）
- **利用規約・プライバシーポリシー・免責事項の全文表示**、外部リンク、Web ビュー
- **チェックボックス「同意します」・スクロール最下部到達の強制・2 段階確認**
- **年齢確認・健康状態の質問・受診勧奨の確認フロー**
- **通知権限の要求**（`UserNotifications` を import しない。stretch-timer の方針を継承）
- **実施ごと / 一定期間ごとの再表示**、リマインド
- **バージョン更新に伴うマイグレーション処理**（バージョン番号は持つが、変換コードは書かない）
- **アニメーション**（フェードイン・スライド・遅延表示）。即時表示・即時解除のみ
- **多言語化**（日本語直書き。`Localizable.strings` を作らない）
- **画面・データモデルの追加**（常時アクセス可能な画面は 3 のまま。SwiftData モデル 0 個）
- サーバー・外部 API・アナリティクス送信（L1 制約）

## 実装方針の要約

### 使用技術・依存

Swift 5.9+ / SwiftUI（iOS 17 以上）と `Foundation` の `UserDefaults` のみ。外部ライブラリ 0。`SwiftData` / `UIKit` / `URLSession` / `Network` / `CFNetwork` / `UserNotifications` を `Safety/` 配下に import しない。テストは XCTest。

### 判定（`SafetyNoticeGate`）

副作用なしの純粋関数を単一の比較式 `acceptedVersion < currentVersion` で実装する。

```swift
enum SafetyNoticeGate {
    /// 現行の注意書きバージョン。文言を実質的に変更したときだけ +1 する
    static let currentVersion = 1

    /// 確認済みバージョンが現行に満たなければ表示する
    static func shouldPresent(acceptedVersion: Int,
                              currentVersion: Int = SafetyNoticeGate.currentVersion) -> Bool {
        acceptedVersion < currentVersion
    }
}
```

判定表（`currentVersion == 1`）は次の 6 ケースすべてを分岐なしで覆う。**フェイルセーフの向きは常に「表示する」に固定する。**

| 保存されている値 | `acceptedVersion` | 判定 |
|---|---|---|
| キーが存在しない（初回起動 / 再インストール直後） | 0 | **表示する** |
| `0` | 0 | **表示する** |
| `1`（現行バージョンを確認済み） | 1 | 表示しない |
| `2` 以上（将来バージョンで確認 → ダウングレード） | 2 以上 | 表示しない |
| 負値（外部ツール等による破損） | 負値 | **表示する** |
| Int 以外の型（文字列・配列など） | `integer(forKey:)` が 0 を返す | **表示する** |

### 永続化（`SafetyNoticeStore`）

SwiftData を使わず、`UserDefaults` に `"safetyNotice.acceptedVersion"`（Int）**1 個だけ**を保存する。`UserDefaults` を触るのは本型のみで、`UserDefaults.standard` の直接参照は `init` の既定引数 1 箇所に限定し、テストは `UserDefaults(suiteName:)` を注入する。`synchronize()` は呼ばない（書き込み前に落ちた場合は次回 1 回余分に表示されるだけで、復旧処理を設けない）。`NSUbiquitousKeyValueStore` を使わず、値が端末外へ出る経路を持たない。公開 API は読み取り `acceptedVersion` と記録 `accept(version:)` の 2 つだけで、確認済み状態を取り消す・巻き戻す API を公開しない。

### 提示方法（`SafetyNoticeGateView`）

`fullScreenCover` / `sheet` を使わず、`ZStack` の重ね合わせで**最初のフレームから注意書きが出ている**状態を作る。

```swift
struct SafetyNoticeGateView<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var isPresented: Bool
    private let store: SafetyNoticeStore

    init(store: SafetyNoticeStore = SafetyNoticeStore(),
         @ViewBuilder content: @escaping () -> Content) {
        self.store = store
        self.content = content
        _isPresented = State(initialValue:
            SafetyNoticeGate.shouldPresent(acceptedVersion: store.acceptedVersion))
    }

    var body: some View {
        ZStack {
            content()
                .accessibilityHidden(isPresented)
            if isPresented {
                SafetyNoticeView { store.accept(); isPresented = false }
            }
        }
    }
}
```

- 判定は `init` で 1 回だけ行い、`onAppear` / `scenePhase` で再評価しない。
- 中身をジェネリックな `Content` で受けるため `RootTabView` の型を参照せず、タブ構成の変更に対して不変。
- 不透明な全面背景 `Color(.systemBackground).ignoresSafeArea()` がヒットテストを吸収し、背面のタブバー・「回す」ボタンへタップが抜けない。背面は `accessibilityHidden(true)` で VoiceOver から隔離する。
- `.animation` / `withAnimation` を書かないため、Reduce Motion への個別対応も不要。
- 2 回目以降は `ZStack` の分岐で `SafetyNoticeView` が生成されず、描画コストが 0 になる。

### 画面（`SafetyNoticeView` / `SafetyNoticeText` / `SafetyNoticeMetrics`）

上から 絵文字「⚠️」48pt（`accessibilityHidden`）／ 見出し「はじめる前に」`.title2` bold（`.isHeader`）／ 本文 3 項目 `.body`（1 項目 1 要素・項目間 12pt）／ 可変スペーサー／「わかりました」ボタン 高さ 56pt の 5 要素。文字列はすべて `SafetyNoticeText` に集約し、`Text(verbatim:)` で描画する（`LocalizedStringKey` を受けるイニシャライザを `Safety/` 配下で使わない）。

本文の確定文言:

1. 痛みが出たら、すぐに中止してください。（19 文字）
2. 反動をつけず、ゆっくり動かしてください。（20 文字）
3. 体調がすぐれない日は、無理をしないでください。（23 文字）

レイアウトは iPhone SE（375×667・縦固定）のセーフエリア高 647pt を基準に、24 + 58 + 16 + 29 + 20 + 168 + 252 + 56 + 24 = **647** で検算済み。本文幅 327pt・17pt で 1 行約 19 文字のため、最長 23 文字でも 2 行に収まる。将来 5 項目まではレイアウト変更なしで収容できる（スペーサー 132pt が残る）。絵文字・見出し・本文を `ScrollView` に入れ、ボタンは画面下に固定して AX5 でも押し出されないようにする。数値はすべて `SafetyNoticeMetrics` に定数化し、ビューにマジックナンバーを書かない。

### 状態機械

状態は presented / dismissed の 2 つ。`init` の判定では書き込みを行わず、「わかりました」タップ時のみ `store.accept()` で **1 回だけ**書き込む。タップで `isPresented` が false になりビューが階層から外れるため、連打しても二重書き込みが構造的に起きない。背面タップと `scenePhase` の変化は無視する。

### 変更対象ファイル

```
stretch-gacha/
├── StretchGacha/
│   ├── Safety/
│   │   ├── SafetyNoticeGate.swift        [新規] 表示要否の純粋関数 + currentVersion
│   │   ├── SafetyNoticeStore.swift       [新規] UserDefaults 読み書き（注入可能）
│   │   ├── SafetyNoticeText.swift        [新規] 見出し / 本文 3 項目 / ボタンラベルの定数
│   │   ├── SafetyNoticeMetrics.swift     [新規] 余白・フォントサイズ・ボタン高さの定数
│   │   ├── SafetyNoticeView.swift        [新規] 注意書き 1 画面
│   │   └── SafetyNoticeGateView.swift    [新規] 背面を知らない汎用オーバーレイ
│   └── StretchGachaApp.swift             [変更] ルートを SafetyNoticeGateView で包む（数行）
└── StretchGachaTests/
    └── SafetyNoticeTests.swift           [新規] 判定境界値・防御的処理・文言規約・副作用回数・性能
```

`RootTabView.swift` を含め、上記以外のファイルは変更しない。`Gacha/` `Card/` `Timer/` `Record/` `Collection/` `Catalog/` は 0 ファイル変更。

### 実装手順

1. **`SafetyNoticeGate.swift`**: `currentVersion = 1` と `shouldPresent(acceptedVersion:currentVersion:)` を実装。単一の比較式で判定表を覆うこと、フェイルセーフの向きが「表示する」であることをコメントに明記する。`Foundation` すら不要な純粋関数であることを構造的な固定点にする。
2. **`SafetyNoticeStore.swift`**: `UserDefaults` を注入可能にした薄いラッパを実装。キー文字列を `static let` で定義し、`integer(forKey:)` が未保存・型違いで 0 を返すこと（＝表示側へ倒れること）と `synchronize()` を呼ばない理由をコメントに残す。
3. **`SafetyNoticeText.swift`**: 見出し・本文 3 項目・ボタンラベル・絵文字を定数化。本文は `[String]` として持ち、項目数と文字数をテストから検査できる形にする。禁止語 7 語を含めない旨をコメントに残す。
4. **`SafetyNoticeMetrics.swift`**: 画面余白 24 / 絵文字 48pt / 見出し 22pt / 項目間 12 / ボタン 56pt を定数化し、647pt の検算値をコメントで併記する。
5. **`SafetyNoticeView.swift`**: 5 要素を上から実装。`ScrollView` + 下部固定ボタン、全面背景でタップ吸収、`Text(verbatim:)`、アクセシビリティ修飾を付ける。`.animation` / `withAnimation` / `Task` / `async` を書かない。確認のクロージャ（`onAccept`）だけを外から受け、`UserDefaults` を直接触らない。
6. **`SafetyNoticeGateView.swift`**: `@ViewBuilder` の `Content` を受けるジェネリックビューとして実装。`init` で `shouldPresent` を 1 回だけ評価して `@State` の初期値にする。`RootTabView` の型を参照しないことをコメントで固定点として残す。
7. **`StretchGachaApp.swift` の変更**: `WindowGroup` の中身を `SafetyNoticeGateView { RootTabView().environment(practiceStore) }` に置き換える。`ModelContainer` の登録内容、`PracticeStore` の生成・注入には触れない。
8. **`SafetyNoticeTests.swift`**: 受け入れ条件の各項目に 1:1 対応するテストを実装。判定は 6 ケースをデータ駆動テストにする。永続化を伴うテストは `UserDefaults(suiteName:)` を注入し、`setUp` / `tearDown` で `removePersistentDomain(forName:)` を呼んで独立させる。文言検査（項目数 1〜5、各 30 文字以内、禁止語 7 語の不在）を機械的に行う。実時間を待つテストを 1 つも書かない。
9. **仕上げ確認**: 禁止 import の不在、他機能の型を参照していないこと、`print` / `os_log` の不在、Assets.xcassets への追加 0 件、ビルド警告 0 件を確認。実機で目視確認項目（下記「表示確認」）を実施する。

## 受け入れ条件

### 表示要否の判定

- [ ] `SafetyNoticeGate.shouldPresent` が Int 2 つのみに依存し、SwiftUI・SwiftData・`UserDefaults`・`Date`・`Calendar`・乱数を参照しない（import と引数で確認できる）
- [ ] `acceptedVersion == 0`（未保存）で `currentVersion == 1` のとき `true` を返す
- [ ] `acceptedVersion == 1`・`currentVersion == 1` のとき `false` を返す
- [ ] `acceptedVersion == 2`（将来バージョン / ダウングレード）・`currentVersion == 1` のとき `false` を返す
- [ ] `acceptedVersion` が負値（`-1` 等）のとき `true` を返す
- [ ] `SafetyNoticeGate.currentVersion` が **1** である
- [ ] 保存キーに Int 以外の型（文字列）が入っていても、クラッシュせず `acceptedVersion` が 0 として読まれ、注意書きが表示される
- [ ] 判定できない・値が壊れている全ケースで「表示する」側へ倒れる（フェイルセーフの向きが一貫している）

### 表示と確認の挙動

- [ ] 未確認の状態でアプリを起動すると、注意書きが表示される
- [ ] 注意書きに 絵文字・見出し・本文 3 項目・「わかりました」ボタン が表示される
- [ ] 本文に「痛みが出たら中止する」旨と「無理をしない」旨が含まれる
- [ ] 「わかりました」をタップすると注意書きが閉じ、ガチャ画面が操作可能になる
- [ ] 「わかりました」のタップで `UserDefaults` への書き込みが **ちょうど 1 回**発生し、保存される値が `SafetyNoticeGate.currentVersion` と一致する
- [ ] 確認後にアプリを再起動しても注意書きが表示されない
- [ ] 確認前にアプリを終了して再起動すると、注意書きが再び表示される（読まずに落とした場合は確認済みにならない）
- [ ] 注意書きの表示だけでは `UserDefaults` への書き込みが発生しない（**0 回**）
- [ ] 注意書きの表示中に背面（タブバー・「回す」ボタン）へタップが到達しない
- [ ] 注意書きをスワイプ・背面タップで閉じる経路が存在しない（閉じられるのは「わかりました」のみ）
- [ ] `scenePhase` の変化（バックグラウンド往復）で表示要否が再評価されず、表示状態が保たれる

### 文言

- [ ] 画面に出るすべての文字列が `SafetyNoticeText` に集約され、`SafetyNoticeView.swift` に文字列リテラルが存在しない
- [ ] 本文の項目数が **1 以上 5 以下**である（設計値は 3 項目）
- [ ] 本文の各項目が **30 文字以内**である（設計値は最長 23 文字。2 行 × 19 文字 = 38 文字の収容に対する余裕を持った上限）
- [ ] 見出し・本文・ボタンラベルのいずれにも禁止語（治る・治療・効能・医学・監修・診断・処方）が含まれない
- [ ] 文言に受診勧奨・医学的判断・効能・強度・回数の推奨が含まれない（レビューで確認する）
- [ ] 文言がすべて `Text(verbatim:)` で描画され、`LocalizedStringKey` を受ける `Text` イニシャライザが `Safety/` 配下に存在しない

### 性能・規模

- [ ] `SafetyNoticeGate.shouldPresent` の **100,000 回の実行が 2 秒以内**に完了する（テスト実行環境での上限値）
- [ ] `SafetyNoticeStore.acceptedVersion` の **1,000 回の読み取りが 2 秒以内**に完了する（テスト実行環境での上限値。実機での設計目標は 1 回 10ms 未満）
- [ ] 表示要否の判定・表示・確認のいずれにおいても SwiftData の fetch が **0 本**・save が **0 回**である
- [ ] 本機能が SwiftData のモデルを 1 つも追加せず、`ModelContainer` の登録内容が変わっていない
- [ ] `UserDefaults` に保存されるキーが `"safetyNotice.acceptedVersion"` の **1 個だけ**である（同意日時・回数・文言のスナップショットを保存していない）
- [ ] `UserDefaults.standard` を直接参照する箇所が `SafetyNoticeStore.init` の既定引数 **1 箇所のみ**である
- [ ] `NSUbiquitousKeyValueStore`（iCloud 同期）を使用していない

### 他機能との整合

- [ ] 他機能に対する変更が `StretchGachaApp.swift` の **1 ファイル**のみである
- [ ] `RootTabView.swift` が **0 ファイル変更**である（タブ数 3・既定選択がガチャ・選択状態の非永続化がいずれも変わっていない）
- [ ] `Gacha/` `Card/` `Timer/` `Record/` `Collection/` `Catalog/` 配下がいずれも **0 ファイル変更**であり、`StretchCatalog.json` の差分が 0 件である
- [ ] `SafetyNoticeGateView` が `RootTabView` の型を参照しない（`@ViewBuilder` の `Content` で受けている）
- [ ] 確認後の起動でタブが「ガチャ」「図鑑」「履歴」の 3 つであり、起動直後に選択されているのがガチャタブである
- [ ] 常時アクセス可能な画面が **3 つのまま**であり、タブ・ナビゲーション階層が増えていない
- [ ] gacha-draw / practice-record の既存条件「ガチャ 1 回あたりの fetch が 0 本・save が 1 回」「起動時の索引読み込みが fetch 1 本」が本機能の導入後も維持される
- [ ] gacha-draw の演出秒数（N/R 1.2 / SR/UR 1.8 / Reduce Motion 0.3）が変わっていない

### 構造・依存

- [ ] `Safety/` 配下のソースが `SwiftData` / `UIKit` / `URLSession` / `Network` / `CFNetwork` / `UserNotifications` を import していない
- [ ] `Safety/` 配下のソースが `Gacha/` `Card/` `Timer/` `Record/` `Collection/` `Catalog/` 配下の型を参照していない
- [ ] `Safety/` 配下に `print` / `os_log` / `debugPrint` によるログ出力が存在しない
- [ ] `Safety/` 配下に `.animation` / `withAnimation` / `Task` / `async` が存在しない
- [ ] 画像・音源・カラーセット・フォントを 1 つも追加していない（Assets.xcassets への追加が 0 件）
- [ ] 通知・カメラ・マイク・位置情報のいずれの権限も要求せず、Info.plist に使用目的文字列が追加されていない
- [ ] カタログに種目を 1 件追加したフィクスチャで、`Safety/` 配下のコードを 1 行も変更せずに動作する（本機能が種目データに依存していない）
- [ ] 確認済み状態を取り消す・巻き戻す公開 API が存在しない
- [ ] 本機能の実装によりビルド警告が 0 件である

### 手動計測

- [ ] **【手動計測】** 実機の初回起動（アプリ削除後にインストール）で、プロセス起動から注意書きが操作可能になるまでが **1.19 秒以下**である（設計値 1.06 秒）
- [ ] **【手動計測】** 「わかりました」タップからガチャ画面が操作可能になるまでが **0.30 秒以下**である（設計値 0.10 秒）
- [ ] **【手動計測】** 実機の初回起動から最初のストレッチ実施開始（タイマー画面の表示）までが **60 秒以内**である（設計値 38.97 秒）
- [ ] **【手動計測】** 確認済みの状態（2 回目以降の起動）で、コールドスタートからガチャ画面が操作可能になるまで（T1）が **1.19 秒以下**である（gacha-draw / practice-record の既存条件。設計値 1.06 秒）
- [ ] **【手動計測】** 確認済みの状態で、コールドスタートから結果カード表示までのエンドツーエンドが **3.0 秒以内**である（同上。設計値 2.87 秒）

### 表示確認

- [ ] **【表示確認】** 初回起動時、最初のフレームから注意書きが表示され、ガチャ画面・タブバーが一瞬も見えない
- [ ] **【表示確認】** iPhone SE（375×667）縦画面で、絵文字・見出し・本文 3 項目・「わかりました」がスクロールなしですべて収まる
- [ ] **【表示確認】** ライトモード / ダークモードの両方で、見出し・本文・ボタンが背景に埋もれず識別できる
- [ ] **【表示確認】** Dynamic Type を AX5 にしても「わかりました」が画面外へ押し出されず、本文がスクロールで全文へ到達できる
- [ ] **【表示確認】** VoiceOver で「はじめる前に」が見出しとして読まれ、本文 3 項目が 1 項目ずつ読まれ、絵文字が読み上げられない
- [ ] **【表示確認】** VoiceOver で、注意書きの表示中に背面のタブバー・「回す」ボタンへフォーカスが移動しない
- [ ] **【表示確認】** アプリを削除して再インストールすると、注意書きが再び表示される

## 参照

- 機能仕様ドキュメント: `veronica-docs/stretch-gacha/features/safety-notice/spec.md`
  - §2 表示要否の判定（判定表 6 ケース / フェイルセーフの向き）
  - §3 永続化（`UserDefaults` を選ぶ理由）
  - §4 画面仕様（オーバーレイ方式 / 確定文言 / レイアウトメトリクス 647pt の検算 / アクセシビリティ）
  - §5 状態機械（二重書き込みの防止）
  - §7 処理フロー、§8 初回起動 60 秒の検算（38.97 秒）
  - 「実装方針 > 既存実装との整合」（gacha-draw / practice-record / stretch-collection / stretch-card / stretch-timer / stretch-catalog への 0 ファイル変更）
  - 「仮置き依存」#1〜#4（MVP 2 週間 / App Store 公開判断時の文言追加は `SafetyNoticeText` + `currentVersion` の +1 で対応）
