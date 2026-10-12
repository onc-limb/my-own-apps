# 機能仕様: safety-notice

## 変更履歴

- 2026-08-18 初版作成

## 概要と提供価値

初回起動時に「痛みが出たら中止する・無理をしない」旨の注意書きを **1 画面・本文 3 行**で提示し、「わかりました」1 タップで以後は二度と表示しない機能。表示要否は `UserDefaults` に保存した確認済みバージョン番号 1 個だけで決まり、判定は純粋関数に隔離する。

表示はルート（`RootTabView`）の**上に被せるオーバーレイ**として実装する。`RootTabView` 以下（ガチャ / 図鑑 / 履歴）はオーバーレイの裏で通常どおり構築されるため、ユーザーが注意書きを読んでいる約 10 秒の間に gacha-draw のカタログ読み込み（150ms）と当日ドロー状態の fetch（50ms）が済み、解除直後にガチャが操作可能になる。

提供価値は 2 つ。

1. **安全に使える前提を最初に 1 度だけ共有する**: L1 のコンテンツ / 法務制約「無理をしない旨の注意書きを初回に表示する」を、アプリ全体で **1 箇所だけ**の実装で満たす。他機能（stretch-catalog / stretch-card / stretch-timer / practice-record / stretch-collection）はいずれも「全体向けの注意書きは safety-notice の責務であり重複して置かない」と明記しており、本機能がその唯一の置き場所になる。
2. **60 秒の予算を削らない**: 追加する機械時間は起動時の `UserDefaults` 同期読み取り **0.01 秒**と解除時の **0.10 秒**のみ。初回起動から最初のストレッチ開始までの合計は **38.97 秒**（60 秒に対し 21.03 秒の余裕）で、L1 最優先 1 位の学習容易性を割らない。

本機能は SwiftData のモデルを追加せず、ネットワークもテキスト入力も持たず、`RootTabView` を 1 行も変更しない。他機能への変更は `StretchGachaApp.swift` の **1 ファイル**だけである。

## スコープ（やること / やらないこと）

### やること

- 表示要否の純粋関数 `SafetyNoticeGate.shouldPresent(acceptedVersion:currentVersion:)` と現行バージョン定数
- 確認済みバージョンの読み書き `SafetyNoticeStore`（`UserDefaults` を注入可能にする）
- 注意書き画面 `SafetyNoticeView`（絵文字 / 見出し / 本文 3 項目 / 「わかりました」）
- 文言定数 `SafetyNoticeText`（画面に出る全文字列を 1 箇所に集約）
- レイアウト定数 `SafetyNoticeMetrics`
- 汎用オーバーレイ `SafetyNoticeGateView<Content>`（中身を `@ViewBuilder` で受け、`RootTabView` を知らない）
- `StretchGachaApp.swift` の変更（ルートを `SafetyNoticeGateView { RootTabView() ... }` で包む）
- 注意書き表示中に背面（タブバー・ガチャ画面）へタップと VoiceOver フォーカスが抜けないようにする処理
- 上記すべてのユニットテスト（判定の境界値・防御的処理・文言規約・副作用回数・性能）

### やらないこと

- **チュートリアル・オンボーディング**（L1 が「チュートリアルは兼ねず 1 画面・数行に留める」と明示）。操作説明・画面紹介・ページャ・スキップ導線を持たない
- **同意の記録・監査ログ**（同意日時、同意回数、同意テキストのスナップショット保存）
- **設定画面からの再表示導線**（そもそも設定画面を作らない。L1 の 3 画面制約を守る）
- **利用規約・プライバシーポリシー・免責事項の全文表示**、外部リンク、Web ビュー
- **チェックボックス「同意します」・スクロール最下部到達の強制・2 段階確認**（操作を増やさない）
- **年齢確認・健康状態の質問・受診勧奨の確認フロー**
- **通知権限の要求**（stretch-timer の方針を継承。`UserNotifications` を import しない）
- **実施ごと / 一定期間ごとの再表示**、リマインド
- **注意書きのバージョン更新に伴うマイグレーション処理**（バージョン番号は持つが、変換コードは書かない）
- **アニメーション**（フェードイン・スライド・遅延表示）。即時表示・即時解除のみ
- **多言語化**（日本語直書き。`Localizable.strings` を作らない）
- **画面・データモデルの追加**（常時アクセス可能な画面は 3 のまま。SwiftData モデル 0 個）
- サーバー・外部 API・アナリティクス送信（L1 制約）

## 機能仕様の詳細

### 1. 責務境界

| 相手 | 方向 | 受け渡すもの |
|---|---|---|
| practice-record | 受け取る | `RootTabView`（オーバーレイの背面に置く対象）。**`Record/` と `RootTabView.swift` は 0 ファイル変更** |
| gacha-draw | 相互作用なし | ガチャ画面は「初回注意書きの有無を前提にしない実装」（gacha-draw §「既存実装との整合」）。本機能はルート側で被せるだけで、`Gacha/` の型を一切参照しない |
| stretch-catalog | 参照しない | 注意書きは種目データに依存しない固定文言。`StretchCatalog` を import しない |
| stretch-card / stretch-timer | 参照しない | 種目固有の注意（`StretchItem.caution`）は各機能の責務。全体注意はここだけに置く |
| stretch-collection | 相互作用なし | 図鑑タブ 3 つ目の構成に影響しない |
| appstore-release-prep | 渡す（将来） | 審査時に参照する全体注意書きの文言（`SafetyNoticeText` の 1 箇所） |

依存の向きは **safety-notice → SwiftUI / Foundation のみ**。`Safety/` 配下は他機能のどのディレクトリも import しない（`SafetyNoticeGateView` は中身をジェネリックな `Content` として受けるため、`RootTabView` への参照も持たない）。逆に他機能から `Safety/` の型を参照させない。

### 2. 表示要否の判定

```swift
// SafetyNoticeGate.swift — 副作用なしの純粋関数
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

**判定表（`currentVersion == 1`）**

| 保存されている値 | `acceptedVersion` | 判定 |
|---|---|---|
| キーが存在しない（初回起動 / 再インストール直後） | 0 | **表示する** |
| `0` | 0 | **表示する** |
| `1`（現行バージョンを確認済み） | 1 | 表示しない |
| `2` 以上（将来バージョンで確認 → ダウングレード） | 2 以上 | 表示しない |
| 負値（外部ツール等による破損） | 負値 | **表示する** |
| Int 以外の型（文字列・配列など） | `UserDefaults.integer(forKey:)` が 0 を返す | **表示する** |

- **フェイルセーフの向きを「表示する」に固定する**。読めない・壊れている・判断がつかないときは注意書きを出す。出しすぎても学習容易性の損失は初回 1 回分の 10 秒に収まり、出さない側に倒すより安全側であるため。
- 上表のすべてが単一の比較式 `acceptedVersion < currentVersion` で覆われる。分岐を増やさない。
- バージョン比較にしているのは、将来 App Store 公開の判断時に文言を追加した場合（§「仮置き依存」#3）に、`currentVersion` を 2 にするだけで再提示できるようにするため。それ以上の機構（差分表示・履歴・マイグレーション）は持たない。

### 3. 永続化

**SwiftData を使わない。** `UserDefaults` に **Int 1 個**だけを保存する。

```swift
// SafetyNoticeStore.swift
struct SafetyNoticeStore {
    static let acceptedVersionKey = "safetyNotice.acceptedVersion"

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard)

    /// 未保存・型違いなら 0 が返る（= 表示する側へ倒れる）
    var acceptedVersion: Int { defaults.integer(forKey: Self.acceptedVersionKey) }

    func accept(version: Int = SafetyNoticeGate.currentVersion) {
        defaults.set(version, forKey: Self.acceptedVersionKey)
    }
}
```

**SwiftData ではなく `UserDefaults` を選ぶ理由**

| 観点 | 判断 |
|---|---|
| 起動時間 | SwiftData モデルを足すと `ModelContainer` の登録と fetch 1 本が起動経路に増える。`UserDefaults` の同期読み取りは設計目標 10ms 未満で、T1 への加算を 0.01 秒に抑えられる（gacha-draw / practice-record の T1 予算に食い込まない） |
| 他機能への波及 | `ModelContainer(for:)` の登録内容を変えない。practice-record・stretch-collection の既存条件（モデル 1 個・登録内容不変）に触れずに済む |
| 規模 | 保存するのは Int 1 個。`@Model` を 1 つ足すのは明らかに過剰 |
| 消失時の挙動 | アプリ削除・再インストールで消え、注意書きが再表示される。これは正しい挙動であり、復旧処理は不要 |

- `synchronize()` は呼ばない（iOS 12 以降は不要）。「わかりました」タップ直後にアプリが強制終了された場合、書き込みが flush されず次回も注意書きが出ることがあるが、影響は 1 回余分に表示されるだけであり回復処理は設けない（L1 妥協特性「運用性」）。
- iCloud 同期（`NSUbiquitousKeyValueStore`）を使わない。値が端末外へ出る経路を持たない。
- `UserDefaults.standard` を直接参照するのは `SafetyNoticeStore.init` の既定引数 **1 箇所のみ**。テストは `UserDefaults(suiteName:)` を注入する。

### 4. 画面仕様

#### 4.1 提示方法（オーバーレイ）

```swift
// SafetyNoticeGateView.swift
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

- **`fullScreenCover` / `sheet` を使わない**。モーダル提示はアニメーションを伴うため、初回起動時にガチャ画面が一瞬見えてから注意書きがせり上がる。`ZStack` の重ね合わせなら **最初のフレームから注意書きが出ている**状態を作れる。
- 判定は `init` で 1 回だけ行う。`onAppear` / `scenePhase` で再評価しない（1 セッション中に値が変わることはない）。
- `SafetyNoticeView` は不透明な全面背景（`Color(.systemBackground).ignoresSafeArea()`）を持つ。SwiftUI では `Color` がヒットテスト対象になるため、背面のタブバー・「回す」ボタンへタップが抜けない。
- 背面は `accessibilityHidden(true)` で VoiceOver から隔離する。表示中に背面の要素へフォーカスが移らないことを手動確認する。
- 解除はアニメーションなし（`.animation` / `withAnimation` を書かない）。この結果、Reduce Motion への個別対応も不要になる（gacha-draw / stretch-timer と同じ整理）。
- 背面の `RootTabView` は表示中も生きているため、`GachaView.onAppear` のカタログ・ウォームアップと当日ドロー状態の fetch は注意書きを読んでいる間に完了する。

#### 4.2 画面の要素（上から順）

| # | 要素 | 内容 |
|---|---|---|
| 1 | 絵文字 | 中央寄せ。「⚠️」1 文字・48pt。stretch-card が種目固有の注意に使う記号と揃え、記号の意味を 1 つに保つ |
| 2 | 見出し | 中央寄せ。「はじめる前に」・`.title2` bold（22pt） |
| 3 | 本文 | 3 項目。中央寄せ・`.body`（17pt）。項目間 12pt。見出しラベル（「注意」等）は置かない |
| 4 | スペーサー | 可変。既定文字サイズで 252pt |
| 5 | ボタン | 「わかりました」。幅いっぱい・高さ 56pt・角丸・塗りつぶし（主ボタン） |

**本文の確定文言**

| # | 文言 | 文字数 |
|---|---|---|
| 1 | 痛みが出たら、すぐに中止してください。 | 19 |
| 2 | 反動をつけず、ゆっくり動かしてください。 | 20 |
| 3 | 体調がすぐれない日は、無理をしないでください。 | 23 |

L1 の「痛みが出たら中止する・無理をしない」を 1 行目と 3 行目で直接満たし、2 行目で安全な動かし方を補う。効能・強度・回数の推奨を書かない（§「セキュリティ / コンテンツ安全性」）。

**ボタンラベルを「わかりました」にする理由**: 注意を確認したという意思表示が 1 語で伝わり、stretch-card のフッターに置かれる「はじめる」（タイマー開始）と語が衝突しない。同じ語を異なる動作に割り当てないことを優先する。

#### 4.3 レイアウトメトリクス（設計基準: iPhone SE 第 2/3 世代 375×667・縦画面固定）

注意書きはタブバーの上に被さるため、利用可能高さはセーフエリア高 **647pt**（タブバー 49pt を差し引かない）。

| 区間 | 高さ |
|---|---|
| 画面上余白 | 24 |
| 絵文字（48pt フォント、行高 58） | 58 |
| 余白 | 16 |
| 見出し（22pt bold、行高 29） | 29 |
| 余白 | 20 |
| 本文 3 項目（各最大 2 行 × 行高 24 = 48、項目間 12 × 2） | 168 |
| スペーサー（可変） | 252 |
| ボタン | 56 |
| 画面下余白 | 24 |
| 合計 | **647** |

検算: 24 + 58 + 16 + 29 + 20 + 168 + 252 + 56 + 24 = **647** ✓（セーフエリア高と一致）
本文の高さ検算: 24 × 2 × 3 + 12 × 2 = 144 + 24 = **168** ✓

**本文の折り返し**

- テキスト幅 = 375 − 24 × 2（画面左右余白）= **327pt**
- 本文 17pt（全角 1 文字 ≈ 17pt）→ 1 行あたり **約 19 文字**
- 確定文言は最長 23 文字なので、最悪でも 2 行に収まる（19 + 4）

**項目数を増やした場合の余裕**（将来 1 行足すときの判断材料）

- 可変部を除く固定部 = 24 + 58 + 16 + 29 + 20 + 56 + 24 = **227pt**
- 本文 5 項目（各 2 行）= 24 × 2 × 5 + 12 × 4 = 240 + 48 = **288pt**
- スペーサー = 647 − 227 − 288 = **132pt** ≥ 0 → レイアウトを変えずに 5 項目まで収まる

**Dynamic Type**

| 要素 | フォント | 追随 |
|---|---|---|
| 見出し | `.title2` bold | 上限なし（AX5 まで） |
| 本文 | `.body` | 上限なし（AX5 まで） |
| ボタンラベル | `.headline` | 上限 `.xxxLarge`（ボタン高さ 56pt を保つため） |
| 絵文字 | `.system(size: 48)` 固定 | **追随しない**（装飾要素） |

絵文字・見出し・本文を `ScrollView` に入れ、**ボタンは画面下に固定する**。既定文字サイズではスペーサー 252pt が残るためスクロールは発生しない。AX5 では本文が伸びてスクロールが有効になり、「わかりました」が画面外へ押し出されない。

#### 4.4 アクセシビリティ（VoiceOver）

1. 絵文字は装飾のため `.accessibilityHidden(true)`
2. 見出しは `.accessibilityAddTraits(.isHeader)`。「はじめる前に」と読まれる
3. 本文は **1 項目 1 要素**（3 要素）。まとめずに読み上げ、1 項目ずつ確認できるようにする
4. 「わかりました」は標準の `Button`。ラベルがそのまま読まれる
5. 背面（タブバー・ガチャ画面）は `accessibilityHidden(true)` により、表示中は VoiceOver から到達できない

テキストはすべて `Text(verbatim:)` で描画する（stretch-card / practice-record / stretch-collection と同じ方針）。

### 5. 状態機械

```swift
// 状態は 2 つだけ
// presented  : 注意書きを表示中（初回起動時のみ到達しうる）
// dismissed  : 注意書きなし（通常の状態）
```

| 現在 | イベント | 次 | 副作用 |
|---|---|---|---|
| （`init`） | `shouldPresent == true` | presented | なし（表示のみ。書き込みは行わない） |
| （`init`） | `shouldPresent == false` | dismissed | なし |
| presented | 「わかりました」タップ | dismissed | `store.accept()`（`UserDefaults` へ **1 回だけ**書き込み） |
| presented | 背面のタップ | presented | 無視（背景がヒットテストを吸収する） |
| presented | `scenePhase` の変化 | presented | 無視（再判定しない・状態を保つ） |
| dismissed | 何をしても | dismissed | 同一セッション中に再表示されない |

**二重書き込みの防止**: 「わかりました」のタップで `isPresented` が false になり、ビュー自体が階層から外れるため、連打しても 2 回目のタップが届かない。判定・書き込みは構造的に 1 回に限定される。

### 6. データモデル（永続化）

**SwiftData のモデルは 0 個。** `ModelContext` を参照せず、`SwiftData` を import しない。`ModelContainer(for: DailyDrawState.self, PracticeRecord.self)` の登録内容を変更しない。

永続化するのは `UserDefaults` の `"safetyNotice.acceptedVersion"`（Int）**1 個だけ**。同意日時・同意回数・同意した文言のスナップショット・起動回数のいずれも保存しない。

### 7. 処理フロー

```
[プロセス起動]
   ├─ ModelContainer(for: DailyDrawState.self, PracticeRecord.self)   ← 変更なし
   ├─ PracticeStore(context:) → loadIndex()                           ← 変更なし（fetch 1 本）
   └─ SafetyNoticeGateView.init
         ├─ store.acceptedVersion                 ← UserDefaults 同期読み取り 1 回（10ms 未満）
         └─ SafetyNoticeGate.shouldPresent(...)   ← 純粋関数・O(1)
   ▼
[最初のフレーム]
   ├─ 背面: RootTabView（既定選択 = ガチャ）を通常どおり構築
   │      └─ GachaView.onAppear → カタログのウォームアップ 150ms + 当日状態 fetch 50ms
   └─ 前面: shouldPresent == true のときだけ SafetyNoticeView を重ねる
            （不透明背景でタップを遮断、背面は accessibilityHidden）
   ▼
[ユーザーが読む（設計上 約 10 秒）]   ← この間に背面のウォームアップが完了している
   ▼
[「わかりました」タップ]
   ├─ store.accept()          ← UserDefaults へ書き込み 1 回（ディスク I/O はここだけ）
   └─ isPresented = false     ← アニメーションなしで即時解除
   ▼
[ガチャ画面が操作可能]  ← 追加の I/O・非同期なし（設計目標 0.10 秒）
   ▼
[2 回目以降の起動]
   └─ shouldPresent == false → オーバーレイを構築せず、gacha-draw の既存経路そのまま
```

**注意書きの表示中も、解除後も、追加のディスク I/O・ネットワーク・非同期処理を発生させない**ことを設計上の固定点とする。

### 8. 初回起動 60 秒の検算

L1 最優先 1 位「初回起動から 60 秒以内に最初のガチャ → ストレッチ実施まで到達」に対する経路（SR/UR の最長演出・演出スキップなし）。

| 区間 | 秒 | 出典 |
|---|---|---|
| プロセス起動 → 注意書きが操作可能（T1'） | 1.06 | gacha-draw 1.00 + practice-record 0.05 + 本機能 0.01 |
| 注意書きの読了 | 10.00 | gacha-draw の 60 秒内訳の割り当て |
| 「わかりました」タップ → ガチャ画面が操作可能 | 0.10 | 本書の設計値（背面は構築済み・I/O なし） |
| ガチャ画面の認識 | 5.00 | gacha-draw の割り当て |
| 「回す」タップ → 結果カード表示（SR/UR 最長） | 1.81 | gacha-draw（抽選 0.01 + 演出 1.80） |
| 結果カードの読了 | 20.00 | gacha-draw の割り当て |
| 「はじめる」タップ | 1.00 | stretch-timer の割り当て |
| 合計 | **38.97** | |

検算: 1.06 + 10.00 + 0.10 + 5.00 + 1.81 + 20.00 + 1.00 = **38.97 秒**。60 秒に対し **21.03 秒の余裕** ✓

**stretch-timer の内訳との突き合わせ**: 同機能は T1 を除いた 37.8 秒（10 + 5 + 1.8 + 20 + 1）を示している。本書の 38.97 秒から T1' 1.06 秒を引くと 37.91 秒で、差の 0.11 秒は「解除 0.10 秒（本機能が持ち込む増分）+ 演出秒数の丸め差 0.01 秒（1.81 対 1.80）」である。**本機能が初回導線に追加する時間は 0.11 秒**。

## 非機能要件

| 項目 | 値 | 根拠・備考 |
|---|---|---|
| 注意書きの表示回数 | 確認前は **毎起動 1 回**、確認後は **0 回**（同一バージョンの間） | L1「初回に 1 度だけ表示し、確認したら以後は出さない」 |
| 表示要否の判定 | `UserDefaults` 同期読み取り **1 回** + O(1) の比較 1 回。実機設計目標 **10ms 未満** | SwiftData を経由しない |
| 　T1 への加算 | **0.01 秒** | 下 2 行に反映 |
| 　T1（プロセス起動 → ガチャ画面が操作可能・2 回目以降） | 設計値 **1.06 秒**（gacha-draw 1.00 + practice-record 0.05 + 本機能 0.01）／検収上限 **1.19 秒** | gacha-draw の既存上限を据え置き、余裕 130ms |
| 　コールドスタート → 結果カード表示（E2E・2 回目以降） | 設計値 **2.87 秒**／上限 **3.0 秒** | 1.06 + 1.81。余裕 130ms |
| 初回起動: プロセス起動 → 注意書きが操作可能 | **1.19 秒以下**（設計値 1.06 秒） | T1 と同一の上限を流用する |
| 「わかりました」タップ → ガチャ画面が操作可能 | 設計目標 **0.10 秒**／検収上限 **0.30 秒** | 背面は構築済み。追加の I/O・非同期・アニメーションなし |
| 初回起動 → 最初のストレッチ実施開始 | **38.97 秒**（60 秒以内） | §8 の検算 |
| 　本機能が初回導線に追加する時間 | **0.11 秒** | 判定 0.01 + 解除 0.10 |
| `shouldPresent` 1 回の所要時間 | O(1)。実機設計目標 1µs 未満 | Int の比較 1 回 |
| 　同上・テストのアサート閾値 | **100,000 回の判定が 2 秒以内** | シミュレータ / CI の実行環境差を吸収する余裕を持った上限 |
| 　`SafetyNoticeStore` 経由の読み取り | **1,000 回が 2 秒以内**（テスト実行環境での上限値） | 同上 |
| SwiftData クエリ本数 | **fetch 0 本 / save 0 回**（`SwiftData` を import しない） | `ModelContainer` の登録内容を変更しない |
| 追加する SwiftData モデル数 | **0 個** | |
| 永続化する値の数 | **1 個**（`UserDefaults` の Int 1 個） | 同意日時・回数・文言を保存しない |
| ディスク書き込み回数 | 「わかりました」タップ時に **1 回**のみ。以後 **0 回** | |
| ディスク使用量 | **100B 未満**（キー文字列 + Int 1 個） | |
| ネットワークリクエスト数 | **0 件** | L1 制約: サーバー・外部 API 禁止 |
| 通知権限の要求回数 | **0 回**（`UserNotifications` を import しない） | stretch-timer の方針を継承 |
| 追加アセット数 | **0 個**（画像・音源・カラーセット・フォントを追加しない） | 絵文字 1 文字と標準色のみ |
| メモリ増分 | **1MB 未満**（実質は Bool 1 個と固定文字列 5 個） | |
| 常時アクセス可能な画面数 | **3**（ガチャ / 図鑑 / 履歴）のまま増やさない | 初回 1 回だけのオーバーレイは加算しない（stretch-timer の `fullScreenCover`・stretch-collection の詳細シートと同じ整理） |
| 画面上の操作対象 | **1 個**（「わかりました」） | チェックボックス・リンク・スキップを置かない |
| 本文の項目数 | 設計値 **3 項目**。レイアウト上は 5 項目まで収容可能 | §4.3 の検算 |
| 本文 1 項目の文字数 | 設計値 **最長 23 文字**。テストのアサート上限 **30 文字** | 2 行 × 19 文字 = 38 文字の収容に対し余裕を持った上限 |
| 常時可視を保証する要素 | 「わかりました」ボタン | 本文のみスクロールする（AX5 時） |
| 対応最小画面 | 375×667pt（iPhone SE 第 2/3 世代）・縦画面固定 | L1: iPhone のみ・縦固定 |
| 他機能に対する変更ファイル数 | **1 ファイル**（`StretchGachaApp.swift`） | `RootTabView.swift` を含め他は 0 |
| 種目追加時に本機能で変更するファイル数 | **0 ファイル** | カタログを参照しない |
| 想定同時ユーザー数 | 1（自分のみ） | L1 妥協特性: スケーラビリティ |
| 実装完了時期 | MVP（2 週間）内 ※**L1 の仮置き値に基づく** | L1「期限・マイルストーン」が【仮置き】 |

**既存の手動計測条件の前提を明確化する**: gacha-draw / practice-record / stretch-collection の「コールドスタート → 結果カード表示 3.0 秒以内」「T1 1.19 秒以下」は、いずれも **注意書きを確認済みの状態（2 回目以降の起動）で計測する**ものとする。初回起動は注意書きの読了 10 秒を含むため同じ土俵で比較できない。これは既存条件の緩和ではなく計測前提の明文化であり、条件の数値は 1 つも変更しない。

## 非機能優先順位との対応

### 1 位: 学習容易性（説明書なしで初回起動 60 秒以内に最初のガチャ → 実施開始）

- **60 秒の予算に 0.11 秒しか追加しない**: 注意書きの読了 10 秒は gacha-draw が当初から確保していた枠であり、本機能が新たに持ち込む機械時間は判定 0.01 秒 + 解除 0.10 秒だけ。合計 38.97 秒で 21.03 秒の余裕を残す（§8）。
- **操作対象を 1 つに絞る**: ボタンは「わかりました」だけ。チェックボックス、「同意する / 同意しない」の 2 択、スクロール最下部到達の強制、規約リンクを置かない。覚える操作が増えない。
- **読む量を 3 行に固定する**: 見出し 1 行 + 本文 3 項目（各最長 23 文字）。L1 の「1 画面・数行に留める」をレイアウト予算とテストの両方で担保する。長文の免責・利用規約全文を出さない。
- **チュートリアルを兼ねない**: 画面説明・操作ガイド・ページャを一切持たない。L1 が「チュートリアルは兼ねず」と明示しており、ここで説明を足すと 60 秒の予算を直接削る。
- **一瞬もガチャ画面を見せない**: モーダル提示ではなくオーバーレイにすることで、最初のフレームから注意書きが出る。画面が切り替わる様子を見せないことで「何が起きたのか」を考えさせない。
- **戻れない状態を作らない**: 注意書きは 1 タップで抜けられ、抜けた先が既に構築済みのガチャ画面である。待ち・読み込み表示・遷移アニメーションを挟まない。
- **失敗状態を作らない**: エラーダイアログ・リトライ導線・権限要求ダイアログを持たない。`UserDefaults` が読めなくても「表示する」側に倒れるだけで、ユーザーには常に同じ 1 画面しか見えない。
- **記号の意味を 1 つに保つ**: 「⚠️」は stretch-card が種目固有の注意に使う記号と同じ。アプリ全体で「⚠️ = 注意」の対応を崩さない。

### 2 位: パフォーマンス（コールドスタート → 結果 3 秒以内、演出 60fps）

- **起動経路への加算を 0.01 秒に固定する**: 判定は `UserDefaults` の同期読み取り 1 回と Int の比較 1 回のみ。SwiftData の fetch を増やさず、`ModelContainer` の登録内容も変えないため、practice-record が確保した 140ms の余裕を 130ms に留める。
- **2 回目以降はビューすら構築しない**: `shouldPresent == false` のとき `SafetyNoticeView` は `ZStack` の分岐で生成されない。通常運用（確認後）の描画コストが 0 になる。
- **待ち時間を背面のウォームアップに充てる**: オーバーレイ方式により、ユーザーが読んでいる 10 秒の間に gacha-draw のカタログ読み込み（150ms）と当日状態 fetch（50ms）が完了する。解除後にこれらを走らせるモーダル方式より、体感の待ちが短い。
- **描画経路から I/O と非同期を排除する**: `SwiftData` / `URLSession` / `Task` / `async` を `Safety/` に持ち込まない。書き込みはタップ時の 1 回だけで、演出中・カウントダウン中には決して起きない。
- **重い描画機能を使わない**: `blur` / `shadow` / `mask` / `TimelineView` / `Canvas` を使わない。画像アセットを持たないためデコードも発生しない。
- **アニメーションを持たない**: 表示・解除ともに即時。`.animation` / `withAnimation` を書かないため、60fps を要求される区間と重なる余地が構造的に無い。

### 3 位: 保守性（週末開発でも壊さず拡張できる）

- **判定を純粋関数に隔離する**: `SafetyNoticeGate.shouldPresent` は SwiftUI・SwiftData・`UserDefaults`・`Date`・乱数のいずれにも依存せず、Int 2 つだけを受ける。§2 の判定表がそのままユニットテストになる。
- **永続化に触る場所を 1 箇所に集める**: `UserDefaults` を触るのは `SafetyNoticeStore` だけ。`UserDefaults.standard` の直接参照は既定引数の 1 箇所に限定し、テストからは別 suite を注入する。
- **文言を 1 箇所に集約する**: 画面に出る全文字列を `SafetyNoticeText` に置き、`SafetyNoticeView` に文字列リテラルを書かない。App Store 公開時に文言を見直す際、変更点が 1 ファイルに収まる。
- **他機能のコードをほぼ触らない**: 変更は `StretchGachaApp.swift` の 1 ファイル（ルートを `SafetyNoticeGateView` で包む数行）のみ。`RootTabView.swift` すら変更しない。`Gacha/` / `Card/` / `Timer/` / `Record/` / `Collection/` / `Catalog/` は 0 ファイル変更。
- **背面を知らない実装にする**: `SafetyNoticeGateView` は中身をジェネリックな `Content` で受けるため、`RootTabView` の構成（タブ 2 つでも 3 つでも）に依存しない。stretch-collection がタブを増やしても本機能に波及しない。
- **バージョン更新の口だけ用意する**: 文言変更時は `SafetyNoticeText` の修正と `currentVersion` の +1 で完結する。差分表示・履歴・マイグレーション変換コードは書かない（stretch-catalog が `schemaVersion` を持ちつつ変換コードを書かないのと同じ整理）。
- **テストは範囲・上限でアサートする**: 性能は「100,000 回 2 秒以内」「1,000 回 2 秒以内」という余裕を持った上限で書く。本文の文字数は設計値 23 に対し上限 30 でアサートし、文言の微修正でテストが落ちないようにする。一方、判定表の 6 ケース・文言の項目数・禁止語の不在のように経路差で揺れない値は厳密にアサートする。

### 妥協特性で簡略化すること

| 妥協特性 | 本機能で作らないもの |
|---|---|
| スケーラビリティ | 保存するのは Int 1 個で、複数ユーザー・複数プロファイル・端末間の同意状態管理を持たない。注意書きの出し分け（ユーザー属性・地域・言語別）、A/B テスト、表示回数の集計基盤を持たない |
| 互換性・相互運用性 | 同意状態のエクスポート / インポート、iCloud 同期、他端末への引き継ぎ、他形式（規約管理サービス等）との連携を持たない。多言語化せず日本語直書き。`UserDefaults` のキーはこのアプリ専用 |
| 運用性 | 同意日時・同意回数のログ、表示成否のアナリティクス、書き込み失敗の検知・リトライ・通知、同意状態をリセットするデバッグ画面を持たない。書き込み前にアプリが落ちた場合は次回もう 1 回表示されるだけで、復旧処理を設けない。不具合は自分が使って気づいたら直す |

## セキュリティ

本機能は完全ローカル・単一ユーザーで、ネットワークもテキスト入力も扱わない。攻撃面は「`UserDefaults` に保存した確認済みバージョンの読み戻し」と「注意書きの表示を迂回されないこと」に限定される。

### 認証・認可

- **不要（実装しない）**。アカウント・ログインを持たない単一端末・単一ユーザー構成（L1 のスコープ外事項）。注意書きに権限による出し分けは存在しない。
- **OS 権限を 1 つも要求しない**: 通知・カメラ・マイク・位置情報・HealthKit のいずれの権限ダイアログも出さない。要求しない権限は Info.plist の使用目的文字列も追加しない（stretch-timer の方針を継承）。初回起動で権限ダイアログを出さないことは、L1 最優先の学習容易性を守るための要件でもある。
- **書き換え経路を絞る**: 公開 API は読み取り（`acceptedVersion`）と確認の記録（`accept(version:)`）の 2 つだけ。確認済み状態を取り消す・巻き戻す API を公開しない。他機能から `Safety/` の型を参照させない。

### 入力検証

- ユーザー入力はボタンタップ 1 種類のみ。テキスト入力・数値入力・URL スキーム / ユニバーサルリンクの受け口を持たない。
- **永続化データを「信頼しない入力」として扱う**: `UserDefaults.integer(forKey:)` は未保存・型違いのとき 0 を返す。判定は `acceptedVersion < currentVersion` の単一比較で、§2 の判定表のすべて（未保存・0・負値・型違い・将来バージョン）を分岐なしで安全に処理する。**判断がつかない場合は必ず「表示する」側へ倒れる**。
- **表示の迂回経路を作らない**: 注意書きは不透明な全面背景でヒットテストを吸収し、`accessibilityHidden` で背面を VoiceOver から隔離する。表示中に背面のタブバー・「回す」ボタンへ到達する経路を持たない。スワイプで閉じられるモーダル（`sheet` / `interactiveDismiss`）を使わないため、確認せずに閉じることもできない。
- **書き込みを 1 回に限定する**: 「わかりました」のタップでビューが階層から外れるため、連打しても 2 回目のタップが届かない。二重書き込み・二重解除が構造的に起きない。
- **表示テキストを書式として解釈させない**: すべて `Text(verbatim:)` で描画する。`LocalizedStringKey` を受ける `Text` イニシャライザを `Safety/` 配下で使わない（stretch-card / practice-record / stretch-collection と同じ方針）。テキスト選択・データ検出・リンク化も有効にしない。

### データ保護

- **保存するのは Int 1 個だけ**。氏名・メールアドレス・端末識別子・位置情報・利用統計・同意日時・同意回数を一切保存しない。App Privacy「データ収集なし」申告（appstore-release-prep）と矛盾しない状態を維持する。
- `UserDefaults` の値は iOS の Data Protection 下に置かれ、追加の暗号化は行わない（保存内容に秘匿性がないため）。キーチェーンも使わない。
- **iCloud 同期を有効化しない**: `NSUbiquitousKeyValueStore` を使わない。確認済み状態が端末外へ複製されない。
- **ネットワークを使わない**: `URLSession` / `Network` / `CFNetwork` を import しない。App Transport Security 設定を緩めない。規約全文を Web ビューで読み込むこともしない。
- **ログ出力を残さない**: `Safety/` 配下に `print` / `os_log` / `debugPrint` を書かない。確認状態を外部へ送らない。
- スクリーンショット・画面録画の制限は設けない（注意書きに秘匿情報が無いため）。

### 依存関係

- 外部ライブラリ 0。`SwiftUI` / `Foundation` で完結する（L1 制約: 外部ライブラリ原則ゼロ）。`SwiftData` も `UIKit` も使わない（ハプティクスを持たない）。

### コンテンツ安全性（法務制約の技術的担保）

- **本機能が L1 の法務制約「無理をしない旨の注意書きを初回に表示する」を満たす唯一の実装箇所**である。stretch-catalog（`caution` は種目固有の注意のみ）、stretch-card、stretch-timer、practice-record、stretch-collection のいずれも「全体向けの注意書きは safety-notice の責務であり重複して置かない」と明記しており、その前提を本機能が引き受ける。
- **医学的効能・専門家監修を主張しない**: 文言に「治る」「治療」「効能」「医学」「監修」「診断」「処方」（stretch-catalog の禁止語 7 語と同一）を含めない。テストで機械的に検査する。検査は `SafetyNoticeTests` 内に 7 語のリストを持って行う。`CatalogValidator` はカタログ JSON 向けの検査であり、対象（固定 UI 文言 対 データファイル）が異なるため流用しない。
- **受診勧奨・健康状態の判断を書かない**: 「医師に相談してください」等の医療的な指示を出さない。医学的判断を示唆する文言を持たないことで、L1 の「医学的効能は謳わず専門家監修も主張しない」を文言レベルで担保する。書くのは「痛みが出たら中止する」「反動をつけない」「体調がすぐれない日は無理をしない」という、行為の中止と加減に関する記述のみ。
- **効能・強度・回数の推奨を書かない**: どの部位に効くか、何回やるべきかを注意書きに書かない（それらは種目データの責務であり、かつ効能表現になり得る）。
- 文言の追加が必要になる場合（App Store 公開の判断時）は `SafetyNoticeText` の変更と `currentVersion` の +1 で対応する（§「仮置き依存」#3）。

## 実装方針

### 使用技術

- Swift 5.9+ / SwiftUI（iOS 17 以上）
- `Foundation` の `UserDefaults`（Int 1 個の読み書きのみ）
- **SwiftData は使わない**（import しない）。**UIKit も使わない**
- テストは XCTest（標準）

### 既存実装との整合

- **practice-record（status: issued_local）**: 同機能が導入した `RootTabView` をオーバーレイの背面に置く。**`Record/` 配下と `RootTabView.swift` は 0 ファイル変更**。`PracticeStore` を参照せず、`.environment(store)` の注入位置も変えない（`SafetyNoticeGateView` の中身として `RootTabView().environment(store)` をそのまま渡す）。同機能の受け入れ条件（起動時 fetch 1 本、記録 1 回あたり fetch 0 本 / save 1 回、履歴表示 fetch 0 本）はいずれも維持される。
  - T1 への加算 0.01 秒により、同機能の設計値 1.05 秒は **1.06 秒**になる。検収上限 1.19 秒に対する余裕は 140ms → **130ms**。上限値そのものは変更しない。
- **gacha-draw（status: issued_local）**: **`Gacha/` 配下は 0 ファイル変更**。同機能が「ガチャ画面は初回注意書きの有無を前提にしない実装とし、safety-notice がルート側で被せる形になる」と設計した通りに載せる。同機能の責務境界表にある「safety-notice から確認済みフラグを受け取る」行は、**ガチャ画面側が何も参照しない（表示制御が完全にルート側で完結する）**という形で満たす。
  - E2E 設計値は 2.86 秒 → **2.87 秒**（上限 3.0 秒に対し余裕 130ms）。演出秒数（1.2 / 1.8 / 0.3）・fetch 本数・確率の各条件には一切影響しない。
- **stretch-collection（status: issued_local）**: **`Collection/` 配下は 0 ファイル変更**。タブ 3 つの構成・既定選択タブ・タブ選択の非永続化に触れない。`SafetyNoticeGateView` が中身をジェネリックに受けるため、タブ構成の変更に対して本機能は不変。
- **stretch-card（status: issued_local）** / **stretch-timer（status: issued_local）** / **stretch-catalog（status: issued_local）**: いずれも **0 ファイル変更**。`StretchItem` を参照せず、`RarityStyle` も使わない（注意書きにレア度の概念が無いため）。`StretchCatalog.json` の差分は 0 件。
- **collection-progress / appstore-release-prep（後回し）**: 相互作用なし。App Store 公開を判断した場合、審査向けの文言点検は `SafetyNoticeText` の 1 箇所を見るだけで済む。
- Xcode プロジェクト（`stretch-gacha/`）は先行機能の実装時に作成済みの想定。

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

`RootTabView.swift` を含め、上記以外のファイルは変更しない。

### 実装手順

1. **`SafetyNoticeGate.swift`**: `currentVersion = 1` と `shouldPresent(acceptedVersion:currentVersion:)` を実装。単一の比較式で §2 の判定表を覆うこと、フェイルセーフの向きが「表示する」であることをコメントに明記する。この関数が `Foundation` すら不要な純粋関数であることを構造的な固定点にする。
2. **`SafetyNoticeStore.swift`**: `UserDefaults` を注入可能にした薄いラッパを実装。キー文字列を `static let` で定義し、`integer(forKey:)` が未保存・型違いで 0 を返すこと（＝表示側へ倒れること）をコメントに残す。`synchronize()` を呼ばない理由も併記する。
3. **`SafetyNoticeText.swift`**: 見出し「はじめる前に」、本文 3 項目（§4.2 の確定文言）、ボタン「わかりました」、絵文字「⚠️」を定数化する。本文は `[String]` として持ち、項目数と文字数をテストから検査できる形にする。禁止語 7 語を含めない旨をコメントに残す。
4. **`SafetyNoticeMetrics.swift`**: §4.3 の数値（画面余白 24、絵文字 48pt、見出し 22pt、項目間 12、ボタン 56pt）を定数化し、検算値をコメントで併記する。ビューにマジックナンバーを書かない。
5. **`SafetyNoticeView.swift`**: §4.2 の 5 要素を上から実装。絵文字・見出し・本文を `ScrollView` に入れ、ボタンは下部固定。全面背景 `Color(.systemBackground).ignoresSafeArea()` を最背面に敷いてタップを吸収する。テキストはすべて `Text(verbatim:)`。§4.4 のアクセシビリティ修飾を付ける。`.animation` / `withAnimation` / `Task` / `async` を書かない。確認のクロージャ（`onAccept`）だけを外から受け、`UserDefaults` を直接触らない。
6. **`SafetyNoticeGateView.swift`**: `@ViewBuilder` の `Content` を受けるジェネリックビューとして実装。`init` で `shouldPresent` を 1 回だけ評価して `@State` の初期値にする。表示中は中身に `accessibilityHidden(true)` を適用する。`RootTabView` の型を参照しないことをコメントで固定点として残す。
7. **`StretchGachaApp.swift` の変更**: `WindowGroup` の中身を `SafetyNoticeGateView { RootTabView().environment(practiceStore) }` に置き換える。`ModelContainer` の登録内容、`PracticeStore` の生成・注入には触れない。
8. **`SafetyNoticeTests.swift`**: 「受け入れ条件」の各項目に 1:1 対応するテストを実装。判定は §2 の 6 ケースをデータ駆動テストにする。永続化を伴うテストは `UserDefaults(suiteName:)` を注入し、`setUp` / `tearDown` で `removePersistentDomain(forName:)` を呼んで独立させる。文言の検査（項目数 1〜5、各 30 文字以内、禁止語 7 語の不在）を機械的に行う。実時間を待つテストを 1 つも書かない。
9. **仕上げ確認**: `Safety/` 配下が `SwiftData` / `UIKit` / `URLSession` / `Network` / `CFNetwork` / `UserNotifications` を import していないこと、`Gacha/` `Card/` `Timer/` `Record/` `Collection/` `Catalog/` の型を参照していないこと、`print` / `os_log` が無いこと、Assets.xcassets への追加が 0 件であること、ビルド警告 0 件であることを確認する。実機（アプリを削除してからインストール）で「初回起動で最初のフレームから注意書きが出る」「確認後に再起動しても出ない」「アプリ削除 → 再インストールで再び出る」「ライト / ダーク」「Dynamic Type AX5」「VoiceOver で背面に到達できない」を目視確認する。

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

## 仮置き依存

| # | L1 の仮置き値 | 本書での依存箇所 | 仮置きが覆った場合の影響 |
|---|---|---|---|
| 1 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 注意書きを 1 画面・本文 3 行に固定し、設定画面からの再表示導線、同意日時の記録、表示アニメーション、多言語化を作らないと決めた判断 | 期間が延びても、L1 が「チュートリアルは兼ねず 1 画面・数行に留める」と確定させているため文言量の判断は覆らない。再表示導線を足す場合は設定画面（4 つ目の画面）の追加が必要になり、L1 の「画面は 3 つまで」の再判断を伴うため本機能単独では完結しない。表示アニメーションの追加は `SafetyNoticeGateView` の変更のみで収まり、判定ロジック・保存形式には波及しない |
| 2 | 期限・マイルストーン「MVP を 2 週間で実機投入」 | 非機能要件の「実装完了時期: MVP（2 週間）内」 | MVP 期間が変わっても本機能の設計値（判定 0.01 秒・解除 0.10 秒・レイアウト予算 647pt・保存値 1 個）は変わらない |
| 3 | 配布・審査「当面は Xcode 直接インストール。仮: 4 週間の自己利用で価値を確認できたら App Store 公開を判断する」 | 配布範囲が自分 1 人であることを前提に、注意書きを本文 3 行に留め、利用規約・免責事項の全文表示や受診勧奨の文言を持たないと決めた判断 | App Store 公開を判断した場合、appstore-release-prep 側で審査ガイドライン（身体への危害に関する項）に照らして文言の追加要否を点検する。追加が必要になっても、対応は `SafetyNoticeText` の文言変更と `SafetyNoticeGate.currentVersion` を 2 へ上げること（既存ユーザーへ再提示される）で収まり、判定ロジック・保存形式・画面構成には波及しない。**本機能がバージョン番号を Bool ではなく Int で持つ理由がこれにあたる**。文言を 5 項目まで増やしてもレイアウトは変更不要（§4.3 の検算） |
| 4 | 配布・審査「App Privacy は『データ収集なし』で申告（ローカル完結・トラッキングなし）」 | 同意日時・同意回数・端末識別子を一切保存せず、`UserDefaults` に Int 1 個だけを持つと決めた判断 | 公開判断が前倒しになっても、端末外へ出さない構成は「データ収集なし」申告と整合し、審査上の追加対応は生じない。逆に将来「いつ同意したか」の記録が必要になった場合は保存する値が増えるため、申告内容と L1 の「個人情報は収集しない」制約側の再判断が必要になる |

## 実装記録
