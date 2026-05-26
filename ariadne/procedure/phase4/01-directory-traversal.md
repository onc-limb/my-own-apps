# Phase 4 / 01 — Directory Traversal

## Goal
ディレクトリを引数に取ると配下の `.ts` / `.tsx` を再帰的に集めて解析する。`node_modules` などの除外をデフォルトで備える。

## Prerequisites
- Phase 3 完了
- 単一ファイルに対する解析が安定して動く

## Steps

### 1. ディレクトリ走査関数

`lib/walker/walker.ml`:
```ocaml
let rec walk ~exclude dir =
  Sys.readdir dir
  |> Array.to_list
  |> List.concat_map (fun name ->
       let path = Filename.concat dir name in
       if exclude path then []
       else if Sys.is_directory path then walk ~exclude path
       else [path])
```

### 2. 拡張子フィルタ

```ocaml
let target_exts = [".ts"; ".tsx"]
let is_target path = List.mem (Filename.extension path) target_exts
```

`walk` の結果を `List.filter is_target` でフィルタする。

### 3. デフォルト除外パターン

最初から組み込むデフォルト:

```ocaml
let default_excludes = [
  "node_modules";
  ".git";
  "dist";
  "build";
  ".next";
  ".turbo";
  ".cache";
]

let default_exclude_suffixes = [
  ".d.ts";
  ".generated.ts";
  ".gen.ts";
]

let excluded ~dirs ~suffixes path =
  let base = Filename.basename path in
  List.exists (fun d -> base = d) dirs
  || List.exists (fun s ->
       let len_s = String.length s in
       let len_p = String.length path in
       len_p >= len_s && String.sub path (len_p - len_s) len_s = s) suffixes
```

### 4. ユーザ指定除外パターン

Phase 4 / 03 の Configuration セクションで詳細化するが、ここでは `--exclude PATTERN` の glob を受け取る形にしておく。

最小実装としては「指定されたパターンを文字列部分一致でチェック」で十分。glob は外部ライブラリ（`re` の glob 変換、`ocamlfind list | grep glob`）を使う。

```bash
opam install -y re
```

```ocaml
let glob_to_regex g = Re.compile (Re.Glob.glob g)
```

### 5. 入力モードの整理

CLI 引数の挙動:
- 引数 1 つがファイル → そのファイルだけ解析
- 引数 1 つがディレクトリ → ディレクトリ再帰
- 引数複数 → それぞれを処理

```ocaml
let expand_input path =
  if Sys.is_directory path then walk ~exclude:default_exclude path
  else [path]
```

### 6. 並べ替えと重複排除

```ocaml
let collect_files inputs =
  List.concat_map expand_input inputs
  |> List.filter is_target
  |> List.sort_uniq compare
```

ファイル順を決定論的にしておくと CI のログ差分が読みやすくなる。

### 7. 進捗ヒント（軽く）

実ファイル数が多くなる前提なので、`stderr` に簡単な進捗を出すフラグを用意。

```ocaml
let verbose = ref false
let log_processing path =
  if !verbose then Printf.eprintf "processing %s\n%!" path
```

## Verification

- [ ] ディレクトリを渡すと再帰スキャンする
- [ ] `node_modules` 配下が結果に含まれない
- [ ] `.d.ts` / `.generated.ts` が除外される
- [ ] `--exclude '**/__tests__/**'` のような glob を受け取れる
- [ ] 引数の順序によらず結果順が決定的

## Pitfalls / Tips
- `Sys.readdir` は `.` `..` を返さないが、シンボリックリンクのループは別途気にする（最初は無視で OK）
- macOS の `.DS_Store` がノイズになる — 除外リストに追加
- glob ライブラリは `re` で十分。`fileutils` でもよい

## Outputs
- `lib/walker/walker.ml`
- デフォルト除外パターン定義
- 複数入力対応の CLI

## Next
- [02 Threshold & Warnings](02-threshold-warnings.md)
