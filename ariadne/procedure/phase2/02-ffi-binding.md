# Phase 2 / 02 — FFI / Binding

## Goal
OCaml から tree-sitter の C API を呼べる薄いバインディングを書く。ctypes による FFI の基本（型対応、ポインタ、文字列、dune でのリンク）を体で覚える。

## Prerequisites
- [01 tree-sitter Setup](01-tree-sitter-setup.md) 完了
- C のサンドボックスでパース結果を確認済み

## Steps

### 1. ライブラリディレクトリ作成

```
lib/treesitter/
├── dune
├── stubs.c          (必要に応じて。今回は ctypes-foreign で省略)
└── binding.ml
```

`lib/treesitter/dune`:
```
(library
 (name ts_binding)
 (libraries ctypes ctypes-foreign)
 (c_library_flags (-ltree-sitter))
 (foreign_archives ts_typescript))
```

`tree-sitter-typescript` を `libts_typescript.a` にまとめてプロジェクトに同梱する形にする（CI で再現性が高い）。

### 2. 外部スキャナ・パーサのアーカイブ化

```bash
cd vendor/tree-sitter-typescript/typescript
cc -fPIC -c -I src src/parser.c src/scanner.c
ar rcs libts_typescript.a parser.o scanner.o
```

これを dune の `foreign_archives` で拾うか、`ariadne/lib/treesitter/` にコピーする。

### 3. ctypes でバインディング

`lib/treesitter/binding.ml`:
```ocaml
open Ctypes
open Foreign

(* opaque pointers *)
let parser_t : unit ptr typ = ptr void
let tree_t : unit ptr typ = ptr void
let language_t : unit ptr typ = ptr void

(* TSNode は構造体（値型）。最初は ts_node_string 経由で文字列にして使う *)
(* もし TSNode の中身を扱うなら view を別途定義する *)

let ts_parser_new = foreign "ts_parser_new" (void @-> returning parser_t)
let ts_parser_delete = foreign "ts_parser_delete" (parser_t @-> returning void)
let ts_parser_set_language =
  foreign "ts_parser_set_language" (parser_t @-> language_t @-> returning bool)

let ts_parser_parse_string =
  foreign "ts_parser_parse_string"
    (parser_t @-> ptr void @-> string @-> uint32_t @-> returning tree_t)

let ts_tree_delete = foreign "ts_tree_delete" (tree_t @-> returning void)

(* tree-sitter-typescript 由来 *)
let tree_sitter_typescript =
  foreign "tree_sitter_typescript" (void @-> returning language_t)
```

### 4. 最小の動作確認

`lib/treesitter/binding.ml` に試験用 main を一時的に書いてもよいが、後で `bin/` に移す前提で書く。

```ocaml
let parse_to_root_string (src : string) : string =
  let p = ts_parser_new () in
  let lang = tree_sitter_typescript () in
  let _ = ts_parser_set_language p lang in
  let tree =
    ts_parser_parse_string p null src (Unsigned.UInt32.of_int (String.length src))
  in
  (* TSNode 構造体を扱うため、ノード API 用の関数を追加で foreign 宣言する *)
  ignore tree; ignore p;
  "TODO: implement node string via TSNode struct"
```

ここで本質的に必要なのが「**TSNode 構造体の OCaml 表現**」。`TSNode` は 4 つのポインタ／整数を持つ値型構造体で、`ctypes` の `structure` で写像する。

```ocaml
let ts_node : [ `TSNode ] structure typ = structure "TSNode"
let ctx0 = field ts_node "context_0" uint32_t
let ctx1 = field ts_node "context_1" uint32_t
let ctx2 = field ts_node "context_2" uint32_t
let ctx3 = field ts_node "context_3" uint32_t
let id_  = field ts_node "id" (ptr void)
let tree_ = field ts_node "tree" (ptr void)
let () = seal ts_node
```

これで `ts_tree_root_node` / `ts_node_string` / `ts_node_type` / `ts_node_named_child_count` / `ts_node_named_child` を foreign 宣言できる。

### 5. ノードを扱う最小 API

```ocaml
let ts_tree_root_node =
  foreign "ts_tree_root_node" (tree_t @-> returning ts_node)

let ts_node_type =
  foreign "ts_node_type" (ts_node @-> returning string)

let ts_node_named_child_count =
  foreign "ts_node_named_child_count" (ts_node @-> returning uint32_t)

let ts_node_named_child =
  foreign "ts_node_named_child" (ts_node @-> uint32_t @-> returning ts_node)

let ts_node_start_point =
  foreign "ts_node_start_point" (ts_node @-> returning ts_point)
(* ts_point は struct { row: uint32_t; column: uint32_t } *)

let ts_node_end_point =
  foreign "ts_node_end_point" (ts_node @-> returning ts_point)
```

### 6. OCaml らしいラッパに包む

ctypes のままだと使いにくいので、上位 API を作る。

```ocaml
module Node : sig
  type t
  val kind : t -> string
  val start_line : t -> int
  val end_line : t -> int
  val children : t -> t list
end
```

これを Phase 1 で作った「指標ロジック」が呼ぶ。**指標ロジック側はこの抽象に依存し、tree-sitter 直接の関数を呼ばない** ようにする（これが [04 Logic Migration](04-logic-migration.md) の核）。

## Verification

- [ ] `dune build` がリンクエラー無く通る
- [ ] 簡単な TypeScript ソースをパースして root node の `kind` が `program` と表示される
- [ ] 名前付き子ノードの `kind` が `function_declaration` などとして取れる
- [ ] `start_point.row` / `end_point.row` が期待通り

## Pitfalls / Tips
- TSNode は値型 — OCaml で扱うときも値として持ち回る（ポインタにしない）
- `Unsigned.UInt32` 変換忘れに注意
- リンクエラーで `tree_sitter_typescript` が未定義になるのは、`parser.c`/`scanner.c` のアーカイブが組み込まれていない典型例
- `string` で受け渡しすると ctypes が NUL 終端を仮定する。TypeScript ソースに NUL が入る可能性はゼロに近いが、厳密にやるなら `bytes` + 長さ指定

## Outputs
- `lib/treesitter/` — ts_binding ライブラリ
- ノード抽象（`Node` モジュール）

## Next
- [03 Tree Structure Understanding](03-tree-structure-understanding.md)
