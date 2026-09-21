# Phase 0 — 学習プラン

> トップページ 1 枚で **何を学ぶか**、そのために **どの要素を置くか** の対応表。
> スコープ・作業順序・完了基準は [phase0-top-page.md](phase0-top-page.md) 側にある。

## このドキュメントの使い方

- 学習項目には `H`（HTML）`C`（CSS）`J`（JavaScript）`P`（公開と検証）の記号を振ってある。
- **最初に全部読まない。** 作業順序（phase0-top-page.md の §6）を進めていき、
  その要素を作る番になったら該当項目だけ開く。
- 各項目には「つまずきやすい点」がある。**答えは書いていない。**
  そこに気づけるかどうかが学習の中身なので、自分で調べて解く。
- 節目ごとに §6 の到達判定に戻り、**自分の言葉で声に出して説明する**。

### なぜ「自分の言葉で説明する」形にしているのか

Bisra ら (2018) は 64 の研究・69 の効果量を対象にしたメタ分析で、
**自己説明（self-explanation）を促すと学習成果が向上する**ことを示した
（ランダム効果モデルで g = 0.55）。
また Roediger & Karpicke (2006) は、読み返すより**思い出そうとするほうが長期保持に効く**
ことを示している。

→ だからこのドキュメントは「読んで理解する資料」ではなく
**「作った後に自分へ問い直すための質問集」** として作られている。
コードが動いた時点で終わりにせず、§6 の質問に答えられるかを確認する。

---

## 1. HTML — 文書構造

| # | 学ぶこと | 担うページ要素 | つまずきやすい点 |
| --- | --- | --- | --- |
| **H1** | 文書の骨格とメタ情報（`<!DOCTYPE html>`、`lang`、`charset`、viewport、`title`、`description`、OG） | `<head>` 全体 | `lang` を書き忘れると読み上げ言語が狂う。viewport が無いとモバイルで縮小表示される |
| **H2** | ランドマーク要素（`header` / `nav` / `main` / `footer` / `section`） | ページ全体の骨格 | `div` との違いは「支援技術に役割が伝わるか」。`section` は**アクセシブルな名前がないとランドマークにならない** |
| **H3** | 見出しの階層 | `h1` 1 つ + 各 section の `h2` + カードの `h3` | 見た目の大きさで選ばない。レベルを飛ばさない |
| **H4** | リンクとボタンの区別 | カードのリンク / テーマトグル / タグチップ | **遷移するなら `a`、その場で何かするなら `button`**。`div` に click を付けるとキーボードで押せない |
| **H5** | リストのマークアップ | カードグリッド（`ul > li > article`） | `list-style: none` を当てると支援技術からリストの意味が消える実装がある。対処法を調べる |
| **H6** | フォーム部品とラベル | 検索 `input`、並び順 `select`、タグの `input[type=checkbox]` | `label` と `for` / `id` の結び付け。**プレースホルダはラベルの代わりにならない** |
| **H7** | 画像と代替テキスト | ロゴ、（任意で）カードのサムネイル | 装飾画像は `alt=""`。`width` / `height` を書かないとレイアウトシフトが起きる |
| **H8** | ネイティブ要素で済ませる判断 | `<details>` を補足説明に | JS を書く前に「HTML だけで足りないか」を毎回問う癖をつける |

## 2. CSS — 見た目とレイアウト

| # | 学ぶこと | 担うページ要素 | つまずきやすい点 |
| --- | --- | --- | --- |
| **C1** | カスケード・詳細度・継承 | 全体 | `!important` を使いたくなったら、それは詳細度の設計が失敗したという合図 |
| **C2** | カスタムプロパティでトークン化 | `:root` の色・余白・角丸・タイポ | 変数は**継承する**。だから `[data-theme]` で再定義すると配下に伝播する。**これがダークモードの仕組みそのもの** |
| **C3** | ボックスモデルと `box-sizing` | カードとボタンの余白 | `border-box` を全体に当てる定番の理由を、自分で説明できるか |
| **C4** | 論理プロパティ | 余白全般（`padding-block` / `margin-inline`） | `left` / `right` ではなく `inline-start` / `end` で書く意味 |
| **C5** | Flexbox（1 次元） | ヘッダーの配置、絞り込みバー、バッジの並び | 隙間は `gap` で作る。`margin` で作らない |
| **C6** | Grid（2 次元） | カードグリッド `repeat(auto-fit, minmax(...))` | `auto-fit` と `auto-fill` の違い。カードが 1 枚のときの挙動 |
| **C7** | 流動的なサイズ指定 | `clamp()` で見出し、`ch` で本文の行長 | メディアクエリを書く前に `clamp()` と `minmax()` で解けないかを考える |
| **C8** | テーマの 3 段重ね | `color-scheme` / `prefers-color-scheme` / `[data-theme]` | **CSS だけで OS 追従までを完成させ、JS には「上書き」だけを任せる**という役割分担 |
| **C9** | 色とコントラスト | 本文、バッジ、フォーカスリング | ダークモードで彩度の高い色は眩しい。両テーマで基準を満たすか |
| **C10** | 状態のスタイル | `:hover` / `:focus-visible` / `[aria-pressed]` / `:has()` | `:focus` ではなく `:focus-visible`。フォーカスリングを消さない |
| **C11** | モーションの配慮 | トグルと表示切替の transition | `prefers-reduced-motion: reduce` で無効化する |
| **C12** | ファイル分割 | `tokens.css` / `base.css` / `layout.css` | **読み込み順がカスケード順**になる。分割の基準を自分で決める |

## 3. JavaScript — DOM と状態

| # | 学ぶこと | 担うページ要素 | つまずきやすい点 |
| --- | --- | --- | --- |
| **J1** | スクリプトの読み込みと実行順序 | `<script type="module">` と `<head>` の短いインラインスクリプト | `defer` と `module` は既定で遅延する。**テーマ適用だけは遅延させられない（FOUC）**。最初の設計課題 |
| **J2** | 要素の取得と `dataset` | カードの `data-tags` / `data-status` | `querySelectorAll` が返すのは配列ではない。`Array.from` が要る場面 |
| **J3** | イベントとイベント委譲 | タグチップの束 | チップごとに listener を付けるか、親に 1 つ付けるか。**要素が動的に増える想定だと委譲が要る** |
| **J4** | 属性とクラスの操作 | `hidden` / `classList` / `aria-pressed` / `aria-live` | 見た目だけ変えて `aria-*` の更新を忘れる。`hidden` と `display: none` の関係 |
| **J5** | `localStorage` と例外処理 | テーマの永続化 | プライベートモードや設定で**例外を投げる**。`try` / `catch` が必要。保存できるのは文字列だけ |
| **J6** | URL に状態を載せる | 絞り込み条件 | `pushState` と `replaceState` の違い。入力のたびに履歴を積むと戻るボタンが壊れる |
| **J7** | **単一の state と render 関数** | 絞り込み全体 | **Phase 0 の山。** DOM を直接いじる書き方と `state → render()` にまとめる書き方を**両方書いて比べる** |
| **J8** | 配列の絞り込みと並べ替え | `filter` / `sort` / `localeCompare` | `sort` は破壊的。日本語の並び順をどう決めるか |
| **J9** | 入力の間引き | 検索ボックス | デバウンスを自分で書く（`setTimeout` / `clearTimeout`） |
| **J10** | モジュール分割 | `theme.js` / `filter.js` | **ビルド無しで `import` が動く条件**（`type="module"`、相対パス、拡張子必須、オリジン） |

## 4. 公開と検証

| # | 学ぶこと | 担うもの | つまずきやすい点 |
| --- | --- | --- | --- |
| **P1** | ファイル配置と URL の対応 | `apps/web/public/` の構造 | `/assets/...` を絶対パスで書くか相対で書くか。`html_handling` で末尾スラッシュの扱いが変わる |
| **P2** | キャッシュ | 「更新したのに反映されない」現象 | Cloudflare の既定挙動を読む。ファイル名に版を付ける手法（Phase 1 の伏線） |
| **P3** | DevTools | 全部 | Elements（その CSS がどこから来たか）/ Network（サイズと回数）/ Application（localStorage）/ Lighthouse |
| **P4** | キーボードと支援技術での検証 | 全部 | Tab だけで一周する。VoiceOver で実際に読ませてみる |

---

## 5. 逆引き — ページ要素から学習項目へ

要素を作っている最中に「いま何を学んでいるのか」を確認するための表。

| ページ要素 | 学習項目 |
| --- | --- |
| `<head>` とメタ情報 | H1 |
| skip link | H2 H4 / C10 |
| ヘッダー（サイト名 + トグル） | H4 / C5 |
| **テーマ切替トグル** | J1 J4 J5 / C2 C8 C9 C11 |
| 概要セクション | H2 H3 / C7 |
| 絞り込みバー（検索 / タグ / 並び順） | H6 / C5 C10 / J2 J3 J9 |
| 件数表示と空状態メッセージ | J4 J7 |
| カードグリッド | H5 / C3 C4 C6 |
| カード内のステータスと技術バッジ | C2 C10 / J2 |
| **絞り込みの実行** | J6 J7 J8 |
| フッター | H2 |
| CSS / JS のファイル分割 | C12 / J10 / P1 |
| デプロイと確認 | P1 P2 P3 P4 |

**テーマトグルと絞り込みの 2 行が太字なのは、そこが JS 段階 1 / 段階 2 にあたるため。**
段階 2 で感じる面倒さは失敗ではなく成果（→ [phase0-top-page.md](phase0-top-page.md) §3）。

---

## 6. 到達判定 — 自分の言葉で説明できるか

コードが動いた時点では終わりにしない。次に**声に出して答えられるか**を確認する。
詰まった質問が、次に調べるべき場所。

### HTML

1. `section` と `div` の違いを、支援技術の観点で説明できるか
2. なぜ `h1` は 1 つなのか。見た目の大きさと見出しレベルはどういう関係か
3. リンクとボタンの選び分けの基準を、1 文で言えるか
4. `label` と `placeholder` の役割の違いは何か

### CSS

5. カスタムプロパティがダークモードに効くのは、CSS のどの性質のおかげか
6. `auto-fit` と `auto-fill` は何が違うか。どちらを選んだか、なぜか
7. `clamp()` を使うとメディアクエリが減るのはなぜか
8. `:focus` ではなく `:focus-visible` を使う理由は何か
9. `color-scheme` は何を変えるのか。`prefers-color-scheme` との違いは
10. CSS ファイルを分けた基準は何か。読み込み順を変えると何が起きるか

### JavaScript

11. OS がダークで、前回ユーザーが light を選んでいたら、どちらを優先すべきか。その根拠は
12. テーマ適用を遅延スクリプトでやると何が起きるか。なぜそうなるのか
13. `hidden` 属性と `display: none` はどういう関係か
14. `localStorage` が例外を投げるのはどんなときか。落ちない書き方にしたか
15. イベント委譲が必要になるのはどんなときか
16. 絞り込み UI で `pushState` と `replaceState` のどちらを選んだか。なぜか
17. **状態を 1 つ増やしたとき、直さないといけない場所をどうやって列挙したか**
18. **`state → render()` にまとめると何が楽になり、何が犠牲になるか**
19. `sort` を呼ぶ前に気をつけることは何か
20. デバウンスは何を防いでいるのか
21. ビルド無しで `import` が動く条件は何か

### 公開と検証

22. CSS を変更したのに反映されないとき、最初に見る場所はどこか
23. Tab キーだけで操作して、どこで詰まったか。どう直したか

**17 と 18 が Phase 0 の中心。** この 2 問への自分の答えが、
Phase 1 で React を入れたときの比較の基準線になる。
答えを `journal/` に文章で残しておく。

---

## 7. 意図的に学ばないこと

Phase 0 の目的は **「状態と DOM を自分の手で繋ぐ体験」**。
それ以外は今は雑音になるので触らない。

| 触らないもの | いつ学ぶか |
| --- | --- |
| 仮想 DOM / リアクティブシステム | Phase 1 |
| バンドラ・トランスパイル | Phase 1 |
| TypeScript と型 | Phase 1 |
| サーバサイドと DB | Phase 1 |
| Web Components | Phase 1（React 版と CSS を共有する話が出てから） |
| Service Worker / オフライン | Phase 2 以降 |
| Canvas / WebGL | 必要になったら |
| 自動テスト | Phase 1 以降 |

---

## 8. 参照する一次情報

分からないときは、まとめ記事より先にこちらを開く。

- [MDN Web Docs](https://developer.mozilla.org/ja/) — HTML / CSS / JavaScript の第一の参照先
- [HTML Living Standard](https://html.spec.whatwg.org/multipage/) — 要素の定義を最終確認するとき
- [WAI-ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/) — トグルボタンやチップの正しい実装パターン
- [web.dev — Learn CSS](https://web.dev/learn/css/) — CSS を体系的に追うとき
- [Cloudflare Workers — Static Assets](https://developers.cloudflare.com/workers/static-assets/) — 配信と URL の挙動

---

## 出典（学習設計の根拠）

- Bisra, K., Liu, Q., Nesbit, J. C., Salimi, F., & Winne, P. H. (2018). "Inducing Self-Explanation: a Meta-Analysis." *Educational Psychology Review*, 30(3), 703–725. <https://link.springer.com/article/10.1007/s10648-018-9434-x>
- Roediger, H. L., & Karpicke, J. D. (2006). "Test-Enhanced Learning: Taking Memory Tests Improves Long-Term Retention." *Psychological Science*, 17(3), 249–255. <https://doi.org/10.1111/j.1467-9280.2006.01693.x>
- 比較による学習の根拠（Alfieri et al. 2013 / Schwartz & Bransford 1998）は [../docs/concept.md](../docs/concept.md) を参照。
