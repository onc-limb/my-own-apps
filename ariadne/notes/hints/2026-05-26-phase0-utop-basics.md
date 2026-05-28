---
date: 2026-05-26
phase: phase0
category: hint
tags: [ocaml, utop, repl]
---

# utop の基本操作

## コンテキスト
phase0 で OCaml の言語仕様を utop で試している最中、終了方法が分からなかった。

## 質問 / 状況
utop を抜けたいが、`exit` だけでは反応しない。`Ctrl+C` も効かない。

## 理解 / 解決

### 終了方法
| 方法 | 説明 |
|------|------|
| `#quit;;` | toplevel ディレクティブ。末尾の `;;` 必須 |
| `exit 0;;` | OCaml 標準ライブラリの関数で終了 |
| `Ctrl+D` | EOF を送る。一番手軽 |
| `Ctrl+C` | **入力中の式のキャンセル** だけで終了しない |

### toplevel ディレクティブとは
`#` から始まる行は OCaml の構文ではなく、REPL 固有の命令。

| ディレクティブ | 用途 |
|----------------|------|
| `#quit;;` | utop を終了 |
| `#use "foo.ml";;` | ファイルを読み込んで評価 |
| `#show_type int;;` | 型情報を表示 |
| `#show_val List.map;;` | 値の型シグネチャを表示 |
| `#require "pkg";;` | findlib 経由でパッケージをロード |
| `#directory "path";;` | 検索パス追加 |

`;;` は OCaml の **式の終端** を示す記号で、REPL では「ここまでで評価せよ」の合図。`.ml` ファイル中では原則不要（あっても無視される）。

## 関連リンク
- ariadne/procedure/phase0/02-language-fundamentals.md
- https://ocaml.org/manual/toplevel.html
