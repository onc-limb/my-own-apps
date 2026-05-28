---
date: 2026-05-26
phase: phase0
category: learning
tags: [ocaml, opam, shell, environment, path]
---

# `eval $(opam env)` の意味と設定方法

## コンテキスト
Phase 0 環境構築の手順内に登場する `eval $(opam env)` というおまじない。
これが「何を、なぜ、どう設定するのか」を理解する。

## 学んだこと

### `opam env` の正体
- 単独で叩くと **shell コマンド形式のテキスト** を標準出力に吐くだけ
- 中身は `PATH`, `OPAM_SWITCH_PREFIX`, `CAML_LD_LIBRARY_PATH`, `OCAML_TOPLEVEL_PATH` などの `export` 文
- これ自体は実行されていない。あくまで「shell に流し込むためのテキスト」

### `eval $(opam env)` の役割
- `$(opam env)` で出力をキャプチャ
- `eval` で現在の shell のコマンドとして実行
- 結果として現在のシェルに環境変数がセットされる

### なぜ必要か
opam switch は隔離環境で、コンパイラやツール（`ocaml`, `ocamlc`, `dune` 等）は
`~/.opam/<switch>/bin/` 配下に入っている。
デフォルト PATH にはこのパスがないので、 **eval しないと `command not found` になる**。

| 状態 | `dune` 実行 |
|------|------------|
| `eval $(opam env)` 前 | command not found |
| `eval $(opam env)` 後 | 現在の switch の dune が起動 |

`OPAM_SWITCH_PREFIX` は OCaml コンパイラがライブラリを探す場所を示すのにも使われる。

### 設定方法
| 方法 | コマンド | 効果 |
|------|----------|------|
| 一時的 | `eval $(opam env)` をシェルで実行 | そのセッションのみ |
| 恒久的（手動） | `~/.zshrc` か `~/.bashrc` に上記を追記 | 新規シェル毎に自動適用 |
| 恒久的（自動） | `opam init` 時に "yes" と答える | opam が自動で rc に追記してくれる |

### switch 切り替え時の注意
`opam switch <別の名前>` で switch を変えたら **再度 `eval $(opam env)` する必要がある**。
古い switch のパスがそのままセットされているため。opam 自体も警告メッセージで促してくれることが多い。

## 落とし穴
1. **新しい端末で効かない** — `.zshrc` 等に書いていない or `opam init` してない
2. **VSCode/CI で効かない** — ログインシェルではない場合 `.zshrc` が読まれない。IDE 側の設定や OCaml 拡張に頼る
3. **switch 変えたのに古い ocaml が動く** — `eval $(opam env)` 再実行漏れ。`which ocaml` で実体確認する癖を

## 確認手順（手を動かす）
```bash
opam env                              # テキストを観察
which ocaml                           # eval 前の状態
eval $(opam env)
which ocaml                           # eval 後、~/.opam/... に変わる
echo $PATH | tr ':' '\n' | head -5    # PATH 先頭に opam の bin があるか
```

「自分の目で `which` の出力差分を見る」のが理解の決め手。

## 関連
- [opam switch の理解](2026-05-26-phase0-opam-switch-concept.md)
- [procedure/phase0/01-environment-setup.md](../../procedure/phase0/01-environment-setup.md)
- 公式: https://opam.ocaml.org/doc/Usage.html
