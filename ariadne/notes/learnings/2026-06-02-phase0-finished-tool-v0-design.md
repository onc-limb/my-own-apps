---
date: 2026-06-02
phase: phase0
category: learning
tags: [ocaml, architecture-metrics, cyclomatic-complexity, tooling, dune]
---

# 完成ツール v0 の方針と設計判断

## コンテキスト
`/goal` で「TypeScript を対象に循環的複雑度などのアーキテクチャメトリクスを
計測する完成ツールが欲しい（学習とは別に、すぐ使えて改善しながら使いたい）」
という要求が出た。一方このリポジトリのルール（CLAUDE.md）は
「答えを出さない・コードは明示指示時のみ」のコーチモード。

## 住み分けの決定（ユーザー確認の結果）
学習トラックとツールトラックは速度も「誰が書くか」も真逆なので、確認して決めた。

- **完成ツール**: `tool/` に **OCaml** で Claude が構築・保守する。
  - すぐ実コードベースに回せる。
  - 動く実 OCaml コードを **お手本（ドッグフーディング対象）** として読める。
- **学習トラック** (`roadmap` / `procedure` / `notes`): コーチモードのまま、
  本人が自分で OCaml を書く。R-001/R-002 はこちらで引き続き有効。

→ つまり R-001/R-002 を緩めるのは `tool/` のみ。学習トラックは従来どおり。

## v0 の技術方針（なぜこうしたか）
- **tree-sitter FFI を使わない**。OCaml バインディングは 0.1.0 と未成熟で、
  C ライブラリ + 文法のコンパイルが要る重い構成。ロードマップも Phase 2 まで
  意図的に後回しにしている。「最初は簡単なものから積み上げる」設計思想に合わせ、
  v0 は **純 OCaml の手書き字句スキャナ方式**（外部依存ゼロ）にした。
- メトリクスロジックは言語非依存（分岐を数える発想は対象言語が変わっても同じ）。
- 精度が要る段階で tree-sitter フロントエンド（AST ベース）に差し替えられる構成。

## メトリクス定義（出典つき）
- **循環的複雑度 (McCabe)** = `1 + 分岐点数`。分岐点 = `if` `for` `while`
  `case` `catch` + 論理演算子 `&&` `||` `??`。`switch`/`else`/`default` は
  新しい経路を増やさないので数えない。
  出典: SonarSource "Cognitive Complexity" white paper (2017)。
- 次段で **認知的複雑度**（ネスト加重）と、import グラフから
  **Ca/Ce・不安定度 I=Ce/(Ca+Ce)・主系列からの距離 D**（Robert C. Martin,
  "OO Design Quality Metrics", 1994）を追加予定。

## v0 の既知の制限
- 三項演算子 `?:` は未カウント（`?.`/`??`/`x?:` と区別しにくく過大計上を避けた）。
- テンプレートリテラル `${}` 内の式は文字列扱い。
- 正規表現リテラル未対応（`/` は除算扱い）。
- 計測はファイル単位（関数単位は AST 導入後）。

## OCaml 学習者向けに読みどころ（お手本コード）
- `tool/lib/tokenizer.ml`: 状態機械を **バリアント型 + while ループ + ref** で
  書いた例。`match !state with ...` が中心。
- `tool/lib/scanner.ml`: `Fun.protect` で確実にファイルを閉じる / `List.filter_map`。
- `tool/bin/main.ml`: `cmdliner` の `Term.(const f $ arg1 $ arg2)` の組み立て方。

## 関連リンク
- tool/README.md
- ariadne/roadmap/README.md（学習トラックの設計思想）
- ariadne/procedure/phase1/04-cyclomatic-complexity.md
