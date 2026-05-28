---
date: 2026-05-26
phase: phase0
category: question
tags: [ocaml, opam, tooling, package-manager]
---

# opam とは何か

## コンテキスト
Phase 0（OCaml 基礎・環境構築）の入り口。
roadmap/phase0-ocaml-basics.md および procedure/phase0/01-environment-setup.md で
opam という単語に最初に遭遇するタイミング。

## 質問 / 状況
「opam って何？」という素朴な質問。
他言語のパッケージマネージャ（npm, pip, cargo, gem 等）の経験は前提として持ち合わせている可能性が高い。

## 理解 / 解決（学習者の回答待ち。以下は誘導用のヒント観点）

### ヒントとして提示した3つの観点
1. **何を管理するか** — opam はライブラリだけでなく、**OCaml コンパイラ本体**も管理対象に含む。これは pip や npm にはない特徴。
2. **どこにインストールするか** — opam は「switch」という単位で隔離環境を作る。プロジェクトごと・コンパイラバージョンごとに独立した環境を持てる。
3. **switch（スイッチ）の概念** — Python の virtualenv + pyenv をひとつにまとめたような仕組み。OCaml コンパイラのバージョン × インストールされたパッケージ群、を切り替え単位とする。

### 学習者が回答したら追加で深掘りすべきポイント
- `opam switch` コマンドの存在
- `opam install <package>` と `dune` の関係（opam は配布、dune はビルド）
- グローバルスイッチとローカルスイッチ（プロジェクト内 `_opam`）の違い
- opam リポジトリは https://opam.ocaml.org/

## 関連リンク
- [roadmap/phase0-ocaml-basics.md](../../roadmap/phase0-ocaml-basics.md)
- [procedure/phase0/01-environment-setup.md](../../procedure/phase0/01-environment-setup.md)
- 公式: https://opam.ocaml.org/doc/Manual.html

## 次のアクション（学習者向け）
1. 上の3観点について自分の推測を答える
2. 答え合わせの後、procedure phase0 の environment-setup を読みながら `opam --version` や `opam switch list` を実際に叩いてみる
3. 何か詰まったら notes/stumbles/ に記録する
