# Phase 2 — Reading TypeScript (tree-sitter Introduction)

> **Goal:** 本命の TypeScript 対応へ。tree-sitter を導入し、フェーズ1のロジックを外部パーサ経由で動くよう移植する。

## Why tree-sitter?
- OCaml 標準ライブラリは OCaml 専用で TypeScript は読めない
- tree-sitter は多言語を同一インターフェースでパースする
- 循環的複雑度・ネスト深度・関数長は構文情報だけで計算でき、型解決を必要としない

## TODO

### tree-sitter Setup
- [ ] tree-sitter 本体のインストール
- [ ] tree-sitter-typescript 文法のセットアップ
- [ ] OCaml から tree-sitter を呼ぶバインディングの調査
  - [ ] 既存の OCaml バインディング（ocaml-tree-sitter 等）の有無を確認
  - [ ] なければ C バインディング / FFI の方針を決める
- [ ] dune で C ライブラリとリンクするビルド構成を作る

### FFI / Binding
- [ ] OCaml の FFI（`external` 宣言、`ctypes` ライブラリ）の基本を理解する
- [ ] tree-sitter の C API を OCaml から呼べる最小サンプルを作る
- [ ] パーサの初期化・ソースの読み込み・ツリーの取得ができる
- [ ] ノードの型名・子ノード・位置情報にアクセスできる

### Tree Structure Understanding
- [ ] TypeScript のソースをパースし、ノード構造をダンプする
- [ ] tree-sitter のノード型（named node, anonymous node）の違いを理解する
- [ ] TypeScript の関数定義に対応するノード型を特定する
  - [ ] `function_declaration`
  - [ ] `arrow_function`
  - [ ] `method_definition`
- [ ] 分岐構文に対応するノード型を特定する
  - [ ] `if_statement`
  - [ ] `for_statement` / `for_in_statement` / `for_of_statement`
  - [ ] `while_statement`
  - [ ] `switch_case`
  - [ ] `catch_clause`
  - [ ] `ternary_expression`
  - [ ] `binary_expression` (`&&`, `||`, `??`)

### Logic Migration
- [ ] フェーズ1の走査ロジックを tree-sitter のツリーに対して動くよう移植する
- [ ] 入力インターフェースを抽象化し、パーサの差し替えが容易な設計にする
- [ ] TypeScript の関数に対して循環的複雑度を計算できることを確認する

## Deliverables
- [ ] 単一の `.ts` ファイルをパースし、AST ノード構造をダンプできる最小プログラム
- [ ] TypeScript の関数に対して循環的複雑度を計算できる CLI

## Completion Criteria
- [ ] 入力部（パーサ）の差し替えで指標ロジックが別言語でも再利用できることを実証した
- [ ] tree-sitter の「言語非依存なツリー表現」という設計思想を説明できる
- [ ] FFI（OCaml から C ライブラリを呼ぶ）の基本的な仕組みを理解した
- [ ] 構文ベース解析と型ベース解析の違い、今回なぜ構文ベースで十分かを説明できる

## Notes
- **このフェーズが技術的な最大の山場** — FFI とビルド構成で詰まりやすい
- tree-sitter は構文だけを見るため、型情報は取れない
- 未使用変数の厳密検出など型が要る解析は対象外と割り切る
