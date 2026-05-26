# Phase 4 / 03 — Configuration

## Goal
プロジェクトごとに設定を持てるよう、設定ファイル形式・読み込み・CLI 上書きを整える。

## Prerequisites
- [02 Threshold & Warnings](02-threshold-warnings.md) 完了

## Steps

### 1. 設定ファイル形式の選定

候補:
- YAML（人気・コメント可）
- TOML（軽量・コメント可）
- JSON（標準・コメント不可）

**推奨: YAML**。コメントで「なぜこの値か」を残せる。`yaml` opam パッケージで読める。

```bash
opam install -y yaml
```

### 2. ファイル名

優先順位で読む。

1. `--config PATH` で指定されたファイル
2. プロジェクトルート（カレント）の `ariadne.yaml`
3. プロジェクトルートの `.ariadne.yaml`
4. なければデフォルトを使う

### 3. スキーマ

`ariadne.yaml`:
```yaml
# Ariadne configuration

thresholds:
  cyclomatic: 15
  cognitive: 20
  lines: 80

exclude:
  - "node_modules/**"
  - ".git/**"
  - "dist/**"
  - "**/*.generated.ts"
  - "**/*.d.ts"

extensions:
  - .ts
  - .tsx

format: text       # text | json
color: auto        # auto | always | never
sort: cc           # name | lines | cc | cog
```

### 4. 設定型

`lib/config/config.ml`:
```ocaml
type t = {
  thresholds : Thresholds.t;
  exclude : string list;
  extensions : string list;
  format : Output.format;
  color : Output.color_mode;
  sort : Sort.key;
}

let default = {
  thresholds = Thresholds.default;
  exclude = ["node_modules/**"; ".git/**"; "**/*.d.ts"];
  extensions = [".ts"; ".tsx"];
  format = Output.Text;
  color = Output.Auto;
  sort = Sort.Cc;
}
```

### 5. YAML パース

```ocaml
let load path =
  let ic = open_in path in
  let s = really_input_string ic (in_channel_length ic) in
  close_in ic;
  match Yaml.of_string s with
  | Ok y -> parse_yaml y
  | Error (`Msg m) -> Error (Printf.sprintf "%s: %s" path m)

let parse_yaml y =
  (* dictionary lookup でフィールドを取り出し、無ければデフォルト *)
  ...
```

`Yaml.value` は `[`Null | `Bool of bool | `Float of float | `String of string | `A of value list | `O of (string * value) list ]`。`O` のフィールドルックアップでマッピングするだけ。

### 6. マージのルール

```
default → file config → CLI flags
```

後勝ち。実装は単純に「Option を使って、Some なら上書き」。

```ocaml
let merge_thresholds ~cli ~file =
  { Thresholds.
    cyclomatic = Option.value cli.cyclomatic ~default:file.Thresholds.cyclomatic;
    cognitive = Option.value cli.cognitive ~default:file.cognitive;
    lines = Option.value cli.lines ~default:file.lines;
  }
```

### 7. 未知フィールドの扱い

タイポを見つけやすくするため **警告を stderr に出す**。fatal にはしない（前方互換を意識）。

```ocaml
let warn_unknown_keys ~known yaml_obj =
  List.iter (fun (k, _) ->
    if not (List.mem k known) then
      Printf.eprintf "warning: unknown config key '%s'\n" k
  ) yaml_obj
```

### 8. リファレンスドキュメント

`docs/config-reference.md` を書き、各キーの意味・デフォルト・例を網羅。Phase 5 の Documentation セクションで仕上げる前段。

## Verification

- [ ] `ariadne.yaml` を置いてしきい値を変更すると挙動が変わる
- [ ] `--max-cc 5` で `ariadne.yaml` の値を上書きできる
- [ ] 未知キーで stderr に警告が出るが処理は続行する
- [ ] 設定ファイルが無くてもデフォルトで動作する
- [ ] YAML パースエラーで exit 2、わかりやすいメッセージ

## Pitfalls / Tips
- YAML は字下げに敏感 — エラー時の行番号と列番号を見せる
- 設定の階層化（ホーム → プロジェクト）も将来欲しくなる — 関数を一段ラップしておけば足せる
- 「設定 = 振る舞いの一級表現」。CLI フラグで指定したものを `--show-config` で吐き出せると便利

## Outputs
- `lib/config/config.ml`
- サンプル `ariadne.yaml` を `docs/` に置く
- `docs/config-reference.md` の下書き

## Next
- [04 Report Output](04-report-output.md)
