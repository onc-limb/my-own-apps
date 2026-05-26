# Phase 0 / 02 — Language Fundamentals

## Goal
OCaml の文法と発想（不変・代数的データ型・パターンマッチ・Option/Result）を、後フェーズの AST 走査に転用できるレベルで身につける。

## Prerequisites
- [01 Environment Setup](01-environment-setup.md) 完了
- `utop` が起動できる

## Steps

### 1. `let` と不変性

`utop` で次を試す。
```ocaml
let x = 1;;
let x = x + 1;;   (* シャドーイング — 再代入ではない *)
```

「変数は変わらない、新しい束縛が前のを覆い隠す」感覚を掴む。

### 2. 関数定義

```ocaml
let add x y = x + y;;
let add_named ~x ~y = x + y;;
let greet ?(name="world") () = Printf.printf "Hello, %s\n" name;;
```

- 名前付き引数 `~x`、オプション引数 `?(name=..)` の構文を実際に呼ぶ
- 部分適用 `let add5 = add 5` を試す

### 3. リスト処理（map / filter / fold）

```ocaml
List.map (fun x -> x * 2) [1; 2; 3];;
List.filter (fun x -> x mod 2 = 0) [1; 2; 3; 4];;
List.fold_left (+) 0 [1; 2; 3; 4];;
```

自分で再帰版を書いてみる。
```ocaml
let rec sum = function
  | [] -> 0
  | x :: xs -> x + sum xs
```

### 4. タプルとレコード

```ocaml
let pair = (1, "a");;
type point = { x : int; y : int };;
let p = { x = 1; y = 2 };;
let { x; _ } = p;;
```

### 5. 代数的データ型（ADT）と網羅パターンマッチ

これが Phase 1 以降で最も重要。
```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Mul of expr * expr

let rec eval = function
  | Int n -> n
  | Add (a, b) -> eval a + eval b
  | Mul (a, b) -> eval a * eval b
```

- 一つケースを消すと「網羅性警告」が出ることを実際に体験する
- ワイルドカード `_` を使ってよい場面と使ってはいけない場面を区別する（消す場合は警告が消えて取りこぼしに気付けない）

### 6. Option / Result

```ocaml
let find_first p xs = List.find_opt p xs;;

let safe_div a b =
  if b = 0 then Error "divide by zero"
  else Ok (a / b)
```

`match` で取り出す練習をする。
```ocaml
match safe_div 10 0 with
| Ok v -> Printf.printf "%d\n" v
| Error msg -> Printf.printf "err: %s\n" msg
```

### 7. 例外と Result の使い分け方針

- 想定内のエラー（ファイルが無い、パース失敗、入力不正） → `Result`
- 真にバグ／復帰不能（不変条件違反、内部状態の破壊） → 例外
- 自分なりの一行ルールを `cheatsheet.md`（後述）にメモする

## Verification

- [ ] ADT `expr` を自分で定義し直して `eval` を書ける
- [ ] 「網羅性警告」を意図的に起こせる／消せる
- [ ] `Option.value`、`Result.map` を見ずに型から使い方が想像できる
- [ ] 「不正な状態を表現不能にする」の意味を、自分の言葉で例を出して説明できる

## Pitfalls / Tips
- セミコロン `;` と二重セミコロン `;;` を混同しない — `;;` は対話環境専用
- `match` の `|` の付け忘れで型エラーが出やすい
- `Printf.printf "%s\n"` のフォーマット指定子は型と一致する必要がある（コンパイル時にチェックされる）

## Outputs
- `ariadne/playground/fundamentals/` 配下に動かしながら書いた `.ml` ファイル群

## Next
- [03 Module System](03-module-system.md)
