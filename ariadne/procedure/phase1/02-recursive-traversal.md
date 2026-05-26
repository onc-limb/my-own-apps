# Phase 1 / 02 — Recursive Traversal

## Goal
AST を再帰的に降りながら「興味のあるノードだけ拾い、他はスルー」する走査パターンを身につける。`Ast_traverse` クラスの存在意義を理解する。

## Prerequisites
- [01 AST Understanding](01-ast-understanding.md) 完了

## Steps

### 1. 素朴な再帰関数で走査する

まず手書きで書く。例として「`Pexp_ifthenelse` の出現箇所を数える」関数。

```ocaml
open Ppxlib

let rec count_if_expr (e : expression) : int =
  let here = match e.pexp_desc with
    | Pexp_ifthenelse _ -> 1
    | _ -> 0
  in
  let children =
    match e.pexp_desc with
    | Pexp_ifthenelse (c, t, e_opt) ->
        count_if_expr c + count_if_expr t +
        (match e_opt with Some e -> count_if_expr e | None -> 0)
    | Pexp_let (_, vbs, body) ->
        List.fold_left (fun acc vb -> acc + count_if_expr vb.pvb_expr) 0 vbs
        + count_if_expr body
    | Pexp_apply (f, args) ->
        count_if_expr f + List.fold_left (fun acc (_, a) -> acc + count_if_expr a) 0 args
    | _ -> 0
  in
  here + children

let count_if_structure (s : structure) : int =
  List.fold_left (fun acc item ->
    match item.pstr_desc with
    | Pstr_value (_, vbs) ->
        acc + List.fold_left (fun a vb -> a + count_if_expr vb.pvb_expr) 0 vbs
    | _ -> acc
  ) 0 s
```

ここで気づくはず — **網羅していないコンストラクタの子に if が入っていると数え漏れる**。これを毎ケース手で書くのは現実的でない。

### 2. `Ast_traverse` で同じことをする

`ppxlib` には visitor クラス `Ast_traverse.fold` がある。

```ocaml
open Ppxlib

let if_counter = object
  inherit [int] Ast_traverse.fold as super
  method! expression e acc =
    let acc' =
      match e.pexp_desc with
      | Pexp_ifthenelse _ -> acc + 1
      | _ -> acc
    in
    super#expression e acc'
end

let count_if (s : structure) : int =
  if_counter#structure s 0
```

- `super#expression` を呼ぶことで「子ノードに自動で降りる」
- 興味のあるノードだけ `method!` で上書きすればよい
- 「全コンストラクタを手で書く」苦行から解放される

### 3. 走査クラスのバリエーション

`Ast_traverse` には複数あるので使い分けを知っておく。

| クラス | 目的 |
|--------|------|
| `iter` | 副作用付きで走査（蓄積したいものはmutableで持つ） |
| `fold` | アキュムレータを引き回して走査 |
| `map` | AST を変換する（PPX 用途） |
| `fold_map` | 変換しながら蓄積 |

このプロジェクトでは **`fold` か `iter`** を使う。`map` は AST を書き換えるとき用。

### 4. 「興味のあるノードだけ拾う」設計の練習

次の小タスクを `Ast_traverse.fold` で実装する。

- 関数定義（`Pexp_fun` を持つ `value_binding`）の名前一覧を返す
- 各関数の `Location.t` を返す

```ocaml
let function_locations = object
  inherit [(string * Location.t) list] Ast_traverse.fold as super
  method! value_binding vb acc =
    let name =
      match vb.pvb_pat.ppat_desc with
      | Ppat_var ident -> Some ident.txt
      | _ -> None
    in
    let acc' =
      match name, vb.pvb_expr.pexp_desc with
      | Some n, Pexp_fun _ -> (n, vb.pvb_loc) :: acc
      | _ -> acc
    in
    super#value_binding vb acc'
end
```

### 5. アキュムレータ設計の感覚

- 単純な数 → `int`
- 関数ごとの結果が欲しい → `(name * value) list` を蓄積
- 親情報を子に伝える必要が出たら → fold のアキュムレータを「環境付き」にする（後の Cognitive Complexity で再登場）

## Verification

- [ ] `Ast_traverse.fold` で「特定ノードだけカウント」する visitor を書ける
- [ ] `super#expression` を呼ぶ／呼ばないでどう挙動が変わるか説明できる（呼ばないと子に降りない）
- [ ] 全コンストラクタを書かなくても良い理由を一言で説明できる（visitor が自動再帰）

## Pitfalls / Tips
- `method!` の `!` は「親メソッドを上書きしている」マーク。これを付けないと「未使用 method」警告が出る
- `super#expression e acc'` を呼び忘れると子に降りない（カウント漏れの典型原因）
- アキュムレータに「現在の関数名」のような環境を持たせるパターンは早めに練習しておく

## Outputs
- `bin/traverse_demo.ml` — `Ast_traverse.fold` の動作例
- 関数名と位置情報を抽出する visitor

## Next
- [03 First Metric: Lines of Code](03-loc-metric.md)
