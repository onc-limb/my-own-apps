# Phase 3 / 04 — Output Formatting

## Goal
表形式の整形・ソート・カラー表示を整え、ツールとしての見た目を「使ってみたい」レベルに引き上げる。Phase 4 のレポート機能の土台にする。

## Prerequisites
- [03 Cognitive Complexity](03-cognitive-complexity.md) 完了

## Steps

### 1. 表形式の整形

列幅は内容から決める。

```ocaml
let pad_left n s =
  let len = String.length s in
  if len >= n then s else String.make (n - len) ' ' ^ s

let pad_right n s =
  let len = String.length s in
  if len >= n then s else s ^ String.make (n - len) ' '

let print_table headers rows =
  let widths =
    List.mapi (fun i h ->
      List.fold_left (fun acc row ->
        max acc (String.length (List.nth row i))
      ) (String.length h) rows
    ) headers
  in
  let print_row r =
    List.iteri (fun i cell ->
      let w = List.nth widths i in
      if i = 0 then print_string (pad_right w cell)
      else print_string ("  " ^ pad_left w cell)
    ) r;
    print_newline ()
  in
  print_row headers;
  print_row (List.map (fun w -> String.make w '-') widths);
  List.iter print_row rows
```

### 2. ソート機能

CLI フラグで指定可能にする。
```
--sort=cc        # 循環的複雑度の降順
--sort=cog       # 認知的複雑度の降順
--sort=lines     # 行数降順
--sort=name      # 名前昇順（デフォルト）
```

```ocaml
type sort_key = Name | Lines | Cc | Cog

let sort key rows =
  match key with
  | Name -> List.sort (fun a b -> compare a.name b.name) rows
  | Lines -> List.sort (fun a b -> compare b.lines a.lines) rows
  | Cc -> List.sort (fun a b -> compare b.cc a.cc) rows
  | Cog -> List.sort (fun a b -> compare b.cog a.cog) rows
```

### 3. しきい値カラー（任意）

`Unix.isatty Unix.stdout` を確認した上で ANSI を出す。

```ocaml
let red s = Printf.sprintf "\027[31m%s\027[0m" s
let yellow s = Printf.sprintf "\027[33m%s\027[0m" s

let colorize cc =
  let s = string_of_int cc in
  if cc >= 15 then red s
  else if cc >= 10 then yellow s
  else s
```

`--color=auto|always|never` で制御。CI でリダイレクトされる前提で auto を真面目に判定する。

### 4. 表示する列

最低限:
- function（関数名 + 修飾名）
- lines（開始-終了）
- LOC（行数）
- CC
- Cog

行範囲は `100-128` のような表記が読みやすい。

### 5. メタ情報

ファイル名を表のヘッダ前に出す。
```
=== src/foo.ts ===
function           lines   loc   cc  cog
User#add           5-9     5     2   1
User#name [get]    11-13   3     1   1
```

Phase 4 では複数ファイルになるので「ファイルごとのセクション」を作る前提の整形にしておく。

### 6. JSON 出力との分岐

Phase 4 で JSON 出力を本格化するが、ここで `--format=text|json` の分岐点だけ作っておく。

```ocaml
type format = Text | Json
let format_of_string = function
  | "json" -> Json
  | _ -> Text

let render fmt fns =
  match fmt with
  | Text -> render_table fns
  | Json -> render_json fns
```

JSON は最小実装でよい:
```json
{"file": "src/foo.ts", "functions": [{"name": "User#add", "lines": 5, "cc": 2, "cog": 1}]}
```

### 7. CLI 引数の整理

`Arg` モジュールから `cmdliner` への移行も検討する。プロジェクトとしての軽さを優先するなら `Arg` のまま：

```ocaml
let sort_key = ref Cc
let format = ref Text
let color = ref `Auto
let input = ref None

let spec = [
  "--sort", Arg.String (fun s -> sort_key := parse_sort s), "name|lines|cc|cog";
  "--format", Arg.String (fun s -> format := format_of_string s), "text|json";
  "--color", Arg.String (fun s -> color := parse_color s), "auto|always|never";
]
```

## Verification

- [ ] 列幅が正しく自動調整される
- [ ] `--sort=cc` で降順に並ぶ
- [ ] CI 環境（パイプ先）でカラーが出ない
- [ ] `--format=json` で JSON が出る（最低限）

## Pitfalls / Tips
- 関数名にマルチバイトが入ると `String.length` がバイト数になり整列が崩れる — 当面 ASCII 前提で OK だが TODO に残す
- ANSI コードを `printf "%s"` で混ぜると幅計算がずれる — 色付けは整列後の最後に行う
- JSON のキー名は Phase 4 / 5 で固定するつもりで決める（後方互換を意識）

## Outputs
- 整列された表出力
- `--sort` / `--format` / `--color` 対応の CLI
- JSON 出力の最小実装

## Next
- [05 Validation](05-validation.md)
