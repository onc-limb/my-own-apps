# Phase 0 / 04 — Practice

## Goal
これまでの文法知識を「動くもの」に落として身につける。Phase 1 で AST を相手にする準備として、再帰 ADT のパターンマッチを反射で書けるようにする。

## Prerequisites
- [03 Module System](03-module-system.md) 完了

## Steps

### 1. リスト処理練習

`playground/practice/lists.ml` に以下を自前で実装する（標準ライブラリ非使用）。

- `length : 'a list -> int`
- `rev : 'a list -> 'a list`
- `map : ('a -> 'b) -> 'a list -> 'b list`
- `filter : ('a -> bool) -> 'a list -> 'a list`
- `fold_left : ('acc -> 'a -> 'acc) -> 'acc -> 'a list -> 'acc`
- `take : int -> 'a list -> 'a list`
- `drop : int -> 'a list -> 'a list`

各関数について、`List` モジュールの結果と一致することを `assert` で確認する。

```ocaml
let () = assert (length [1; 2; 3] = 3)
```

### 2. 式評価器

`playground/practice/calc.ml` に最小の式評価器を実装する。

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr
  | If of expr * expr * expr   (* If(cond, then, else)。cond は 0 以外で真 *)

let rec eval : expr -> int = function
  | Int n -> n
  | Add (a, b) -> eval a + eval b
  | Sub (a, b) -> eval a - eval b
  | Mul (a, b) -> eval a * eval b
  | Div (a, b) -> eval a / eval b
  | If (c, t, e) -> if eval c <> 0 then eval t else eval e
```

確認:
```ocaml
let () =
  let e = If (Int 1, Add (Int 2, Int 3), Int 0) in
  assert (eval e = 5)
```

**これは Phase 1 の AST 走査の縮小版**。
- ノードの種類を ADT で表す
- 再帰関数 + match で各ノードに処理を振り分ける

この発想が次フェーズの分岐カウンタにそのまま転用される。

### 3. 式評価器に「分岐カウント」を追加

evaluator を派生させて、式に含まれる `If` の個数を数える関数を書く。

```ocaml
let rec count_if : expr -> int = function
  | Int _ -> 0
  | Add (a, b) | Sub (a, b) | Mul (a, b) | Div (a, b) ->
      count_if a + count_if b
  | If (c, t, e) -> 1 + count_if c + count_if t + count_if e
```

これが「循環的複雑度ロジックの最小ひな型」。Phase 1 でやることはこれの拡張版でしかない。

### 4. チートシートの作成

`ariadne/playground/cheatsheet.md` を作り、覚えにくいものをメモする。最低限以下を含める。

- `let rec` と `and` の使い方
- `match` の `|`／網羅性
- `option` と `result` の代表的な関数
- `List.{map,filter,fold_left,fold_right}` のシグネチャ
- `Printf.{printf,sprintf}` のフォーマット指定子
- `dune build` / `dune exec NAME` / `dune utop`
- `opam install` / `opam switch`

## Verification

- [ ] `lists.ml` の自前実装が標準ライブラリと結果一致する
- [ ] `calc.ml` の評価器に `Mod` などを追加するとき、コンパイラの網羅性警告に導かれて修正できる
- [ ] `count_if` を書きながら「ノード種を場合分け → 子に再帰 → 自分の分を加算」のリズムが体に入っている
- [ ] チートシートが手元にあり、検索より速く引ける

## Pitfalls / Tips
- 評価器でゼロ除算が起きると例外で落ちる — それで OK。`Result` 化したくなったら別途やる
- `count_if` を書くときに「`Add` の中の `If` を忘れる」のがあるある — テストで気づくか、ワイルドカード `_` の誘惑を避ける
- チートシートは長く書かない（自分が引きたい行だけ）

## Outputs
- `playground/practice/lists.ml`
- `playground/practice/calc.ml`
- `playground/cheatsheet.md`

## Next
- Phase 0 完了。roadmap の Completion Criteria をチェックして、満たしていなければ該当セクションへ戻る
- [Phase 1 / 01 AST Understanding](../phase1/01-ast-understanding.md)
