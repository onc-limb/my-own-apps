# Phase 2 / 03 — Tree Structure Understanding

## Goal
tree-sitter-typescript が返すノード型の正体を、自分のラッパ経由で目視確認する。複雑度計算に必要なノード型（関数定義系・分岐系）を確実に同定する。

## Prerequisites
- [02 FFI / Binding](02-ffi-binding.md) 完了

## Steps

### 1. ノードダンプツール

`bin/ts_dump.ml`:
```ocaml
open Ts_binding

let rec dump indent (n : Node.t) =
  Printf.printf "%s%s [%d:%d-%d:%d]\n"
    (String.make (indent * 2) ' ')
    (Node.kind n)
    (Node.start_row n) (Node.start_col n)
    (Node.end_row n) (Node.end_col n);
  List.iter (dump (indent + 1)) (Node.children n)

let () =
  let path = Sys.argv.(1) in
  let src = In_channel.with_open_text path In_channel.input_all in
  let tree = Ts_binding.parse src in
  dump 0 (Ts_binding.root tree)
```

### 2. サンプル `.ts` を順に流す

`tests/ts/01_function.ts`:
```typescript
function add(a: number, b: number): number {
  return a + b;
}
```

期待される主要ノード:
- `program`
- `function_declaration`
- `identifier` (関数名)
- `formal_parameters`
- `statement_block`
- `return_statement`

### 3. 関数定義系を網羅

```typescript
// 02_function_variants.ts
function declared() { return 1; }            // function_declaration
const arrow = (x: number) => x + 1;           // arrow_function
class C {
  method(x: number) { return x; }             // method_definition
  get value() { return 1; }                   // method_definition (kind="get")
  set value(v: number) {}                     // method_definition (kind="set")
}
```

ダンプ結果から、関数として数えるノード型一覧を確定する。

### 4. 分岐系を網羅

```typescript
// 03_branches.ts
function f(x: number, y: number) {
  if (x > 0) return 1;                        // if_statement
  for (let i = 0; i < 10; i++) {}             // for_statement
  for (const k in {}) {}                      // for_in_statement
  for (const k of []) {}                      // for_in_statement (kind同じ場合あり) / for_of?
  while (x > 0) x--;                          // while_statement
  do { x--; } while (x > 0);                  // do_statement
  switch (x) {
    case 1: break;                            // switch_case
    default: break;                           // switch_default
  }
  try { } catch (e) { } finally { }           // try_statement / catch_clause
  const v = x > 0 ? 1 : 0;                    // ternary_expression
  const b = x > 0 && y > 0;                   // binary_expression (operator="&&")
  const c = x ?? y;                           // binary_expression (operator="??")
  const d = x?.toString();                    // optional_chain
}
```

**実機での kind 名を必ず自分のダンプで確認する**。文法のバージョンで微妙にズレることがある。

### 5. ノード名表をプロジェクトに記録する

`docs/ts-node-kinds.md`（または `ASSUMPTIONS.md`）に記録:

| 概念 | tree-sitter ノード kind |
|------|--------------------------|
| 関数宣言 | `function_declaration` |
| アロー関数 | `arrow_function` |
| メソッド | `method_definition` |
| if | `if_statement` |
| for | `for_statement` |
| for...in | `for_in_statement` |
| for...of | （実機で確認）|
| while | `while_statement` |
| do...while | `do_statement` |
| switch case | `switch_case` |
| switch default | `switch_default` |
| try | `try_statement` |
| catch | `catch_clause` |
| 三項 | `ternary_expression` |
| 二項演算 | `binary_expression`（operator フィールドで `&&` / `\|\|` / `??` を判定）|
| optional chain | （実機で確認） |

これが Phase 3 の「分岐網羅」の根拠資料になる。

### 6. named / anonymous ノードの理解

tree-sitter は文法のリテラル（`{`、`if` キーワードなど）も "anonymous" ノードとしてツリーに含む。
- `Node.children` は ts API のどちらを返すか方針を決める
- 通常は **`named_children`** を使う（解析対象がリテラルに依存しないため）
- ただし `binary_expression` の演算子は子ノードの kind で取れない場合があり、**フィールド名 (`operator`) でアクセス**する必要がある

`ts_node_child_by_field_name` を foreign 宣言して、`operator` フィールドを取れるようにする。

## Verification

- [ ] ダンプツールが任意の `.ts` を投入して階層構造を表示する
- [ ] 関数系の 3 種類（declaration / arrow / method）が確実に同定できる
- [ ] 分岐系のノード kind を表として記録した
- [ ] `binary_expression` から `operator` フィールドを取れる

## Pitfalls / Tips
- tree-sitter は **エラー回復付き**でパースする。壊れた入力でも何かを返す — `Node.kind = "ERROR"` を見落とさない
- `for_of_statement` の独立ノードがあるかは tree-sitter-typescript の世代依存。実機優先で決める
- anonymous ノードを含めて走査するとリテラルが大量に出る — 必ず named のみで進める

## Outputs
- `bin/ts_dump.ml`
- ノード kind の対応表（後フェーズで参照する）

## Next
- [04 Logic Migration](04-logic-migration.md)
