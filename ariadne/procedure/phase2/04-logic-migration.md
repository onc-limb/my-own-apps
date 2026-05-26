# Phase 2 / 04 — Logic Migration

## Goal
Phase 1 で OCaml AST に対して書いた指標ロジック（LOC・CC）を、tree-sitter のツリーに対して動くように移植する。**パーサ差し替えで指標が再利用できる**設計を実証する。

## Prerequisites
- [03 Tree Structure Understanding](03-tree-structure-understanding.md) 完了
- 自分の手元にノード kind 対応表がある

## Steps

### 1. 抽象ノード型を定義する

Phase 1 のコードは `Ppxlib.Ast.expression` に直接触れていた。これを **言語非依存の中間表現** に置き換える。

`lib/ir/node.ml`:
```ocaml
type kind =
  | Function of { name : string option }
  | If
  | For
  | While
  | SwitchCase
  | TryCatch
  | Ternary
  | LogicalAnd
  | LogicalOr
  | NullishCoalescing
  | Other of string

type t = {
  kind : kind;
  start_line : int;
  end_line : int;
  children : t list;
}
```

これが「指標ロジックが見る世界」になる。

### 2. アダプタ層を作る

各パーサからこの IR を構築する関数を書く。

`lib/adapter/ts_adapter.ml`:
```ocaml
let rec of_ts_node (n : Ts_binding.Node.t) : Ir.Node.t =
  let kind = classify n in
  { kind;
    start_line = Ts_binding.Node.start_row n + 1;  (* tree-sitter は 0-origin *)
    end_line = Ts_binding.Node.end_row n + 1;
    children = List.map of_ts_node (Ts_binding.Node.named_children n);
  }

and classify (n : Ts_binding.Node.t) : Ir.Node.kind =
  match Ts_binding.Node.kind n with
  | "function_declaration" | "arrow_function" | "method_definition" ->
      Function { name = extract_name n }
  | "if_statement" -> If
  | "for_statement" | "for_in_statement" -> For
  | "while_statement" | "do_statement" -> While
  | "switch_case" -> SwitchCase
  | "catch_clause" -> TryCatch
  | "ternary_expression" -> Ternary
  | "binary_expression" ->
      (match Ts_binding.Node.field n "operator" with
       | Some "&&" -> LogicalAnd
       | Some "||" -> LogicalOr
       | Some "??" -> NullishCoalescing
       | _ -> Other "binary_expression")
  | k -> Other k
```

将来 OCaml 用のアダプタも `lib/adapter/ocaml_adapter.ml` として追加できる構造にしておく。

### 3. 指標ロジックを IR で書き直す

`lib/metrics/cyclomatic.ml`:
```ocaml
open Ir

let rec count_branches (n : Node.t) : int =
  let here =
    match n.kind with
    | If | For | While | SwitchCase | TryCatch | Ternary
    | LogicalAnd | LogicalOr | NullishCoalescing -> 1
    | _ -> 0
  in
  here + List.fold_left (fun acc c -> acc + count_branches c) 0 n.children

let of_function (n : Node.t) : int =
  1 + count_branches n  (* base 1 + branches inside body *)
```

`lib/metrics/loc.ml`:
```ocaml
open Ir

let of_function (n : Node.t) : int =
  n.end_line - n.start_line + 1
```

### 4. 関数の取り出し

```ocaml
let rec collect_functions (n : Ir.Node.t) : Ir.Node.t list =
  let here =
    match n.kind with
    | Ir.Node.Function _ -> [n]
    | _ -> []
  in
  here @ List.concat_map collect_functions n.children
```

### 5. パイプライン全体

`bin/main.ml`:
```ocaml
let analyze path =
  let src = In_channel.with_open_text path In_channel.input_all in
  let ts_tree = Ts_binding.parse src in
  let ir = Ts_adapter.of_ts_node (Ts_binding.root ts_tree) in
  let fns = Functions.collect ir in
  List.map (fun fn ->
    (fn, Loc.of_function fn, Cyclomatic.of_function fn)
  ) fns
```

Phase 1 と同じ表形式で出力する。

### 6. 入れ子の関数についての方針

`function_declaration` の中にさらに `arrow_function` がある場合、`collect_functions` がそのまま両方拾う。**内側の関数も独立にカウントする** ことになる（推奨）。
- 「外側の CC に内側を含めない」設計にしたい場合は、collect で取った関数の中で再帰しないように `count_branches` を書き換える
- どちらの方針を採るかを `ASSUMPTIONS.md` に明記する

### 7. パーサ差し替えが効くことの確認

Phase 1 の OCaml アダプタを書き、同じ `Cyclomatic.of_function` で OCaml ソースの CC が出ることを確認する（ここまでやれば「指標ロジックは言語非依存」を実証したことになる）。

時間が無ければ最低限「TypeScript で動く」だけで Phase 2 は閉じてよい。

## Verification

- [ ] 単一 `.ts` ファイルから関数ごとの CC が出る
- [ ] Phase 1 のサンプルと同じ「if 1 つで CC=2」「&& で +1」が tree-sitter 側でも成立する
- [ ] `Cyclomatic.of_function` のソース内に `ts_binding` への依存が一切ない（IR にだけ依存している）
- [ ] アダプタを `Ts_adapter` から差し替えれば OCaml ソースの解析もできる構造

## Pitfalls / Tips
- `binary_expression` の operator 取得を間違えると `&&` / `||` の加算が落ちる — 単体テスト推奨
- tree-sitter は 0-origin の行番号。OCaml 側で +1 して人間向け表示と揃える
- 「IR を厚く作りすぎない」— 指標で必要なノード種だけ第一級にする。それ以外は `Other`

## Outputs
- `lib/ir/` — 言語非依存ノード IR
- `lib/adapter/ts_adapter.ml` — TypeScript 用変換
- `lib/metrics/` — 言語非依存指標ロジック
- TypeScript ファイルに対して動く CLI

## Next
- Phase 2 完了。roadmap の Completion Criteria を確認
- [Phase 3 / 01 Comprehensive Branch Coverage](../phase3/01-comprehensive-branch-coverage.md)
