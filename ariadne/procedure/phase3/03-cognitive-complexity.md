# Phase 3 / 03 — Cognitive Complexity

## Goal
SonarSource の認知的複雑度（Cognitive Complexity）を実装する。**ネストが深いほど重くする**仕組みを通じて、走査時に「環境（深さ）」を伝播するパターンを身につける。

## Prerequisites
- [02 Function/Method Granularity](02-function-method-granularity.md) 完了

## Steps

### 1. 認知的複雑度のルール（SonarSource 仕様の要約）

増分は 3 つの種類に分かれる。

**基本インクリメント (B+1)** — 構文単体で +1
- `if` / `else if` / `else`
- 三項演算子
- `for` / `while` / `do-while`
- `catch`
- `switch` 全体
- `goto`（TS では該当なし）

**ネストインクリメント (N+depth)** — 上記の基本インクリメントが「他の制御構文の中にネストしている」と、現在のネスト深さを追加で加算
- 例: 関数本体直下の `if` は B(1) + N(0) = +1
- `if` の中の `if` は B(1) + N(1) = +2
- さらに `for` の中だと B(1) + N(2) = +3

**ハイブリッドインクリメント** — 短絡演算子の **連続** は 1 つ目だけ +1
- `a && b && c` は +1（合計）
- `a && b || c` は +2（種類が変わると別カウント）

ネストを増やすノード:
- if / else / for / while / do / switch / catch / 関数の入れ子

### 2. 増分一覧表（実装根拠）

| ノード | 基本 +1 | ネスト効果 |
|--------|---------|------------|
| `if` (then) | ○ | +depth、ネスト深度を +1 して子へ |
| `else if` | ○（+1 だけ。ネストは増やさない流儀あり）| 解釈による — 仕様を明確化 |
| `else` | ○（+1 だけ、ネスト効果なし）|  |
| `ternary` | ○ | +depth、ネスト深度を +1 |
| `for/while/do` | ○ | +depth、ネスト深度を +1 |
| `catch` | ○ | +depth、ネスト深度を +1 |
| `switch` | ○（switch 全体で 1 回） | +depth、ネスト深度を +1 |
| `&&` `\|\|` `??` | グループ化 +1 | ネスト効果なし |
| ネスト関数 | （関数自身は +0）| ネスト深度 +1 |

**else if の扱いを明文化する**こと（SonarSource 公式は else if 各 +1、ネストは増やさない）。

### 3. 実装

走査で「現在のネスト深度」と「直前の論理演算子」を持つ。

```ocaml
type state = {
  depth : int;
  total : int;
  last_logical : Ir.Node.kind option;  (* 連続短絡をグループ化するため *)
}

let initial = { depth = 0; total = 0; last_logical = None }

let increments_nesting (k : Ir.Node.kind) =
  match k with
  | If | For | While | Ternary | TryCatch | SwitchCase -> true
  | _ -> false

let rec walk (st : state) (n : Ir.Node.t) : state =
  let basic, nest_increment, increases_nesting, logical =
    match n.kind with
    | If | For | While | Ternary | TryCatch ->
        (1, st.depth, true, None)
    | SwitchCase ->
        (* switch は全体で 1 回。case では数えず、switch 全体を別途扱う *)
        (0, 0, true, None)
    | LogicalAnd | LogicalOr | NullishCoalescing ->
        let same_as_last = st.last_logical = Some n.kind in
        ((if same_as_last then 0 else 1), 0, false, Some n.kind)
    | _ -> (0, 0, false, None)
  in
  let total' = st.total + basic + nest_increment in
  let st_for_children =
    { depth = st.depth + (if increases_nesting then 1 else 0);
      total = total';
      last_logical = logical;
    }
  in
  let st_after =
    List.fold_left walk st_for_children n.children
  in
  (* 兄弟へ抜ける時に depth は元に戻す。total と last_logical は持ち回る *)
  { depth = st.depth;
    total = st_after.total;
    last_logical = st_after.last_logical;
  }

let of_function (body : Ir.Node.t) : int =
  (walk initial body).total
```

### 4. switch の特殊処理

SonarSource は **switch 全体で +1**（case 数に依らない）。今の IR では `switch_statement` を独立ノードとして追加する必要がある。

`Ir.Node.kind` に `Switch` を追加し、アダプタで `switch_statement` を `Switch` にマップ。`SwitchCase` 自体では加算しない。

### 5. テスト（CC と Cog の差が出る例）

```typescript
function flat(x: number) {              // CC=4, Cog=3
  if (x > 0) return 1;                  //  B+1 N+0 = 1
  if (x > 1) return 2;                  //  B+1 N+0 = 1
  if (x > 2) return 3;                  //  B+1 N+0 = 1
  return 0;
}

function nested(x: number, y: number, z: number) {  // CC=4, Cog=6
  if (x > 0) {                          //  B+1 N+0 = 1
    if (y > 0) {                        //  B+1 N+1 = 2
      if (z > 0) return 1;              //  B+1 N+2 = 3
    }
  }
  return 0;
}
```

「同じ CC でも Cog はネストで重くなる」が確認できる。

### 6. 出力に追加

表に `cog` 列を追加。
```
function                       lines     cc    cog
flat                               5      4      3
nested                             7      4      6
```

## Verification

- [ ] CC と Cog の値が違う関数を 3 つ以上テストできた
- [ ] 連続する `&&` / `||` の混在で、グループ化ルールが効いている
- [ ] SonarSource の公式例（あるいは [`eslint-plugin-sonarjs`](https://github.com/SonarSource/eslint-plugin-sonarjs) の cognitive-complexity ルールの出力）と比較して妥当

## Pitfalls / Tips
- `else if` の解釈は流派あり。**Ariadne の方針として `else if` も +1（ネスト効果なし）**を採用し、ドキュメントに残す
- 状態を fold で持つ設計のため、depth を「子へ降りるときだけ +1」「戻ったら元に戻す」を正しく実装することが肝
- `Cog` は完全に SonarSource 互換にする必要はない。**自分の定義として説明可能** が完了基準

## Outputs
- `lib/metrics/cognitive.ml`
- `Switch` ノードを含む IR 拡張
- CC と Cog 両方を出す CLI

## Next
- [04 Output Formatting](04-output-formatting.md)
