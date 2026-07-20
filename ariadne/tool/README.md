# Ariadne (tool) — アーキテクチャメトリクス計測ツール

TypeScript / JavaScript のソースを解析し、アーキテクチャメトリクスを計測・レポートする
OCaml 製 CLI ツール。

> このディレクトリは **完成版ツール** です。`../roadmap` / `../procedure` の
> 学習トラック（自分で OCaml を書いて積み上げる）とは別物で、
> 「すぐ使える実用ツール」かつ「動く OCaml のお手本」として位置づけています。

## できること（v0.2.0）

### `scan` — コードメトリクス（ファイル単位）

- **LOC**: 総行数 / コード行 / コメント行 / 空行
- **循環的複雑度 (Cyclomatic Complexity, McCabe)**: `1 + 分岐点数`
  - 分岐点 = `if` `for` `while` `case` `catch`、論理演算子 `&&` `||` `??`、三項 `?:`
- **認知的複雑度 (Cognitive Complexity)**: ネストの深さで重み付けした「読みにくさ」指標
- しきい値警告（CI ゲート用に終了コードを返す）

### `coupling` — アーキテクチャメトリクス（モジュール単位）

import グラフを構築し、Robert C. Martin のパッケージメトリクスを計算する。

- **Ca（求心性結合）**: このモジュールに依存する内部モジュール数
- **Ce（遠心性結合）**: このモジュールが依存する内部モジュール数
- **I（不安定度）** = `Ce / (Ca + Ce)`（0=安定, 1=不安定）
- **A（抽象度）** = `抽象 export / 全 export`（interface/type/abstract class が抽象）
- **D（主系列からの距離）** = `|A + I - 1|`（0 が理想。大きいほど設計バランスが悪い）

共通: ディレクトリ再帰走査（`.ts` `.tsx` `.js` `.jsx`、`node_modules`/`.git`/`_build`/`dist`/`build` 除外）、テキスト表 / JSON 出力。

## 使い方

```sh
dune build

# コードメトリクス
dune exec bin/main.exe -- scan ./src
dune exec bin/main.exe -- scan ./src --threshold 10   # CC>=10 で flag、超過時 exit 1
dune exec bin/main.exe -- scan ./src --json

# アーキテクチャメトリクス（結合度）
dune exec bin/main.exe -- coupling ./src
dune exec bin/main.exe -- coupling ./src --json
```

## アーキテクチャ（モジュール構成）

| モジュール | 役割 |
|------------|------|
| `lib/tokenizer.ml` | 手書き字句スキャナ。コメント/文字列を空白化し、行分類（LOC）も返す。 |
| `lib/lexer.ml` | クリーン化済みソースを最小限のトークン列に変換（複雑度計測の共通基盤）。 |
| `lib/metrics.ml` | LOC・循環的複雑度の算出。 |
| `lib/cognitive.ml` | 認知的複雑度（ネスト加重）の近似計算。 |
| `lib/imports.ml` | import 指定子の抽出と export 抽象度の集計。 |
| `lib/graph.ml` | モジュール解決と Ca/Ce/I/A/D の計算。 |
| `lib/scanner.ml` | ファイルシステム走査と読み込み。 |
| `lib/report.ml` | テキスト/JSON レポート整形。 |
| `bin/main.ml` | cmdliner による CLI（`scan` / `coupling`）。 |

## v0 の既知の制限（精度に直結）

トークナイザ方式のため、完全な構文解析より粗い近似です。

- **認知的複雑度はトークンベースの近似**。波括弧でネストを近似し、トップレベル関数は
  ネスト 0、ネスト関数のみネスト加算（ネスト 0 のコールバック内部は過小評価方向）。
  型レベルの条件型 `T extends U ? X : Y` の `?` も三項として数えてしまう。
- **テンプレートリテラル `${ }` 内の式** は文字列扱い（中の分岐を数えない）。
- **正規表現リテラル** は未対応（`/` は除算として扱う）。
- **抽象度 A** はトップレベル `export` 宣言のみを近似集計（再エクスポート等は対象外）。
- **計測はファイル単位**。関数単位の内訳は未対応。

これらは tree-sitter フロントエンド（AST ベース）へ差し替える段階で解消予定。

## ロードマップ（このツールの今後）

1. ✅ v0: LOC + 循環的複雑度（ファイル単位、トークナイザ方式）
2. ✅ 認知的複雑度 (Cognitive Complexity, ネスト加重) ＋ 三項対応
3. ✅ **アーキテクチャ指標**: import グラフ → Ca / Ce / I / A / D
4. 循環依存（dependency cycle）の検出
5. 関数単位の内訳（AST フロントエンド導入）

## 出典

- 循環的・認知的複雑度: SonarSource / G. Ann Campbell, "Cognitive Complexity, Because Testability != Understandability" (2017)
  <https://www.sonarsource.com/blog/cognitive-complexity-because-testability-understandability>
- パッケージメトリクス (Ca/Ce/I/A/D): Robert C. Martin, "OO Design Quality Metrics: An Analysis of Dependencies" (1994)
  <https://linux.ime.usp.br/~joaomm/mac499/arquivos/referencias/oodmetrics.pdf>
