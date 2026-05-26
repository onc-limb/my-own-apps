# Phase 0 / 03 — Module System

## Goal
OCaml のモジュールとシグネチャの基本を理解し、後フェーズで「指標ロジックとパーサを分離する」設計の足場を作る。

## Prerequisites
- [02 Language Fundamentals](02-language-fundamentals.md) 完了

## Steps

### 1. インラインモジュール

```ocaml
module Counter = struct
  let make () = ref 0
  let incr c = c := !c + 1
  let get c = !c
end

let () =
  let c = Counter.make () in
  Counter.incr c;
  Counter.incr c;
  Printf.printf "%d\n" (Counter.get c)
```

### 2. ファイル分割によるモジュール

dune では `foo.ml` がそのまま `Foo` モジュールになる。

```
playground/modules/
├── dune-project
└── bin/
    ├── dune
    ├── counter.ml
    └── main.ml
```

- `counter.ml` に上記の中身（`module Counter = struct ... end` の中身そのまま）を置くと `Counter` モジュールになる
- `main.ml` から `Counter.make` で呼べる

### 3. シグネチャ（.mli）でインターフェースを絞る

`counter.mli` を作る:
```ocaml
type t
val make : unit -> t
val incr : t -> unit
val get : t -> int
```

- 内部表現を `type t` で抽象化する → 外から `ref int` だと見えなくなる
- `make` 経由でしか生成できない強制力を作れる
- 同じ目的で `bin/dune` には変更不要（dune が自動でリンクする）

### 4. ファンクタ（軽く触る）

「モジュールをパラメータに取るモジュール」。後フェーズで「パーサを差し替えても指標ロジックは共通」という設計に使う。

```ocaml
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end

module MakeSet (O : ORDERED) = struct
  type elt = O.t
  type t = elt list
  let empty = []
  let add x s = if List.exists (fun y -> O.compare x y = 0) s then s else x :: s
end

module IntSet = MakeSet (struct type t = int let compare = compare end)
```

- いまは「シグネチャを満たすモジュールを差し込むと、それに合わせた新しいモジュールができる」と理解できれば十分

## Verification

- [ ] `.ml` と `.mli` の役割を一言で説明できる（実装 / 公開インターフェース）
- [ ] `type t` を抽象にすると、外部コードからどう見えるかを確かめている（コンパイルエラーを起こせる）
- [ ] ファンクタの「入力モジュール → 出力モジュール」の関係を図にできる

## Pitfalls / Tips
- `.mli` を書くと、`.ml` 側で `mli` に書いていない値は外から使えなくなる（隠蔽が効く）
- dune は `.mli` を自動で拾うので明示的な記述は不要
- ファンクタは Phase 2 以降で「Parser モジュールを差し替える」場面でもう一度出会う — 今は深追いしない

## Outputs
- `ariadne/playground/modules/` 配下の Counter モジュールと `.mli` 付きビルド

## Next
- [04 Practice](04-practice.md)
