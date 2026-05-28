---
date: 2026-05-26
phase: phase0
category: learning
tags: [ocaml, opam, switch, environment]
---

# opam の switch — コンパイラ込みの環境切り替え

## コンテキスト
Phase 0 入り口。「opam とは何か」を理解する過程で学習者自身が辿り着いた理解。

## 学んだこと

### 核となる理解
opam はライブラリだけでなく **OCaml コンパイラ本体のバージョン** も管理対象とする。
その単位が **switch（スイッチ）** と呼ばれる。

他言語との対比:
| 言語 | コンパイラ/処理系の切替 | ライブラリ管理 |
|------|------------------------|----------------|
| Python | pyenv | pip / venv |
| Node | nvm / volta | npm / yarn |
| Ruby | rbenv | bundler |
| **OCaml** | **opam switch（同一ツール）** | **opam install（同一ツール）** |

→ OCaml は **「処理系の切替」と「ライブラリ管理」を opam ひとつに統合** しているのが特徴。

### switch の実体
- グローバル switch: `~/.opam/<switch名>/` にコンパイラもライブラリも格納される
- ローカル switch: プロジェクトディレクトリに `_opam/` を作って分離可能
  - 作成例: `opam switch create . <ocaml-version>`
  - 感覚としては Node の `node_modules` に近いプロジェクト分離

### なぜ phase0 で最初に触るのか
- OCaml の世界では「どの switch を有効化しているか」で利用できるコンパイラもパッケージも変わる
- ここを曖昧にすると後で「ビルドが通らない」「他人と環境差で詰まる」原因になる
- だから phase0 の最初のチェックポイントとして環境を固める

## 残した宿題（深掘り保留）
- opam のライブラリバージョン解決ロジック（他言語と異なるらしい点）
  → [notes/hints/2026-05-26-opam-version-resolution.md](../hints/2026-05-26-opam-version-resolution.md) に伏線として記録

## 関連リンク
- [質問の起点](../questions/2026-05-26-phase0-what-is-opam.md)
- [roadmap/phase0-ocaml-basics.md](../../roadmap/phase0-ocaml-basics.md)
- [procedure/phase0/01-environment-setup.md](../../procedure/phase0/01-environment-setup.md)
- 公式 switch ドキュメント: https://opam.ocaml.org/doc/Usage.html#opam-switch
