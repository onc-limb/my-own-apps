# Phase 1 / 04 — Cyclomatic Complexity

## Goal
OCaml の関数ごとに循環的複雑度（CC）を計算し、出力に追加する。CC の定義「1 + 分岐数」を、AST 上の具体的な数え方として実装に落とす。

## Prerequisites
- [03 LOC Metric](03-loc-metric.md) 完了

## Steps

### 1. CC の定義を文字にする

- ベース値: 1（関数に入った時点で経路 1 本）
- 以下のノードを **1 ずつ加算**:
  - `if then else` の `if` 1 つにつき 1
  - `match` の各ケース（最初を除く `n` ケースなら `n-1` 加算 / または「ケース数」加算）— **流儀がある**ので自分のルールを決める
  - `while` / `for` の 1 つにつき 1
  - `&&` / `||` の出現 1 つにつき 1（短絡 = 隠れた分岐）
  - `try ... with` の `with` 内パターン 1 つにつき 1

このプロジェクトでは **「ケース数で数える（最初も含めて）」** を採用する（McCabe オリジナル: ケース数 = 分岐数）。気が変わったら明文化して切り替える。

### 2. OCaml の分岐ノード一覧

| ノード | カウント |
|--------|----------|
| `Pexp_ifthenelse (c, t, Some e)` | +1 |
| `Pexp_ifthenelse (c, t, None)` | +1（else なしでも分岐）|
| `Pexp_match (e, cases)` | +`List.length cases` |
| `Pexp_try (e, cases)` | +`List.length cases` |
| `Pexp_while (c, body)` | +1 |
| `Pexp_for (...)` | +1 |
| `Pexp_apply (Pexp_ident "&&" or "||", _)` | +1 |

`&&` / `||` は `Pexp_apply` として現れる。識別子の `txt` を見て判定する。

### 3. visitor の実装

```ocaml
open Ppxlib

let is_short_circuit (e : expression) =
  match e.pexp_desc with
  | Pexp_apply (f, _) ->
      (match f.pexp_desc with
       | Pexp_ident { txt = Lident ("&&" | "||"); _ } -> true
       | _ -> false)
  | _ -> false

let complexity_visitor = object
  inherit [int] Ast_traverse.fold as super
  method! expression e acc =
    let inc =
      match e.pexp_desc with
      | Pexp_ifthenelse _ -> 1
      | Pexp_match (_, cases) -> List.length cases
      | Pexp_try (_, cases) -> List.length cases
      | Pexp_while _ -> 1
      | Pexp_for _ -> 1
      | _ when is_short_circuit e -> 1
      | _ -> 0
    in
    super#expression e (acc + inc)
end

let cyclomatic_complexity (body : expression) : int =
  1 + complexity_visitor#expression body 0
```

### 4. 関数ごとに集計する

LOC のときに作った `collect_functions` を拡張する。

```ocaml
type fn_info = {
  name : string;
  start_line : int;
  end_line : int;
  lines : int;
  cyclomatic : int;
}

(* value_binding を見つけたら body の expression で
   complexity_visitor を走らせる *)
```

ポイント: **CC は関数の body に対して計算する**。トップレベル全体ではない。

### 5. テスト用サンプル

`tests/sample_cc.ml`:
```ocaml
let simple x = x + 1   (* CC = 1 *)

let one_if x = if x > 0 then 1 else 0   (* CC = 2 *)

let with_and x y = if x > 0 && y > 0 then 1 else 0   (* CC = 3 *)

let with_match x =                                    (* CC = 3 *)
  match x with
  | 0 -> "zero"
  | 1 -> "one"
  | _ -> "other"
```

手計算と一致することを確認する。

### 6. 出力に追加

```
function                       start    end  lines     cc
simple                             1      1      1      1
one_if                             3      3      1      2
with_and                           5      5      1      3
with_match                         7     10      4      3
```

## Verification

- [ ] テスト用サンプルすべてで手計算と一致する
- [ ] `Pexp_ifthenelse` の else なしを正しく扱う
- [ ] `&&` と `||` の混在で適切に加算される
- [ ] match のケース数ルールが「+1 per case」か「+cases-1」かを README にメモした

## Pitfalls / Tips
- 短絡演算は `Pexp_apply` 経由なので忘れがち。識別子で判定する
- `let` の右辺に式があっても再帰で降りるので、ネストした `if` も拾える
- 「正解の CC」は流儀で揺れる — 自分の定義を採用して、サンプルでの期待値とセットで検証する

## Outputs
- LOC に加え CC を表示する CLI
- `tests/sample_cc.ml` と期待値メモ

## Next
- [05 Nesting Depth (Optional)](05-nesting-depth.md)
