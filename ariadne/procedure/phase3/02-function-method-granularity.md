# Phase 3 / 02 — Function / Method Granularity

## Goal
「何を関数として 1 つ数えるか」を厳密に決め、宣言関数・アロー関数・メソッド・getter/setter を漏れなく拾う。ネスト関数の取り扱い方針も決める。

## Prerequisites
- [01 Comprehensive Branch Coverage](01-comprehensive-branch-coverage.md) 完了

## Steps

### 1. 「関数」として拾うノード一覧

| 概念 | tree-sitter kind | 名前の取り方 |
|------|------------------|--------------|
| 関数宣言 | `function_declaration` | `name` フィールド |
| 関数式 | `function_expression` | `name` または `<anonymous>` |
| アロー関数 | `arrow_function` | 親の代入先名から推定 / `<arrow>` |
| メソッド | `method_definition` | `name` フィールド |
| getter/setter | `method_definition`（`kind="get"/"set"` 子） | `name` フィールド |

### 2. 関数名の取得ロジック

アロー関数は **自身に名前を持たない**。親が `variable_declarator` なら左辺の識別子を拝借する。

```ocaml
let rec arrow_name (n : Ts_binding.Node.t) : string =
  match Ts_binding.Node.parent n with
  | Some p when Ts_binding.Node.kind p = "variable_declarator" ->
      (match Ts_binding.Node.field p "name" with
       | Some name_node -> Ts_binding.Node.text name_node
       | None -> "<arrow>")
  | Some p when Ts_binding.Node.kind p = "pair" ->
      (match Ts_binding.Node.field p "key" with
       | Some k -> Ts_binding.Node.text k
       | None -> "<arrow>")
  | _ -> "<arrow>"
```

`parent` を取るには tree-sitter の `ts_node_parent` を foreign 宣言する必要がある。

### 3. クラスメソッドの「修飾名」

`method_definition` だけだと `add` のような短い名前になる。所属クラスを付けて `User#add` のように表示すると読みやすい。

走査で「現在のクラス名」をスタックで持つ。

```ocaml
type ctx = { class_stack : string list }

let qualified_name ctx base =
  match ctx.class_stack with
  | [] -> base
  | c :: _ -> c ^ "#" ^ base
```

### 4. getter / setter の区別

`method_definition` の子に `get` / `set` キーワードがあるかで判定。

- getter → `name` のあとに `[get]` を付ける（`User#name [get]`）
- setter → `[set]`

`docs/complexity-rules.md` に表示規約として書く。

### 5. ネスト関数の方針

選択肢:
- **(A) 内側を含めて外側に加算する**
  - 外側の CC が肥大化
  - 「全体の難しさ」を表す
- **(B) 内側を別関数として独立カウントし、外側からは除外する** ← 推奨
  - ESLint complexity ルールと一致する
  - レポートに内側関数も別行で並ぶ
  - 「この関数自身の難しさ」が明確

実装: `collect_functions` で再帰しつつ、`count_branches` 側で「ネスト関数の中には降りない」ように分ける。

```ocaml
let is_function n =
  match n.kind with Function _ -> true | _ -> false

let rec count_branches_outside_fns (n : Ir.Node.t) : int =
  let here = if is_branch n.kind then 1 else 0 in
  let children =
    List.filter (fun c -> not (is_function c)) n.children
  in
  here + List.fold_left (fun acc c -> acc + count_branches_outside_fns c) 0 children
```

### 6. テスト

`tests/granularity.ts`:
```typescript
function outer(x: number) {
  const inner = (y: number) => {
    if (y > 0) return 1;     // inner の CC=2
    return 0;
  };
  if (x > 0) return inner(x); // outer の CC=2
  return 0;
}

class User {
  add(a: number, b: number) { return a + b; }  // User#add CC=1
  get name() { return "u"; }                    // User#name [get] CC=1
}
```

`outer` の CC が 3 になっていたら方針 (B) に違反しているサイン。

## Verification

- [ ] アロー関数も別行として表示される
- [ ] クラスメソッドが `Class#method` 形式で表示される
- [ ] getter / setter が `[get]` / `[set]` の修飾付きで表示される
- [ ] ネスト関数の CC が外側に含まれていない（テストで明示確認）

## Pitfalls / Tips
- 親アクセスが必要になるので `ts_node_parent` の foreign 宣言を忘れない
- `Function { name }` の name は IR で持たず、抽出時に決める設計にすると差し替えやすい
- 「全体の複雑さ」が見たい人もいるので、`--include-nested` フラグ余地は残しておく（実装は後でよい）

## Outputs
- 拡張された `collect_functions` と `cyclomatic`
- 「ネスト関数は別カウント」を明記したドキュメント

## Next
- [03 Cognitive Complexity](03-cognitive-complexity.md)
