---
date: 2026-05-26
phase: phase0
category: learning
tags: [ocaml, currying, partial-application, category-theory]
---

# カリー化と部分適用

## コンテキスト
phase0 / 02-language-fundamentals.md で `let add x y = x + y` を学習中。
`let add5 = add 5` がなぜ動くのか、型表記 `int -> int -> int` の読み方を考えた。

## 理解

### `->` の右結合と「すべて1引数関数」
OCaml の関数矢印 `->` は **右結合**。

```
int -> int -> int  ≡  int -> (int -> int)
```

つまり `add : int -> int -> int` は「2引数関数」ではなく、
**「`int` を受け取って『`int` を受け取って `int` を返す関数』を返す関数」**。

実行イメージ (`add 3 5`):
1. `add 3` → `fun y -> 3 + y`（3 を捕捉した新しい関数）
2. その関数に 5 を適用 → `3 + 5 = 8`

「左の引数から順に固定される」のがポイント。

### カリー化と部分適用の違い
混同しやすいので分離して覚える。

| 用語 | 意味 |
|------|------|
| **カリー化 (currying)** | 多引数関数を 1 引数関数の連鎖に **変換** する操作・形式 |
| **部分適用 (partial application)** | カリー化された関数に **引数を一部だけ渡す** 呼び方 |

OCaml / Haskell の関数は最初からカリー化された形で書かれているので、
部分適用が「特別な機能」ではなく自然な帰結として使える。

## 圏論との接続

これはデカルト閉圏 (CCC) における **指数対象** の話。

```
Hom(A × B, C)  ≅  Hom(A, C^B)
```

- 左辺: `A` と `B` のペアを受け取って `C` を返す関数（タプル版）
- 右辺: `A` を受け取って「`B` を受け取って `C` を返す関数」を返す関数（カリー版）

両者の間の自然同型を **curry / uncurry** と呼ぶ。OCaml に実物がある:

```ocaml
val Fun.curry   : ('a * 'b -> 'c) -> 'a -> 'b -> 'c
val Fun.uncurry : ('a -> 'b -> 'c) -> 'a * 'b -> 'c
```

`'a * 'b -> 'c` は **直積からの射** = タプル受け取り。
`'a -> 'b -> 'c` はカリー化版。

## 設計上の示唆: データラスト (data-last) 原則

「左の引数から固定される」性質から、OCaml 標準ライブラリは
**設定（関数・述語・初期値）を左、操作対象データを最後** に置くのが原則。

```ocaml
List.map       : ('a -> 'b) -> 'a list -> 'b list           (* 関数, データ *)
List.filter    : ('a -> bool) -> 'a list -> 'a list         (* 述語, データ *)
List.fold_left : ('acc -> 'a -> 'acc) -> 'acc -> 'a list -> 'acc
```

### データラストが嬉しい 2 つの理由

| 何ができるか | 必要な条件 |
|--------------|------------|
| `let double_all = List.map double` のような **設定の使い回し**（部分適用） | 関数を左に |
| `xs \|> List.map f \|> List.filter p` のような **パイプライン** | データを右に |

両方を同時に満たすのがデータラスト順。`List.map` の使用場面は
「**いろんなリストに同じ変換を適用する**」が圧倒的に多いので、
変換関数を先に固定できる順序が理にかなっている。

### パイプライン演算子 `|>`

```ocaml
[1; 2; 3]
|> List.map (fun x -> x * 2)      (* → [2; 4; 6] *)
|> List.filter (fun x -> x > 2)   (* → [4; 6] *)
```

`x |> f` は `f x` と等価。データラスト設計と組み合わさることで
データの加工チェーンを自然な左→右の流れで書ける。

## 関連リンク
- ariadne/procedure/phase0/02-language-fundamentals.md
- OCaml manual: https://ocaml.org/manual/coreexamples.html
- 圏論動画（学習者視聴済み）
- [[2026-05-26-phase0-utop-basics]]
