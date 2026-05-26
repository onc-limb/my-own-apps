# Phase 5 / 03 — Multi-language Architecture

## Goal
言語追加が「アダプタ 1 個と設定 1 行」で済む構造に整理する。共通の指標ロジックと言語固有のマッピングを完全分離し、第 3 言語を足すコストを最小化する。

## Prerequisites
- [02 Python Support](02-python-support.md) 完了

## Steps

### 1. Language モジュールの抽象化

`lib/lang/lang.ml`:
```ocaml
module type S = sig
  val extensions : string list
  (** "[.ts; .tsx]" や "[.py]" *)

  val parse : string -> Ts_binding.Tree.t
  (** ソース文字列 → tree-sitter ツリー *)

  val to_ir : Ts_binding.Node.t -> Ir.Node.t
  (** tree-sitter ノード → 言語非依存 IR *)

  val name : string
  (** "typescript" / "python" *)
end
```

各言語が `Lang.S` を実装するモジュールになる。

### 2. 既存実装をシグネチャに合わせる

`lib/lang/typescript.ml`:
```ocaml
include Ts_adapter
let name = "typescript"
let extensions = [".ts"; ".tsx"]
let parse src = Ts_binding.parse_typescript src
let to_ir n = of_ts_node n
```

`lib/lang/python.ml`:
```ocaml
include Python_adapter
let name = "python"
let extensions = [".py"]
let parse src = Ts_binding.parse_python src
let to_ir n = of_ts_node n
```

### 3. 言語レジストリ

`lib/lang/registry.ml`:
```ocaml
let all : (module Lang.S) list = [
  (module Typescript);
  (module Python);
]

let for_extension ext : (module Lang.S) option =
  List.find_opt (fun m ->
    let module L = (val m : Lang.S) in
    List.mem ext L.extensions
  ) all

let for_path path = for_extension (Filename.extension path)

let names () = List.map (fun m ->
  let module L = (val m : Lang.S) in L.name) all
```

新言語を足すには:
1. `lib/lang/foo.ml` を作って `Lang.S` を実装
2. `registry.ml` の `all` に 1 行追加

これだけにする。

### 4. パイプライン全体を言語非依存に

`lib/pipeline.ml`:
```ocaml
let analyze_file path : file_report =
  match Registry.for_path path with
  | None -> { path; parse_error = Some "unsupported language"; functions = [] }
  | Some (module L) ->
      let src = read_file path in
      let tree = L.parse src in
      if Ts_binding.Tree.has_error tree then
        { path; parse_error = Some "syntax errors"; functions = [] }
      else
        let ir = L.to_ir (Ts_binding.root tree) in
        let fns = Functions.collect ir
                  |> List.map (annotate_metrics) in
        { path; parse_error = None; functions = fns }
```

ここまで来ると `Pipeline.analyze_file` は言語の存在を知らない。

### 5. 共通 IR の確認

`Ir.Node.kind` が共通でないと指標ロジックが分岐だらけになる。Phase 2 / 4 で導入した kind を再確認:

```ocaml
type kind =
  | Function of { name : string option }
  | If
  | For
  | While
  | Switch          (* SonarSource Cog 用 *)
  | SwitchCase
  | TryCatch
  | Ternary
  | LogicalAnd
  | LogicalOr
  | NullishCoalescing
  | Other of string
```

Python の `and`/`or` も、TypeScript の `&&`/`||` も、同じ `LogicalAnd`/`LogicalOr` に落ちる。

### 6. 言語ごとの差分ルール（明文化）

`docs/language-rules.md`:

```markdown
# 言語別の分岐数え方

## 共通
- `If` / `For` / `While` / `SwitchCase` / `TryCatch` / `Ternary` で +1
- `LogicalAnd` / `LogicalOr` / `NullishCoalescing` で +1

## TypeScript 固有
- `??` を分岐として数える
- `?.` (Optional chaining) は数えない
- `switch` の `default` は数えない

## Python 固有
- `with` は数えない（リソース管理）
- 内包表記の `if` は数える
- `match` / `case` は switch と同様（case 数で +1）
```

### 7. テストハーネスの拡張

`tests/<lang>/` ディレクトリで言語別にケースを管理。同じ `dune runtest` で全部走らせる。

```
tests/
├── typescript/
│   ├── 01-flat.ts
│   └── ...
└── python/
    ├── 01-flat.py
    └── ...
```

期待値ファイルも言語ごとに `expected.yaml` を置く。

### 8. CLI への影響

`--language LANG` フラグで明示指定を許可する（拡張子が変則的なケース用）。

```bash
ariadne --language=typescript snippet.txt
```

レジストリに `for_name` も追加。

```ocaml
let for_name name =
  List.find_opt (fun m ->
    let module L = (val m : Lang.S) in L.name = name
  ) all
```

## Verification

- [ ] `lib/pipeline.ml` から言語名がコードに出現しない（registry 経由）
- [ ] 第 3 言語を仮で `lib/lang/dummy.ml` として足してみて、registry に 1 行加えるだけで動く
- [ ] 同じテスト基盤で TS / Python ケース両方が走る
- [ ] `docs/language-rules.md` に差分が明示されている

## Pitfalls / Tips
- 「first-class module」（`(module ...)`）のシンタックスに最初は面食らう — Phase 0 のファンクタ理解がここで活きる
- IR を厚くしすぎない — 共通指標で使う kind に絞る
- 言語追加コストを「実測」できるとよい — 1 言語追加に何時間かかるかを記録しておくと、後で技術ブログ材料になる

## Outputs
- `lib/lang/` の各言語モジュール
- `Registry` モジュール
- `docs/language-rules.md`

## Next
- [04 Documentation & Distribution](04-documentation-distribution.md)
