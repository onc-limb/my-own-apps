# Phase 4 / 04 — Report Output

## Goal
人間向け（terminal）と機械向け（JSON）の両出力を整え、複数ファイルにわたるサマリーを出せるようにする。後段の CI 連携・ダッシュボード化の土台を作る。

## Prerequisites
- [03 Configuration](03-configuration.md) 完了

## Steps

### 1. 出力データのモデル

```ocaml
type metric_value = { value : int; threshold : int option; over : bool }

type function_report = {
  name : string;
  start_line : int;
  end_line : int;
  lines : metric_value;
  cyclomatic : metric_value;
  cognitive : metric_value;
}

type file_report = {
  path : string;
  parse_error : string option;
  functions : function_report list;
}

type summary = {
  files_total : int;
  files_with_errors : int;
  functions_total : int;
  cc_max : int;
  cc_avg : float;
  cog_max : int;
  cog_avg : float;
  violations_total : int;
}

type report = {
  files : file_report list;
  summary : summary;
  thresholds : Thresholds.t;
  generated_at : string;
}
```

両形式とも同じ `report` を経由する。

### 2. テキスト出力

```
Ariadne report — 2026-05-26 12:34

=== src/foo.ts (3 functions) ===
function           range    loc   cc   cog
User#init          10-30    21    2    1
User#process       33-92    60    18*  9
User#cleanup       95-100   6     1    0
  (* exceeds threshold)

=== src/bar.ts (2 functions) ===
...

--- Summary ---
files:           12 (errors: 0)
functions:       78
cc max / avg:    22 / 5.4
cog max / avg:   28 / 4.1
violations:      3
```

ファイルが多いときに「違反のあるファイルだけ詳細を出す」`--quiet` モードも有用。

### 3. JSON 出力

スキーマを `docs/json-schema.md` に固定する。

```json
{
  "generatedAt": "2026-05-26T12:34:56Z",
  "thresholds": { "cyclomatic": 15, "cognitive": 20, "lines": 80 },
  "files": [
    {
      "path": "src/foo.ts",
      "parseError": null,
      "functions": [
        {
          "name": "User#process",
          "startLine": 33,
          "endLine": 92,
          "lines": { "value": 60, "threshold": 80, "over": false },
          "cyclomatic": { "value": 18, "threshold": 15, "over": true },
          "cognitive": { "value": 9, "threshold": 20, "over": false }
        }
      ]
    }
  ],
  "summary": {
    "filesTotal": 12,
    "filesWithErrors": 0,
    "functionsTotal": 78,
    "ccMax": 22,
    "ccAvg": 5.4,
    "cogMax": 28,
    "cogAvg": 4.1,
    "violationsTotal": 3
  }
}
```

OCaml 標準で書ける。`Buffer` を使って手書きでもよいし、`yojson` を使ってもよい。

```bash
opam install -y yojson
```

### 4. 出力先

- `--output FILE` で書き出す（指定しなければ stdout）
- 表は `stdout`、ログは `stderr` を維持
- パイプで `jq` などに渡せる前提

### 5. 違反のハイライト

テキスト出力では違反箇所に `*` を付け、色対応時は赤で表示する。`Output.color_mode` がここで効く。

```ocaml
let format_cc r =
  let v = string_of_int r.cyclomatic.value in
  let v = if r.cyclomatic.over then v ^ "*" else v in
  if r.cyclomatic.over && Color.enabled then Color.red v else v
```

### 6. サマリー統計の計算

```ocaml
let summarize files =
  let fns = List.concat_map (fun f -> f.functions) files in
  let cc_vals = List.map (fun f -> f.cyclomatic.value) fns in
  let cog_vals = List.map (fun f -> f.cognitive.value) fns in
  let avg xs =
    let n = List.length xs in
    if n = 0 then 0.0
    else float_of_int (List.fold_left (+) 0 xs) /. float_of_int n
  in
  let max_or_zero = List.fold_left max 0 in
  {
    files_total = List.length files;
    files_with_errors = List.length (List.filter (fun f -> f.parse_error <> None) files);
    functions_total = List.length fns;
    cc_max = max_or_zero cc_vals;
    cc_avg = avg cc_vals;
    cog_max = max_or_zero cog_vals;
    cog_avg = avg cog_vals;
    violations_total = List.fold_left (fun acc f ->
      acc + List.length (List.filter (fun fn ->
        fn.cyclomatic.over || fn.cognitive.over || fn.lines.over
      ) f.functions)) 0 files;
  }
```

### 7. 安定したフォーマット

JSON のキー順は固定（`yojson` は OrderedJson 的に書く）。CI の差分が読みやすい。
`generatedAt` を含めると差分が常に出てしまうので `--no-timestamp` フラグを用意するか、テスト出力では JSON から除外する。

## Verification

- [ ] テキスト出力でファイルごとのセクションが見やすい
- [ ] サマリーが末尾に出る
- [ ] JSON 出力が `jq` で問題なく扱える
- [ ] `--output report.json` でファイル出力できる
- [ ] パースエラーがあったファイルが `parseError` フィールドで分かる

## Pitfalls / Tips
- JSON のフィールド名は `camelCase` で統一する（外部ツール連携の慣習）
- 整数 / 浮動の混在で読み手が困らないよう、平均値は固定で `Float` にする
- 出力スキーマは Phase 5 で外部に晒される — 将来の互換性のため `version` フィールドの追加も検討

## Outputs
- 統一的な `report` 型と両 renderer
- `docs/json-schema.md`

## Next
- [05 Error Handling & Robustness](05-error-handling.md)
