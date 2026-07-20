# Phase 0 — OCaml Basics & Development Environment

> **Goal:** OCaml の言語そのものに慣れ、ビルド・パッケージ管理の足回りを整える。

## TODO

### Environment Setup
- [x] opam をインストール・初期化する
- [x] dune をインストールする
- [x] utop（対話環境）をインストールする
- [x] エディタの OCaml 拡張を設定する（ocaml-lsp-server, merlin）
- [x] dune で「Hello World」プロジェクトをビルド・実行できる状態にする

### Language Fundamentals
- [x] `let` 束縛と不変性を理解する
- [x] 関数定義（名前付き引数、ラベル引数含む）を書ける
- [x] 再帰関数を書ける（リスト処理: map, filter, fold）
- [x] タプルとレコード型を使える
- [ ] 代数的データ型（ADT）を定義できる
  - [ ] `type expr = Int of int | Add of expr * expr` のような再帰 ADT
  - [ ] `match` で網羅的にパターンマッチできる
  - [ ] コンパイラの網羅性チェック警告を理解・対処できる
- [ ] `Option` 型によるnull安全な値の表現
- [ ] `Result` 型によるエラーハンドリング
- [ ] 例外（`raise`, `try ... with`）と `Result` の使い分け方針を持つ

### Module System
- [ ] モジュールの基本（`module M = struct ... end`）
- [ ] モジュールシグネチャ（`.mli` ファイル）
- [ ] ファンクタの基本概念を理解する

### Practice
- [ ] リスト処理の練習問題を解く
- [ ] 簡単な式評価器を ADT + パターンマッチで実装する
- [ ] 自分用の OCaml チートシートを作成する

## Deliverables
- [ ] dune でビルドできる Hello World プロジェクト
- [ ] 練習問題の解答コード群
- [ ] OCaml チートシート

## Completion Criteria
- [ ] ADT を自分で定義し、`match` で網羅的に分解できる
- [ ] 「不正な状態を表現不能にできる」理由を自分の言葉で説明できる
- [ ] `dune build` / `dune exec` / `opam install` が手に馴染んでいる
- [ ] 例外と `Result` の使い分けの方針を持っている

## Notes
- Windows の場合は WSL2 上で行うのが最も摩擦が少ない
- 「再帰とパターンマッチで考える」発想の転換に時間がかかるのは正常
