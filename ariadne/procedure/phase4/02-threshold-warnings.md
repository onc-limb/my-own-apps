# Phase 4 / 02 — Threshold & Warnings

## Goal
複雑度・行数のしきい値を設定し、超過した関数を警告として可視化する。CI 連携の準備として「exit code 1」を返す動作を作る。

## Prerequisites
- [01 Directory Traversal](01-directory-traversal.md) 完了

## Steps

### 1. しきい値の型定義

`lib/config/thresholds.ml`:
```ocaml
type t = {
  cyclomatic : int;
  cognitive : int;
  lines : int;
}

let default = {
  cyclomatic = 15;
  cognitive = 20;
  lines = 80;
}
```

業界経験則: CC 10-15 で警告、20+ で要対処。デフォルトは「ゆるい警告」寄り。

### 2. CLI フラグ

```
--max-cc N        # 循環的複雑度の上限
--max-cog N       # 認知的複雑度の上限
--max-lines N     # 関数行数の上限
```

```ocaml
let max_cc = ref None
let max_cog = ref None
let max_lines = ref None

let resolve_thresholds () =
  { Thresholds.cyclomatic = Option.value !max_cc ~default:Thresholds.default.cyclomatic;
    cognitive = Option.value !max_cog ~default:Thresholds.default.cognitive;
    lines = Option.value !max_lines ~default:Thresholds.default.lines;
  }
```

### 3. 違反検出

```ocaml
type violation = {
  file : string;
  fn : string;
  metric : [`Cc | `Cog | `Lines];
  actual : int;
  threshold : int;
}

let check_function ~thresholds ~file (fn : fn_info) : violation list =
  let vs = ref [] in
  if fn.cyclomatic > thresholds.Thresholds.cyclomatic then
    vs := { file; fn = fn.name; metric = `Cc;
            actual = fn.cyclomatic;
            threshold = thresholds.cyclomatic } :: !vs;
  if fn.cognitive > thresholds.cognitive then
    vs := { file; fn = fn.name; metric = `Cog;
            actual = fn.cognitive;
            threshold = thresholds.cognitive } :: !vs;
  if fn.lines > thresholds.lines then
    vs := { file; fn = fn.name; metric = `Lines;
            actual = fn.lines;
            threshold = thresholds.lines } :: !vs;
  !vs
```

### 4. 違反のレポート

通常の表に加えて、末尾に違反サマリーを出す。

```
=== Violations ===
src/foo.ts:42  User#update    cc=22 (> 15)
src/bar.ts:10  process        cog=24 (> 20)
src/baz.ts:5   render         lines=120 (> 80)

3 violation(s) in 2 file(s)
```

### 5. exit code

```ocaml
let exit_code violations =
  if violations = [] then 0 else 1

let () =
  let violations = run () in
  exit (exit_code violations)
```

Phase 1 の引数エラー = 2 と区別する。

### 6. しきい値の上書き優先順位

最終的には次の順で解決される。

1. CLI フラグ（最優先）
2. 設定ファイル（Phase 4 / 03 で導入）
3. デフォルト

Phase 4 / 03 と矛盾しないよう、`resolve_thresholds` を「ファイル設定 ← CLI で上書き」に発展できる形にしておく。

### 7. 警告のみ・違反のみモード

```
--warn-only       # 違反があっても exit 0
--quiet           # 違反だけ出す（通常の表を出さない）
```

CI と人間用で挙動を分けられるようにする。

## Verification

- [ ] 違反する関数を含むファイルで exit 1
- [ ] すべて閾値以下の場合は exit 0
- [ ] 違反サマリーが見やすい形で末尾に並ぶ
- [ ] `--max-cc 5` のように低い値を指定すると複数の違反が出る
- [ ] `--warn-only` で違反があっても exit 0

## Pitfalls / Tips
- 違反一覧は **CC 降順** で並べると人が読みやすい
- しきい値の妥当性は元コードによる。`docs/thresholds.md` にデフォルト根拠を書く（McCabe 推奨 10、現代的な許容 15、警報 20）
- exit code は CI で重要な契約。`docs/cli.md` に表として明示する

## Outputs
- 違反検出ロジック
- 違反サマリー出力
- exit code の正しい返却

## Next
- [03 Configuration](03-configuration.md)
