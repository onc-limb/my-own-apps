# Phase 1 / 03 — First Metric: Lines of Code per Function

## Goal
OCaml ソースをパースし、**各関数定義について「関数名」と「行数」を出力する** プログラムを書く。指標ロジック書きの最初のリハーサル。

## Prerequisites
- [02 Recursive Traversal](02-recursive-traversal.md) 完了

## Steps

### 1. 関数定義をどう特定するか

OCaml で「関数」と呼ぶものはいくつかある。最小スコープを次に絞る。

- `let f x = ...` のように `value_binding` の右辺が `Pexp_fun` で始まるもの
- `let f x y = ...` も最終的に `Pexp_fun (..., Pexp_fun (...))` のネスト

最初は **`Pstr_value` 直下の `value_binding`** に限定する。ネストした local 関数（`let in` 内）は次フェーズで考える。

### 2. 行数の計算

`Location.t` は `loc_start.pos_lnum` と `loc_end.pos_lnum` を持つ。

```ocaml
let line_count (loc : Location.t) =
  loc.loc_end.pos_lnum - loc.loc_start.pos_lnum + 1
```

「+1」で「1 行関数を 1 と数える」ようにする。0 にすると気持ち悪い。

### 3. 走査の実装

```ocaml
open Ppxlib

type fn_info = {
  name : string;
  start_line : int;
  end_line : int;
  lines : int;
}

let extract_name (pat : pattern) : string option =
  match pat.ppat_desc with
  | Ppat_var ident -> Some ident.txt
  | _ -> None

let collect_functions (s : structure) : fn_info list =
  List.concat_map (fun item ->
    match item.pstr_desc with
    | Pstr_value (_, vbs) ->
        List.filter_map (fun vb ->
          match extract_name vb.pvb_pat, vb.pvb_expr.pexp_desc with
          | Some name, Pexp_fun _ ->
              let loc = vb.pvb_loc in
              Some {
                name;
                start_line = loc.loc_start.pos_lnum;
                end_line = loc.loc_end.pos_lnum;
                lines = loc.loc_end.pos_lnum - loc.loc_start.pos_lnum + 1;
              }
          | _ -> None
        ) vbs
    | _ -> []
  ) s
```

### 4. ファイルから読み込む

```ocaml
let load_file path =
  let ic = open_in path in
  let len = in_channel_length ic in
  let s = really_input_string ic len in
  close_in ic;
  s

let analyze path =
  let src = load_file path in
  let lexbuf = Lexing.from_string src in
  Location.input_name := path;
  Lexing.set_filename lexbuf path;
  Ppxlib.Parse.implementation lexbuf
```

`Lexing.set_filename` を呼ばないと、`Location.t` のファイル名が `_none_` になりエラーメッセージで困る。

### 5. 表示

```ocaml
let () =
  let path = Sys.argv.(1) in
  let structure = analyze path in
  let fns = collect_functions structure in
  Printf.printf "%-30s %6s %6s %6s\n" "function" "start" "end" "lines";
  List.iter (fun f ->
    Printf.printf "%-30s %6d %6d %6d\n" f.name f.start_line f.end_line f.lines
  ) fns
```

### 6. テスト用のサンプル

`tests/sample_loc.ml`:
```ocaml
let add x y = x + y

let big x =
  let a = x + 1 in
  let b = a * 2 in
  let c = b - 3 in
  a + b + c
```

`dune exec ./bin/main.exe -- tests/sample_loc.ml` で 2 関数・期待行数が出ることを確認する。

## Verification

- [ ] 1 行関数の lines が 1
- [ ] N 行関数の lines が N（手で数えて一致）
- [ ] トップレベルの非関数（`let x = 1`）が結果に含まれていない
- [ ] 複数ファイルに対して同じプログラムが動く

## Pitfalls / Tips
- `let f = fun x -> ...` 形式も `Pexp_fun` なので拾える
- `let x = 1` は `Pexp_constant` なので除外される
- 行数は「ソースの行範囲」であり、コメントや空行も含む — それで OK。意図的なら別途定義する

## Outputs
- 単一の `.ml` ファイルを引数に取り、関数名と行数を表で出す CLI

## Next
- [04 Second Metric: Cyclomatic Complexity](04-cyclomatic-complexity.md)
