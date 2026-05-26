# Phase 1 / 05 — Nesting Depth (Optional)

## Goal
関数ごとの「最大ネスト深度」を計算する。アキュムレータに **環境（現在のネスト深度）** を持たせる走査パターンを掴む。Phase 3 の Cognitive Complexity の予行演習。

## Prerequisites
- [04 Cyclomatic Complexity](04-cyclomatic-complexity.md) 完了

## Steps

### 1. 「ネスト」を何で数えるか定義する

ここでは「分岐構文の入れ子の深さ」とする。
- `if`、`match`、`while`、`for`、`try` に入ると深さ +1
- 関数本体の最上位は 0
- 同じ階層に並ぶ分岐は同じ深さ

### 2. 状態付き走査

`Ast_traverse.fold` はアキュムレータが 1 つだが、それを「`(current_depth, max_depth)` のタプル」にできる。

```ocaml
open Ppxlib

type state = { current : int; max_seen : int }
let bump s = { current = s.current + 1; max_seen = max s.max_seen (s.current + 1) }

let is_nesting_node (e : expression) =
  match e.pexp_desc with
  | Pexp_ifthenelse _
  | Pexp_match _
  | Pexp_try _
  | Pexp_while _
  | Pexp_for _ -> true
  | _ -> false
```

ただし `Ast_traverse.fold` は **同じアキュムレータを子間で共有しつつ伝播する**。今回欲しいのは「子を見るときだけ深さを +1 にして、戻ってきたら元に戻す」というスコープ付き挙動。

### 3. fold で手書きする方が素直なケース

このパターンは visitor よりも **手書き再帰** の方が読みやすい。

```ocaml
let rec max_depth ?(depth=0) (e : expression) : int =
  let here = if is_nesting_node e then depth + 1 else depth in
  let child_depth = if is_nesting_node e then depth + 1 else depth in
  let children = collect_children e in
  List.fold_left (fun acc child ->
    max acc (max_depth ~depth:child_depth child)
  ) here children

and collect_children (e : expression) : expression list =
  match e.pexp_desc with
  | Pexp_ifthenelse (c, t, e_opt) ->
      [c; t] @ (match e_opt with Some e -> [e] | None -> [])
  | Pexp_match (e, cases) | Pexp_try (e, cases) ->
      e :: List.map (fun c -> c.pc_rhs) cases
  | Pexp_while (c, b) -> [c; b]
  | Pexp_for (_, a, b, _, body) -> [a; b; body]
  | Pexp_let (_, vbs, body) ->
      body :: List.map (fun vb -> vb.pvb_expr) vbs
  | Pexp_apply (f, args) -> f :: List.map snd args
  | Pexp_sequence (a, b) -> [a; b]
  | Pexp_fun (_, _, _, body) -> [body]
  | _ -> []
```

`collect_children` は **拾い漏れがある**前提で進める。後で出てきたら足す。

### 4. 関数ごとに記録

`fn_info` に `max_nesting : int` を追加して、`max_depth body` を呼ぶ。

### 5. テスト

```ocaml
let flat x = x + 1                        (* depth 0 *)

let one x = if x > 0 then 1 else 0        (* depth 1 *)

let nested x y =                          (* depth 2 *)
  if x > 0 then
    if y > 0 then 1 else 0
  else 0

let triple x y z =                        (* depth 3 *)
  if x > 0 then
    if y > 0 then
      if z > 0 then 1 else 0
    else 0
  else 0
```

## Verification

- [ ] 「分岐なし」関数で depth = 0
- [ ] `if` 1 つで depth = 1
- [ ] `if` ネスト N で depth = N
- [ ] `match` と `if` を混ぜたケースで期待通り

## Pitfalls / Tips
- `collect_children` の網羅が甘いと深さを過小評価する。出力がおかしいときはまずここを疑う
- 「並列の分岐」は深くならない（同じ階層）
- このコードは Phase 3 の Cognitive Complexity で再利用する形にしておくと楽

## Outputs
- 関数ごとに「最大ネスト深度」を出す機能の追加

## Next
- [06 CLI Integration](06-cli-integration.md)
