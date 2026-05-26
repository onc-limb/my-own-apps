# Phase 1 / 01 — AST Understanding

## Goal
`ppxlib` を使って OCaml ソースを AST にパースし、ノードの型と構造を「目で見て」理解する。

## Prerequisites
- Phase 0 完了
- `dune` プロジェクトを作れる

## Steps

### 1. プロジェクト作成

```
ariadne/
├── dune-project
└── bin/
    ├── dune
    └── ast_dump.ml
```

`dune-project`:
```
(lang dune 3.0)
```

`bin/dune`:
```
(executable
 (name ast_dump)
 (libraries ppxlib))
```

### 2. ppxlib のインストール

```bash
opam install -y ppxlib
```

### 3. 最小ダンプコード

`bin/ast_dump.ml`:
```ocaml
let () =
  let src = {|
    let add x y = x + y
    let _ = add 1 2
  |} in
  let lexbuf = Lexing.from_string src in
  let structure = Ppxlib.Parse.implementation lexbuf in
  Format.printf "%a@." Ppxlib.Pprintast.structure structure;
  Format.printf "----@.";
  Format.printf "%s@." (Ppxlib.Astlib.Pprintast.string_of_structure structure)
```

`dune exec ./bin/ast_dump.exe` で表示される。

### 4. 構造をダンプして観察する

`Pprintast` は人間向けのソース再構成。AST そのものを見るには次を使う。

```ocaml
let () =
  let src = "let add x y = x + y" in
  let structure = Ppxlib.Parse.implementation (Lexing.from_string src) in
  List.iter (fun item ->
    Format.printf "%a@." Ppxlib.Pprintast.structure_item item
  ) structure
```

さらに詳しい型構造は `Ppxlib.Ast.show_structure` 系のショウ関数や、`ocaml -dparsetree` でも見られる。

```bash
echo 'let add x y = x + y' | ocaml -stdin -dparsetree
```

### 5. ノード型の関係を把握する

最低限おさえる型を整理する。`Ppxlib.Ast` のドキュメントを開きながら、自分のメモ（`playground/cheatsheet.md`）に書き写す。

| 型 | 役割 | 代表的なコンストラクタ |
|----|------|------------------------|
| `structure` | トップレベル定義のリスト | （`structure_item` のリスト） |
| `structure_item` | 1 つのトップレベル要素 | `Pstr_value`, `Pstr_type` |
| `value_binding` | `let p = e` の片側 | `pvb_pat`, `pvb_expr` |
| `expression` | 式 | `Pexp_ifthenelse`, `Pexp_match`, `Pexp_apply`, `Pexp_let` |
| `pattern` | パターン | `Ppat_var`, `Ppat_construct` |
| `Location.t` | 位置情報 | `loc_start.pos_lnum`, `loc_end.pos_lnum` |

### 6. 自分で触って確かめる

入力ソースを少しずつ変えて、対応する AST がどう変わるか観察する。
- `if then else` を入れる → `Pexp_ifthenelse`
- `match` を入れる → `Pexp_match` + ケース配列
- `let rec` → `pvb_expr` の中に `Pexp_fun` が並ぶ

## Verification

- [ ] 1 行の OCaml コードを与えると `structure_item -> expression` までを口頭で説明できる
- [ ] `Location.t` から行番号を取り出すコードを 1 行で書ける（`loc.loc_start.pos_lnum`）
- [ ] `Pexp_ifthenelse` のコンストラクタが 3 引数（cond / then / else option）であることを確認した
- [ ] AST のダンプを眺めて、ソースとの対応がイメージできる

## Pitfalls / Tips
- `ppxlib` の AST 型は巨大 — 必要なものだけ拾えばよい
- `compiler-libs` でも同じことはできるが、`ppxlib` の方がドキュメントが揃っている
- 人間用整形（`Pprintast`）と AST ダンプは別物。両方触ると理解が早い

## Outputs
- `bin/ast_dump.ml` — 任意のソースを AST に変換して整形出力する CLI

## Next
- [02 Recursive Traversal](02-recursive-traversal.md)
