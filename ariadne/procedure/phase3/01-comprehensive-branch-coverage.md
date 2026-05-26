# Phase 3 / 01 — Comprehensive Branch Coverage

## Goal
TypeScript の主要分岐構文すべてに対して循環的複雑度を漏れなく加算する。各構文の「数え方」を明文化して `docs/complexity-rules.md` に固める。

## Prerequisites
- Phase 2 完了
- ノード kind 対応表（Phase 2 / 03 で作ったもの）

## Steps

### 1. 対応する構文の表を作る

`docs/complexity-rules.md` に保存:

| 構文 | tree-sitter kind / field | +CC |
|------|---------------------------|-----|
| `if` | `if_statement` | +1 |
| `else if` | （`else` 節内の `if_statement` がそのまま +1）| +1 each |
| `else` | （加算なし） | 0 |
| `for` | `for_statement` | +1 |
| `for...in` | `for_in_statement` | +1 |
| `for...of` | `for_in_statement` または独立 kind（実機で確認） | +1 |
| `while` | `while_statement` | +1 |
| `do...while` | `do_statement` | +1 |
| `switch case` | `switch_case` | +1 / case |
| `switch default` | `switch_default` | 0（"default" は分岐ではないとする）|
| `try` | `try_statement` | 0 |
| `catch` | `catch_clause` | +1 |
| `finally` | （加算なし） | 0 |
| `三項` | `ternary_expression` | +1 |
| `&&` | `binary_expression` op="&&" | +1 |
| `\|\|` | `binary_expression` op="\|\|" | +1 |
| `??` | `binary_expression` op="??" | +1 |
| `?.` | `optional_chain` （後述）| 議論：0 を採用 |

### 2. Optional chaining (`?.`) の扱い

`a?.b` は「a が null/undefined なら short-circuit する」分岐に見えるが、
- ESLint の `complexity` ルールは **数えない**
- SonarSource (Cognitive Complexity 定義者) は **数えない**

→ **数えないことを採用**。`Other "optional_chain"` のまま捨てる。気が変わったら一行で切り替えられる構造にしておく。

### 3. `else if` の数え方

tree-sitter では `if_statement` の `alternative` フィールドにさらに `if_statement` が入る形になる。ネストして再帰で走査すれば自然に +1 ずつ加算される。**特別扱い不要**。

### 4. switch の数え方

McCabe の元定義では「case 数 = 分岐」。default を含める流派と含めない流派がある。ESLint の complexity は default を **含めない**。これに揃える。

### 5. 実装の更新

`lib/adapter/ts_adapter.ml` の `classify` を、上記表に基づいて埋める。漏れがあるとカウントが小さくなるだけなので、テストで気づくようにする（次セクション）。

```ocaml
| "switch_case" -> SwitchCase
| "switch_default" -> Other "switch_default"  (* 数えない *)
| "catch_clause" -> TryCatch
| "try_statement" -> Other "try_statement"
| "optional_chain" -> Other "optional_chain"
```

### 6. 単体テスト

`tests/branch_coverage.ts`:
```typescript
function f1() { return 1; }                              // CC=1
function f2(x: number) { return x > 0 ? 1 : 0; }         // CC=2 (ternary)
function f3(x: number, y: number) {
  return x > 0 && y > 0;                                  // CC=2 (&&)
}
function f4(x: number) {
  switch (x) { case 1: return 1; case 2: return 2; default: return 0; }
}                                                          // CC=3 (case x2)
function f5() {
  try {} catch (e) {} finally {}                          // CC=2 (catch)
}
function f6(x: number) {
  return x ?? 0;                                          // CC=2 (??)
}
```

これらの期待値表を `tests/branch_coverage.expected.txt` などに置き、`dune runtest` で差分が出ないようにする（次フェーズで `alcotest` を入れてもよい）。

### 7. ルール明文化

`docs/complexity-rules.md` の冒頭に:
```markdown
# Cyclomatic Complexity Rules (Ariadne)

Base value: 1 per function.
Each of the following adds 1:

- `if_statement` (each occurrence, includes else-if chains)
- `for_statement`, `for_in_statement`
- `while_statement`, `do_statement`
- each `switch_case` (excludes default)
- `catch_clause`
- `ternary_expression`
- `binary_expression` with operator `&&`, `||`, `??`

Not counted: optional chaining `?.`, `switch_default`, `else` alone, `try`/`finally`.

References: McCabe (1976), ESLint complexity rule.
```

## Verification

- [ ] テストファイルの全関数で期待 CC と一致
- [ ] 明文化されたルールがレポジトリ内のドキュメントに存在する
- [ ] 加算ルール変更は `Ts_adapter.classify` の 1 箇所で完結する（散在していない）

## Pitfalls / Tips
- TypeScript の文法バージョン違いで kind 名が変わることがある — ダンプを優先する
- `else if` を特殊扱いしようとすると逆に壊れる — 普通に再帰させる
- ルールは「自分のツールが何を採用しているか」が説明できれば良い。業界標準と一致する必要はない

## Outputs
- `docs/complexity-rules.md`
- `tests/branch_coverage.ts` と期待値

## Next
- [02 Function/Method Granularity](02-function-method-granularity.md)
