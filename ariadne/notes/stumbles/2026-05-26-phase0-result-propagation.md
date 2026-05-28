---
date: 2026-05-26
phase: phase0
category: stumble
tags: [ocaml, result, error-propagation, pattern-match, answer-given]
---

# Result のエラー伝播でつまずいた

> **注: このトピックは答えを先出しした（学習者の要請による）。**
> 後日、自力で書き直して理解を定着させること。

## コンテキスト
[Phase0 練習問題](../hints/2026-05-26-phase0-exercises.md) Exercise 1-A で
`expr` に `Div` を追加し、`eval` の戻り値を `(int, string) result` にする
選択肢 (c) を取った。

## つまずきの軌跡

### Step 1: 関数適用の文法ミス
```ocaml
safe_div (eval a eval b)   (* ← (eval a) に eval を適用してから b を適用、と読まれる *)
```
→ `safe_div (eval a) (eval b)` が正解。
`->` 右結合と関数適用が **左結合** であることを意識すると読み解ける。

### Step 2: eval の戻り値型の不整合
`Div` だけ `result` を返し、他の枝は `int`。match の全分岐が同じ型を返す
ルールに反した → 全枝を `result` にする方針へ。

### Step 3: `Ok (eval a + eval b)` の罠
`eval a` が `result` 型なので `+` できない。
**Result は「箱から取り出す」のではなく「箱のまま運ぶ」のが正しい使い方**。

### Step 4: `resolve` 関数を作ろうとした失敗
```ocaml
let resolve = function
  | Ok v -> v
  | Error e -> Printf.printf "Error: %s\n" e
```

問題:
1. 戻り値型が `int` と `unit` で食い違い、型エラー
2. そもそも `Error` のとき `int` として何を返すか決められない
   - `0` を返す → `1/0 + 5` が `5` になってしまう（エラーを握りつぶす）
3. **「中身を取り出す」設計自体が Result の存在意義を否定している**

## 解決: エラー伝播パターン

```ocaml
let rec eval = function
  | Int n -> Ok n
  | Add (a, b) ->
      (match eval a with
       | Error e -> Error e
       | Ok av ->
         (match eval b with
          | Error e -> Error e
          | Ok bv -> Ok (av + bv)))
  (* Mul, Sub も同様 *)
  | Div (a, b) ->
      (match eval a with
       | Error e -> Error e
       | Ok av ->
         (match eval b with
          | Error e -> Error e
          | Ok bv -> safe_div av bv))
```

### 重要ポイント

1. **エラー伝播**: `Error e -> Error e` で「そのまま上に返す」
2. **箱で包み直す**: 計算結果は `Ok (av + bv)` で `result` に戻す
3. **`Div` だけは違う**: `safe_div` 自体が `result` を返すので、`Ok` で包まない
   （包むと `(result, string) result` の二重箱になる）
4. **内側の `match` を `(...)` で囲む**: OCaml の有名な罠。`|` の所属が曖昧になる
   ので、ネストした `match` は必ず括弧で囲う

## 動作確認

```ocaml
eval (Add (Int 1, Int 2))                        (* → Ok 3 *)
eval (Div (Int 10, Int 0))                       (* → Error "divide by zero" *)
eval (Add (Div (Int 1, Int 0), Int 5))           (* → Error "divide by zero" *)
```

最後の例が **エラー伝播の威力**。`Div` の `Error` が `Add` を **そのまま通り抜けて**
最終結果になる。命令型での `try-catch` に相当する制御フローが、`match` の連鎖で
表現されている。

## 教訓

| やってしまった発想 | 正しい発想 |
|--------------------|-----------|
| 「Result の中身を取り出して計算」 | 「Result のまま運び、必要なとき開封」 |
| 「Error のとき何かデフォルト値を返す」 | 「Error はそのまま伝播させる」 |
| 「中身を `int` として使いたい」 | 「箱の中で計算する」 |

これは **モナドの発想** に直結する（圏論動画の文脈と接続）。
`Result.bind` / `let*` 構文を使うと、この match ネストを 1 行で書ける。
次に学ぶべきトピック。

## TODO: 自分で再現する

- [ ] 数日後、何も見ずに同じ `eval` を書き直す（記憶ではなく理解で）
- [ ] `Result.bind` を使った書き換え版を学習する
- [ ] `let*` 構文を学習する
- [ ] `Mul`, `Sub`, `Div` の枝が「ほぼ同じ形」をしていることが
      どんな抽象化を呼んでいるかを言語化する

## 関連
- [[2026-05-26-phase0-currying]]
- [[2026-05-26-phase0-exercises]]
- ../../procedure/phase0/02-language-fundamentals.md
