# Phase 0 / 04 — Practice

## Goal
これまでの文法知識を「動くもの」に落として身につける。Phase 1 で AST を相手にする準備として、**再帰 ADT のパターンマッチを反射で書けるようにする**。
この節は読む節ではなく**手を動かす節**。だからあえて完成コードは載せず、**型と考え方だけ**を示す。コードは自分で埋めること。

## Prerequisites
- [03 Module System](03-module-system.md) 完了

## このドキュメントの読み方（ここだけ作法が違う）
01〜03 は写経だったが、**04 は自力実装**。各演習で示すのは「**何を作るか（型シグネチャ）**」「**どう考えるか（再帰の組み立て方）**」「**ベースケースのヒント**」まで。
**完成コードは載せていない**（このプロジェクトの方針 R-001/R-002）。自分で書いて、できたら「レビューして」と声をかけること。詰まったらヒントを増やす。

---

## 再帰関数を組み立てる「型」（全演習共通の思考法）

02 で見た通り、再帰は必ず 2 つの部分でできている。これを毎回**先に言葉にしてから**書く。

1. **ベースケース**：これ以上分解できない最小の入力で、答えが直接決まる場合（例：空リスト `[]`、葉ノード `Int n`）
2. **再帰ケース**：入力を「先頭＋残り」や「自分＋子」に分け、**残り／子を自分自身で解いて**から組み合わせる場合

> 合言葉：「**最小のとき答えは何か（ベース）／残りを自分に任せたら、自分の分で何を足すか（再帰）**」。
> この 2 問に言葉で答えられれば、コードはほぼ書けている。

---

## Steps

### 1. リスト処理練習 — 標準ライブラリを自前で再発明する

`playground/practice/lists.ml` に以下を**標準ライブラリ非使用**で実装する。型シグネチャは「契約」。これを満たすように書く。

```
length    : 'a list -> int
rev       : 'a list -> 'a list
map       : ('a -> 'b) -> 'a list -> 'b list
filter    : ('a -> bool) -> 'a list -> 'a list
fold_left : ('acc -> 'a -> 'acc) -> 'acc -> 'a list -> 'acc
take      : int -> 'a list -> 'a list      (* 先頭 n 個 *)
drop      : int -> 'a list -> 'a list      (* 先頭 n 個を捨てた残り *)
```

**考え方の例（`length` の場合）**：
- ベースケース：`[] -> ?`（空リストの長さは何か）
- 再帰ケース：`_ :: xs -> ?`（先頭は中身を見ない＝`_`、残り `xs` の長さに何を足す？）

各関数について、`List` モジュールの結果と一致することを `assert` で確認する：
```ocaml
let () = assert (length [1; 2; 3] = 3)
let () = assert (rev [1; 2; 3] = [3; 2; 1])
(* ... 各関数ぶん書く。assert が通れば実装は正しい *)
```

**ヒント**：`map` と `filter` は `length` と同じ「`[]` / `x :: xs`」の形。`rev` は「`fold_left` で前に積む」とも「素朴な再帰」とも書ける。両方試すと fold の力が分かる。

### 2. 式評価器 — Phase 1 の AST 走査の縮小版

`playground/practice/calc.ml` に最小の式評価器を実装する。**型定義はここまで作る**（これは設計の対象なので示す）：

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr
  | If of expr * expr * expr   (* If(cond, then, else)。cond は 0 以外で真 *)
```

そして `eval : expr -> int` を書く。**骨組み（ベースケースだけ）を示すので、残りは自分で埋める**：

```ocaml
let rec eval : expr -> int = function
  | Int n -> n                 (* ← ベースケース：葉。これ以上分解できない *)
  | Add (a, b) -> (* ? *)      (* ← 左右を eval して足す。02 の expr と同じ発想 *)
  (* Sub / Mul / Div / If の各ケースを自分で埋める *)
```

**考え方**：各ノードで「子（`a`, `b`, `c` …）を `eval` で先に値にしてから、自分の演算を適用する」。`If` だけは「`cond` を評価し、0 以外なら `then`、0 なら `else` を評価」。

確認：
```ocaml
let () =
  let e = If (Int 1, Add (Int 2, Int 3), Int 0) in
  assert (eval e = 5)
```

**これは Phase 1 の AST 走査の縮小版**。「ノード種を ADT で表す → 再帰 + match で各ノードに処理を振り分ける」——この発想が次フェーズの分岐カウンタにそのまま転用される。

### 3. 「分岐カウント」を追加 — 循環的複雑度の最小ひな型

`eval` を派生させ、式に含まれる **`If` の個数**を数える `count_if : expr -> int` を書く。

**骨組み（考え方つき）**：
```ocaml
let rec count_if : expr -> int = function
  | Int _ -> (* ? *)           (* 葉に If は無い。何個？ *)
  | Add (a, b) -> (* ? *)      (* 自分は If でない。子に含まれる If の合計 *)
  (* Sub / Mul / Div も Add と同じ形 *)
  | If (c, t, e) -> (* ? *)    (* 自分が If 1 個 + 3 つの子に含まれる If *)
```

**リズム**：「**ノード種を場合分け → 子に再帰 → 自分の分を加算**」。
`Add`〜`Div` は「自分は数えない（0 加算）、子の合計」。`If` は「**自分の 1** ＋ 子の合計」。これが「循環的複雑度ロジックの最小ひな型」で、Phase 1 でやるのはこの拡張版でしかない。

**注意（あるある）**：`Add` のケースで「中に隠れた `If`」を数え忘れない。`Add (Int 1, If (...))` のように、`If` でないノードの**子**に `If` がいる。子への再帰を省くとここを取りこぼす。

### 4. チートシートの作成

`ariadne/playground/cheatsheet.md` を作り、**自分が引きたい行だけ**メモする（長く書かない）。最低限：

- `let rec` と `and`（相互再帰）の使い方
- `match` の `|`／網羅性／`_` の使いどころと罠
- `option` と `result` の代表関数（`value` / `map` / `bind` など）
- `List.{map, filter, fold_left, fold_right}` のシグネチャ
- `Printf.{printf, sprintf}` のフォーマット指定子（`%d %s %b` …）
- `dune build` / `dune exec NAME` / `dune utop`
- `opam install` / `opam switch` / `eval $(opam env)`

---

## Verification

- [ ] `lists.ml` の自前実装が、すべて標準ライブラリと結果一致する（`assert` が全部通る）
- [ ] `calc.ml` の評価器に `Mod of expr * expr` を追加したとき、**コンパイラの網羅性警告に導かれて** `eval` / `count_if` を修正できる
- [ ] `count_if` を書きながら「ノード種を場合分け → 子に再帰 → 自分の分を加算」のリズムが手に馴染んでいる
- [ ] チートシートが手元にあり、検索より速く引ける

---

## 理解度確認問題（実装演習の先の「概念確認」）

> 実装（Steps 1〜3）そのものが一番の確認。ここでは**実装後に答えられるべき問い**を置く。解答は載せていない。

### Q1. ベースと再帰
自作した `length` のベースケースと再帰ケースを**言葉で**説明せよ。`map` も同様に説明せよ。両者の構造の共通点は何か。

### Q2. fold で書き直す
`length` を `fold_left` を使って書き直せ（再帰を自分で書かずに）。`fold_left` の累積値 `acc` には何を入れ、各要素で何をするか説明せよ。

### Q3. 網羅性に導かれる修正（重要）
`calc.ml` に `Mod of expr * expr` を追加すると、`eval` と `count_if` の**両方**で何が起きるか。実際に追加して、コンパイラのメッセージを読み、それに従って直せ。このとき「`_ -> ...` で握りつぶさない」のはなぜか。

### Q4. count_if の取りこぼし
`count_if (Add (Int 1, If (Int 1, Int 2, Int 3)))` の正しい答えは何か。もし `Add` のケースで子への再帰を忘れたら、答えはどうずれるか。これが教えてくれる「再帰の鉄則」を一言で。

### Q5. Phase 1 への接続
`count_if` と「Phase 1 でやる循環的複雑度の計算」は、構造的にどこが同じでどこが違うと予想するか。現時点の仮説でよい（roadmap/phase1 を眺めて答えてよい）。

---

## Pitfalls / Tips
- 評価器でゼロ除算（`Div (_, Int 0)`）が起きると例外で落ちる — **それで OK**。`Result` 化したくなったら別途やる（07 で学んだ設計判断の練習になる）。
- `count_if` で「`If` でないノードの子に隠れた `If`」を数え忘れるのが最頻出ミス。`assert` で検出するか、`_` の誘惑を避けてコンストラクタを明示列挙する。
- チートシートは長く書かない。**自分が実際に引きたい行**だけ。育てるもの。

## Outputs
- `playground/practice/lists.ml`（自前実装 + assert）
- `playground/practice/calc.ml`（評価器 + count_if）
- `playground/cheatsheet.md`

## Next
- Phase 0 完了。roadmap の Completion Criteria をチェックし、満たしていなければ該当セクションへ戻る
- [Phase 1 / 01 AST Understanding](../phase1/01-ast-understanding.md)
