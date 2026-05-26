# Phase 3 / 05 — Validation

## Goal
ESLint の `complexity` ルール、`eslint-plugin-sonarjs` の `cognitive-complexity` ルールと比較し、Ariadne の出す数値が妥当な範囲に収まることを確認する。エッジケースをテスト化して退行を防ぐ。

## Prerequisites
- [04 Output Formatting](04-output-formatting.md) 完了
- Node.js / npm が使える環境

## Steps

### 1. テストハーネスを置く

`tests/cases/` 配下に小さな `.ts` をたくさん作る。1 ファイル 1 ケース。

```
tests/cases/
├── 01-flat-if.ts
├── 02-nested-if.ts
├── 03-switch.ts
├── 04-logical-and.ts
├── 05-mixed-logical.ts
├── 06-ternary-chain.ts
├── 07-try-catch.ts
├── 08-arrow-in-method.ts
├── 09-empty-fn.ts
├── 10-large-switch.ts
└── expected.yaml
```

`expected.yaml`:
```yaml
- file: 01-flat-if.ts
  function: f
  cc: 2
  cog: 1
- file: 02-nested-if.ts
  function: f
  cc: 4
  cog: 6
```

`dune runtest` でアリアドネの出力と比較する Bash テストでも、`alcotest` を入れて OCaml で書いてもよい。

### 2. ESLint で参照値を取る

```bash
cd tests/eslint
npm init -y
npm install --save-dev eslint eslint-plugin-sonarjs
```

`.eslintrc.json`:
```json
{
  "rules": {
    "complexity": ["error", { "max": 1 }],
    "sonarjs/cognitive-complexity": ["error", 1]
  }
}
```

max を 1 にしておくと **すべての関数で違反扱い**となり、エラー文に各関数の実複雑度が出る。

```bash
npx eslint ../cases/*.ts --rule '{"complexity":["error",1]}' --format json > eslint.json
```

JSON をパースして関数名と複雑度の対応表を作る。

### 3. 比較スクリプト

`tools/compare.sh` 程度で良い。
```bash
ariadne tests/cases/*.ts --format=json > actual.json
node tools/compare.js actual.json eslint.json
```

`compare.js` で「ファイル × 関数」のキーで join し、CC が ±0、Cog が ±2 以内なら OK 程度の許容を持たせる（実装差で完全一致は難しい）。

### 4. エッジケース

下記が落とし穴。テストに必ず入れる。
- 空の関数 `function f() {}` → CC=1, Cog=0
- 単一 return `function f() { return 1; }` → CC=1, Cog=0
- 深いネスト（5 段の `if`）
- 巨大 switch（case 20 個以上）
- `try { } catch (e) { try {} catch {} }` のような catch ネスト
- アロー関数だらけの map/filter/reduce チェーン
- `?? ` と `||` の混在
- IIFE: `(() => { ... })()`

### 5. 既知の差分を文書化

ESLint と完全一致は望まない。差が出る箇所は `docs/known-differences.md` に記録。

```markdown
# Known Differences from ESLint complexity

- ESLint counts `default:` in switch; Ariadne does not.
- ESLint counts `?.` (optional chaining) as branch since v8; Ariadne does not.
- Reason: see `docs/complexity-rules.md`.
```

### 6. 退行テスト

`dune runtest` を走らせるたびにスナップショット比較。`actual.json` と `expected.json` の差分を `diff` で表示。

```
(rule
 (alias runtest)
 (action
  (chdir %{project_root}
   (progn
     (run %{exe:bin/main.exe} --format=json tests/cases/01-flat-if.ts)
     (diff tests/cases/01-flat-if.expected tests/cases/01-flat-if.actual)))))
```

将来テスト追加が楽になる構造を最初に作る。

## Verification

- [ ] 全テストケースで Ariadne の出力が期待値と一致
- [ ] ESLint との比較スクリプトが動き、許容範囲内
- [ ] 差分の説明が `docs/known-differences.md` にある
- [ ] `dune runtest` で退行が検知される

## Pitfalls / Tips
- ESLint の `complexity` は関数名を出さないことがある — 行番号で突き合わせる
- `eslint-plugin-sonarjs` のバージョンで数値が変わることがある — 比較対象を固定する
- 「合わせ込み」を頑張りすぎない。**自分の定義に沿って動いているかが本質**

## Outputs
- `tests/cases/` 配下のテストスニペット
- `tests/expected.yaml`（または `.expected` ファイル群）
- `docs/known-differences.md`

## Next
- Phase 3 完了。roadmap の Completion Criteria を確認
- [Phase 4 / 01 Directory Traversal](../phase4/01-directory-traversal.md)
