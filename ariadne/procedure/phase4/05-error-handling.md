# Phase 4 / 05 — Error Handling & Robustness

## Goal
実プロジェクトに投入すると必ず出るエラー（パース不能・巨大ファイル・文字コード）に対して **落ちない** ツールを作る。エラーは握りつぶさず、レポートと exit code に正しく現れるようにする。

## Prerequisites
- [04 Report Output](04-report-output.md) 完了

## Steps

### 1. パースエラーの取り扱い

tree-sitter は壊れた入力でも `ERROR` ノードを混ぜたツリーを返す。完全失敗ではないが「正しい」結果ではない。

```ocaml
let has_error_node (root : Ts_binding.Node.t) : bool =
  Ts_binding.Tree.has_error tree   (* ts_tree_root_node_with_offset の派生 *)

(* または再帰で ERROR を探す *)
let rec contains_error n =
  Ts_binding.Node.kind n = "ERROR"
  || List.exists contains_error (Ts_binding.Node.children n)
```

方針:
- ファイル全体がパース不能 → `file_report.parse_error = Some msg` にし、関数解析はスキップ
- 部分エラー（ERROR ノードが少数）→ 警告だけ出して解析は続行（実用上ありがち）

### 2. 各ファイル処理の例外境界

```ocaml
let analyze_file ~config path : file_report =
  try
    let src = read_file path in
    let tree = Ts_binding.parse src in
    if Ts_binding.Tree.has_error tree then
      { path; parse_error = Some "syntax errors detected"; functions = [] }
    else
      let ir = Ts_adapter.of_ts_node (Ts_binding.root tree) in
      { path; parse_error = None;
        functions = Functions.collect ir
                    |> List.map (annotate_with_metrics ~config) }
  with
  | Sys_error msg ->
      { path; parse_error = Some (Printf.sprintf "io: %s" msg); functions = [] }
  | e ->
      { path; parse_error = Some (Printexc.to_string e); functions = [] }
```

**1 ファイルの失敗で全体が落ちないこと** が重要。

### 3. 巨大ファイル対応

10 MB を超えるような minify/bundled ファイルは解析する意味が薄く、tree-sitter のパース時間も伸びる。

```ocaml
let max_file_size = ref 5_000_000  (* 5 MB *)

let check_size path =
  let s = (Unix.stat path).st_size in
  if s > !max_file_size then
    Error (Printf.sprintf "file too large (%d bytes)" s)
  else Ok ()
```

`--max-file-size BYTES` フラグで上書き。デフォルト 5 MB はだいたい妥当な経験則。

### 4. タイムアウト

tree-sitter は通常高速だが、極端な入力で詰まることがある。

```ocaml
let parse_with_timeout ~ms src =
  Ts_binding.set_timeout (ms * 1000);  (* マイクロ秒 *)
  Ts_binding.parse src
```

`ts_parser_set_timeout_micros` を foreign 宣言して呼ぶ。

### 5. エンコーディング

tree-sitter は UTF-8 を前提とする。BOM 付き UTF-8 や UTF-16 で書かれたファイルは壊れる。

```ocaml
let strip_bom s =
  if String.length s >= 3
     && s.[0] = '\xEF' && s.[1] = '\xBB' && s.[2] = '\xBF'
  then String.sub s 3 (String.length s - 3)
  else s
```

UTF-16 検出はマジックバイト（`\xFF\xFE` or `\xFE\xFF`）で。`parse_error` にして処理を続行。

### 6. 進捗表示

ファイル数が多いケースで反応がないと不安。`stderr` に進捗を出す。

```
[ 12 / 128 ] src/components/UserCard.tsx
```

ターミナルなら `\r` で更新、それ以外なら 1 行ずつ出す。

```ocaml
let show_progress = ref false
let report_progress i n path =
  if !show_progress then
    Printf.eprintf "[ %d / %d ] %s\n%!" i n path
```

### 7. エラーの集約レポート

末尾サマリーに「エラーがあったファイル」を別途列挙する。

```
=== Parse errors ===
src/legacy/old.ts  syntax errors detected
src/huge.bundle.js file too large (12345678 bytes)

2 file(s) skipped
```

exit code への影響:
- 違反あり → 1
- パース失敗のみ → 2（不完全な結果）
- 違反もパース失敗も無し → 0

これを `--ignore-parse-errors` フラグで「パース失敗を 0 とみなす」モードに切り替え可能にしておくと、急いで CI に乗せたいときに使える。

## Verification

- [ ] 1 つの壊れたファイルを混ぜても残りは普通に解析される
- [ ] 巨大ファイルが skip されてサマリーに記載される
- [ ] BOM 付きファイルが読める
- [ ] エラー集約が末尾に出る
- [ ] exit code が状況で正しく分かれる

## Pitfalls / Tips
- 「落ちない」を「黙る」と勘違いしない — 必ず `parse_error` に残す
- 例外を全部 catch する範囲を **ファイル単位だけ** に絞る — 全体を try-with で囲うと開発時にバグを見落とす
- 設定ファイルのパースエラーは例外でなく即 exit 2（プログラム全体が動かない問題なので）

## Outputs
- 各ファイルが独立した境界で解析される実装
- サマリーへのエラー集約
- 進捗フラグ `--progress`

## Next
- [06 Performance (Optional)](06-performance.md)
