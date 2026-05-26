# Phase 5 / 02 — Python Support

## Goal
tree-sitter-python を組み込み、`.py` ファイルに対しても循環的複雑度・認知的複雑度を計算できるようにする。Phase 2 で作った IR + アダプタ設計が本当に通用するかを実証する。

## Prerequisites
- Phase 5 / 01 完了（または並行可）
- 多言語アダプタを差し込めるよう Phase 2 / 04 の IR が確立されている

## Steps

### 1. tree-sitter-python のセットアップ

```bash
cd ariadne/vendor
git clone https://github.com/tree-sitter/tree-sitter-python.git
cd tree-sitter-python
cc -fPIC -c -I src src/parser.c
ar rcs libts_python.a parser.o
```

スキャナがあるなら一緒にコンパイル。`vendor/tree-sitter-python/src/scanner.c` の有無を確認。

### 2. バインディングへの追加

`lib/treesitter/binding.ml`:
```ocaml
let tree_sitter_python =
  foreign "tree_sitter_python" (void @-> returning language_t)
```

`dune` の `foreign_archives` に `ts_python` を追加。

### 3. ノード kind の調査

Python の関数定義系:
- `function_definition` — `def f(...)`
- クラス内の関数も同じ kind（コンテキストで判別）
- `lambda` — ラムダ式

分岐構文:

| 概念 | kind | 備考 |
|------|------|------|
| if | `if_statement` | |
| elif | `elif_clause` | else の下のさらに条件 |
| else | `else_clause` | 加算なし |
| for | `for_statement` | |
| while | `while_statement` | |
| try | `try_statement` | |
| except | `except_clause` | 各 except で +1 |
| with | `with_statement` | **議論あり**（リソース管理であり分岐ではない流派が主流） |
| and / or | `boolean_operator` | operator フィールドで判定 |
| 三項 | `conditional_expression` | `a if b else c` |
| match | `match_statement` | Python 3.10+ |
| case | `case_clause` | match の各 case |
| 内包表記 if | `if_clause` in list_comprehension | **議論あり**（後述） |

### 4. with の扱い

`with` は Python ユーザーには「分岐ではなくスコープ管理」と見られる。**数えない**を採用。
`ASSUMPTIONS.md` に明記。

### 5. 内包表記の if

```python
[x for x in xs if x > 0]
```

この `if` は条件分岐。SonarSource は **数える**。

→ **数える** を採用。`if_clause` を `If` 相当にマッピング。

ただし「内包表記内の分岐」は **構文上はネストしている**ので Cognitive Complexity ではネスト効果も働く（リスト内包 1 段 + if で N=1）。これを Cognitive Complexity ルールにも反映する。

### 6. Python アダプタ

`lib/adapter/python_adapter.ml`:
```ocaml
let rec of_ts_node (n : Ts_binding.Node.t) : Ir.Node.t =
  let kind = classify n in
  { kind;
    start_line = Ts_binding.Node.start_row n + 1;
    end_line = Ts_binding.Node.end_row n + 1;
    children = List.map of_ts_node (Ts_binding.Node.named_children n);
  }

and classify n =
  match Ts_binding.Node.kind n with
  | "function_definition" | "lambda" ->
      Function { name = python_name n }
  | "if_statement" | "elif_clause" | "if_clause" -> If
  | "for_statement" -> For
  | "while_statement" -> While
  | "except_clause" -> TryCatch
  | "conditional_expression" -> Ternary
  | "case_clause" -> SwitchCase
  | "boolean_operator" ->
      (match Ts_binding.Node.field n "operator" with
       | Some "and" -> LogicalAnd
       | Some "or" -> LogicalOr
       | _ -> Other "boolean_operator")
  | k -> Other k
```

### 7. 言語ディスパッチ

```ocaml
type language = TypeScript | Python

let detect path =
  match Filename.extension path with
  | ".ts" | ".tsx" -> Some TypeScript
  | ".py" -> Some Python
  | _ -> None

let adapter_for = function
  | TypeScript -> Ts_adapter.of_ts_node
  | Python -> Python_adapter.of_ts_node

let parse_for = function
  | TypeScript -> Ts_binding.parse_typescript
  | Python -> Ts_binding.parse_python
```

### 8. テスト

`tests/python/01-flat.py`:
```python
def f1(x):
    if x > 0:
        return 1
    return 0
# CC=2, Cog=1
```

`tests/python/02-with.py`:
```python
def f2(path):
    with open(path) as f:
        return f.read()
# CC=1 (with は数えない)
```

`tests/python/03-comprehension.py`:
```python
def f3(xs):
    return [x for x in xs if x > 0]
# CC=2 (内包内の if を数える)
```

## Verification

- [ ] `.py` を渡すと結果が出る
- [ ] テストファイルの期待値と一致する
- [ ] `with` が複雑度に加算されない
- [ ] 内包表記の `if` が加算される
- [ ] `--language` フラグ無しでも拡張子から自動判別される

## Pitfalls / Tips
- Python の `elif` を `if_statement` と別 kind で扱うことを忘れない（tree-sitter での実態を必ずダンプで確認）
- `match` 文は Python 3.10+ — tree-sitter 文法側のバージョンに依存する
- ラムダを「関数」として並べると一覧が荒れる — `--include-lambda` フラグ余地を残しておく

## Outputs
- `lib/adapter/python_adapter.ml`
- Python 用ノード kind 表 `docs/python-node-kinds.md`
- `tests/python/` 配下のテストケース

## Next
- [03 Multi-language Architecture](03-multi-language-architecture.md)
