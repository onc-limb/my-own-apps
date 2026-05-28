---
date: 2026-05-26
phase: phase0
category: hint
tags: [ocaml, opam, version-resolution, deferred]
status: deferred
---

# opam のライブラリバージョン解決（深掘り保留）

## なぜここに残しているか
Phase 0 の opam 入門時、学習者が「ライブラリのバージョン解決方法も他とは異なるらしい」と
触れたうえで、今は深掘りせず先に進む判断をした。
**先に進むのは正しい判断**。ただし戻ってくるべきタイミングがあるので伏線として残す。

## 戻ってくるべきタイミング
以下のいずれかが起きたら、このノートに戻って深掘りすること。

- [ ] `opam install` で「コンフリクト」や「unsatisfiable constraints」エラーに遭遇した
- [ ] 同じパッケージなのに switch を変えると挙動が変わって混乱した
- [ ] phase4 以降で他人の環境と差分が出てビルドが通らない事象が出た
- [ ] phase5 で CI 環境を組むときに switch を固定する必要が出た

## 深掘り時に調べるべきキーワード（ヒント）
答えは見ない。以下のキーワードで検索し、自分で読み解くこと。

- **opam の SAT ソルバー** — npm/pip と違って制約充足問題として解く
- **`opam.lock` / `opam.locked`** — ロックファイルの作法（npm の package-lock.json に相当）
- **`dune-project` の `depends`** vs **`<package>.opam` の `depends`** — どっちが本物？
- **`opam pin`** — リポジトリ未公開バージョンを使いたいとき
- **flexible vs lockfile-based installation** — 開発時と CI 時の使い分け

## 自問用テンプレ（戻ってきたとき用）
1. 自分が今ぶつかっているエラーは「制約が矛盾している」のか「ロックされていない」のか？
2. プロジェクトの依存は `dune-project` と `*.opam` のどちらに書かれているか？
3. 同じ状態を他環境で再現するには、何を共有すれば足りるか？

## 関連
- [opam switch の理解](../learnings/2026-05-26-phase0-opam-switch-concept.md)
- 公式 Solver: https://opam.ocaml.org/doc/Manual.html#Common-file-format
