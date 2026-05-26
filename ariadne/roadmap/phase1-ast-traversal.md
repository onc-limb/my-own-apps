# Phase 1 — AST Traversal Skeleton (without tree-sitter)

> **Goal:** 解析対象を OCaml 自身にし、FFI の苦労ゼロで「AST を再帰的に降りながらカウンタを積む」という静的解析の核心骨格を体得する。

## TODO

### AST Understanding
- [ ] `ppxlib`（または `compiler-libs`）のインストールと基本理解
- [ ] OCaml ソースをパースして AST を取得する最小コードを書く
- [ ] AST をダンプして構造を目で見て理解する
- [ ] OCaml の AST ノード型（`expression`, `pattern`, `structure_item` 等）の関係を把握する

### Recursive Traversal
- [ ] AST を再帰的に走査する関数のパターンを身につける
- [ ] 興味のあるノードだけ拾い、他は再帰で素通りさせる設計を理解する
- [ ] `Ast_traverse` (visitor パターン) の仕組みを把握する

### First Metric: Lines of Code per Function
- [ ] 関数定義ノードを特定する方法を理解する
- [ ] 位置情報（`Location.t`）から行数を計算する
- [ ] 関数名と行数のペアを収集する走査を実装する

### Second Metric: Cyclomatic Complexity
- [ ] 循環的複雑度の定義を理解する（1 + 分岐数）
- [ ] OCaml の分岐ノードを列挙する
  - [ ] `if` 式
  - [ ] `match` の各ケース（arm）
  - [ ] `while` / `for`
  - [ ] `&&` / `||`（短絡評価 = 隠れた分岐）
  - [ ] `try ... with` の各パターン
- [ ] 関数ごとに分岐数をカウントする走査を実装する
- [ ] 計算結果を元コードと突き合わせて妥当性を検証する

### Optional: Nesting Depth
- [ ] ネストの深さを追跡するロジックを追加する
- [ ] 最大ネスト深度を関数ごとに記録する

### CLI Integration
- [ ] コマンドライン引数で `.ml` ファイルパスを受け取る
- [ ] 解析結果を表形式で標準出力に表示する

## Deliverables
- [ ] `.ml` ファイルを解析し、各関数の「行数」と「循環的複雑度」を表示する CLI ツール
- [ ] テスト用サンプル OCaml コードと期待される解析結果

## Completion Criteria
- [ ] AST を再帰的に走査するコードを自力で書ける
- [ ] 循環的複雑度が「制御フローの分岐の数」であり、なぜ `1 + 分岐数` で計算するのかを説明できる
- [ ] 「指標ロジック」と「AST の入力元」が分離できることを理解している
- [ ] 自分のツールが出した数字の妥当性を元コードから検証できる

## Notes
- `ppxlib` の AST 型は大きく複雑。最初から全ノードを理解しようとしない
- 自分が数えたいノード（分岐系）だけに絞って進める
- 「すべてのノードを網羅処理する」必要はない
