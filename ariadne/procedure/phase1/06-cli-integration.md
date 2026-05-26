# Phase 1 / 06 — CLI Integration

## Goal
ここまでの指標計算を「コマンドラインツール」として動く形に整える。引数受け取り、エラーハンドリング、出力整形を最低限の品質で済ませる。

## Prerequisites
- [05 Nesting Depth](05-nesting-depth.md) 完了（または飛ばしてもよい）

## Steps

### 1. 引数受け取り

最小は `Sys.argv` で十分。`Arg` モジュールを使うと優しい。

```ocaml
let () =
  let path = ref None in
  let speclist = [] in
  let anon p = path := Some p in
  Arg.parse speclist anon "usage: ariadne <file.ml>";
  match !path with
  | None -> prerr_endline "missing input file"; exit 2
  | Some p -> run p
```

将来 `--threshold` や `--format` を増やす想定なので `Arg` 化しておく。

### 2. ファイル読み込みのエラー処理

```ocaml
let load_file path =
  try
    let ic = open_in path in
    let len = in_channel_length ic in
    let s = really_input_string ic len in
    close_in ic;
    Ok s
  with Sys_error msg -> Error msg
```

`Result` で返し、上位で `match` する。`exit 2` の系統を確立する（後の CI 用）。

### 3. パースエラーのハンドリング

`Ppxlib.Parse.implementation` は構文エラーで例外を投げる。

```ocaml
let parse path src =
  let lexbuf = Lexing.from_string src in
  Lexing.set_filename lexbuf path;
  try Ok (Ppxlib.Parse.implementation lexbuf)
  with
  | Syntaxerr.Error _ as e ->
      Error (Printf.sprintf "parse error: %s" (Printexc.to_string e))
```

### 4. 出力整形

整列するだけの簡易テーブル。
```ocaml
let print_header () =
  Printf.printf "%-30s %6s %6s %6s %6s\n" "function" "start" "end" "lines" "cc"

let print_row f =
  Printf.printf "%-30s %6d %6d %6d %6d\n" f.name f.start_line f.end_line f.lines f.cyclomatic
```

### 5. 終了コードのルール

| 状況 | exit code |
|------|-----------|
| 正常 | 0 |
| ファイルが無い / 引数間違い | 2 |
| パースエラー | 2 |
| しきい値超過（Phase 4 で導入） | 1 |

Phase 4 で `--threshold` を入れたとき変えやすいよう、main 関数の終わりで `exit code` を呼ぶ形にしておく。

### 6. 全体構造

```
bin/
  main.ml         — CLI 入り口（Arg / 引数バリデーション / exit code）
lib/
  parse.ml        — Lexing + Ppxlib.Parse のラップ
  metrics.ml      — fn_info 型 / collect_functions / cyclomatic 計算
  report.ml       — 整形出力
```

`lib/dune`:
```
(library
 (name ariadne)
 (libraries ppxlib))
```

`bin/dune`:
```
(executable
 (name main)
 (libraries ariadne))
```

将来 `cmdliner` などへ差し替えやすい構造にしておく。

## Verification

- [ ] `dune exec ./bin/main.exe -- tests/sample_cc.ml` で表が出る
- [ ] 存在しないファイルを指定すると分かりやすいエラーで exit 2
- [ ] 構文エラーのあるファイルを与えても落ちずに exit 2 で抜ける
- [ ] `bin/` と `lib/` が分離されていて、`lib/` 単体でテスト可能な構造になっている

## Pitfalls / Tips
- `exit 0/1/2` の意味は Phase 4-5 で重要になる。ここで一度決めておく
- 整形は ASCII で十分。色付きは Phase 3 / 4 で考える
- `lib/` に切り出しておくと、Phase 2 の tree-sitter 移行で「指標ロジックは触らずパーサ層だけ差し替える」ができる

## Outputs
- `bin/main.ml` — CLI 本体
- `lib/` — パース層と指標層の分離
- Phase 1 完了の証拠としての `.ml` ファイル指標出力

## Next
- Phase 1 完了。roadmap の Completion Criteria を確認
- [Phase 2 / 01 tree-sitter Setup](../phase2/01-tree-sitter-setup.md)
