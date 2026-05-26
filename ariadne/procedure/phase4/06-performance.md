# Phase 4 / 06 — Performance (Optional)

## Goal
複数ファイル解析を並列化し、OCaml 5 の `Domain` / `Domainslib` または `Eio` を実体験する。1000 ファイル規模で実用速度を出せるようにする。

## Prerequisites
- [05 Error Handling](05-error-handling.md) 完了
- OCaml 5.x を使っている

## Steps

### 1. まずは計測

最適化前に計測する。最初は直列で動かしたまま自分の実プロジェクトに当てる。

```bash
time ./_build/default/bin/main.exe ~/work/project
```

「何秒かかっているか・何がボトルネックか」を見ずに並列化しない。多くの場合 IO（ファイル読み込み）よりパース時間が支配的。

### 2. ライブラリの選択

| 選択肢 | 特徴 | 学習量 |
|--------|------|--------|
| `Thread`（systhreads） | OCaml 4 系互換、GIL 制約あり、並列化効果は限定的 | 低 |
| `Domain`（標準） | 真の並列化、OCaml 5 のみ | 中 |
| `Domainslib.Task` | Domain を pool で抽象化、map/reduce 系 API | 中 |
| `Eio` | 並行 + IO の統合フレームワーク、思想が独特 | 高 |

**推奨: `Domainslib`**。学習負荷とコードの単純さのバランスが最良。

```bash
opam install -y domainslib
```

### 3. ワーカープール

```ocaml
let analyze_all ~config ~num_domains paths =
  let pool = Domainslib.Task.setup_pool ~num_domains () in
  let results =
    Domainslib.Task.run pool (fun () ->
      Domainslib.Task.parallel_map pool ~chunk_size:8
        ~f:(fun path -> Analyzer.analyze_file ~config path)
        (Array.of_list paths)
    )
  in
  Domainslib.Task.teardown_pool pool;
  Array.to_list results
```

### 4. `num_domains` の決め方

```ocaml
let default_domains () =
  let n = Domain.recommended_domain_count () in
  max 1 (n - 1)
```

CLI で `--jobs N` 上書き可能に。`--jobs 1` で従来の直列動作と互換。

### 5. 共有可変状態に注意

進捗カウンタを並列で更新するなら `Atomic` を使う。
```ocaml
let counter = Atomic.make 0
let progress_step () =
  let i = Atomic.fetch_and_add counter 1 in
  Printf.eprintf "[ %d ] processed\n%!" i
```

tree-sitter のパーサインスタンスはスレッドセーフではない場合があるので、**Domain ごとに parser を作る**。

```ocaml
let parse_with_local_parser src =
  let p = Ts_binding.parser_new () in
  Ts_binding.parser_set_language p (Ts_binding.lang_typescript ());
  let tree = Ts_binding.parse p src in
  Ts_binding.parser_delete p;
  tree
```

または `Domain.DLS`（Domain-Local Storage）でドメインごとにキャッシュ。

### 6. 結果集約

`parallel_map` の出力をそのままレポートに渡せばよいので、決定論性も保たれる（入力配列順を維持）。

### 7. ベンチマーク

最終的に
```bash
hyperfine \
  './main.exe --jobs 1 ~/work/project' \
  './main.exe --jobs 4 ~/work/project' \
  './main.exe --jobs 8 ~/work/project'
```

を回し、スループットと CPU 効率を見る。線形には伸びない（パース時間が短いファイルが多いと並列化のオーバーヘッドが効く）。

## Verification

- [ ] `--jobs N` で速度が短くなることが計測できる
- [ ] 同じ入力で `--jobs 1` と `--jobs 8` の出力が **完全一致**する（決定性）
- [ ] 進捗カウンタが race condition なく加算される
- [ ] tree-sitter parser がドメインごとに分離されている

## Pitfalls / Tips
- 並列化で速くなる前提条件は CPU バウンドであること。IO バウンドだと逆効果になることもある
- `Domain` は heavy weight。プールしないで起動・破棄を繰り返さない
- ベンチマーク前に必ず directory cache を温める（cold cache だと IO がボトルネックになって誤判断する）
- tree-sitter C ライブラリのスレッド安全性はバージョン依存。確信が無ければドメインごとに parser 分離

## Outputs
- `--jobs` フラグ
- 並列化された解析パイプライン
- ベンチマーク結果のメモ

## Next
- [07 Real-world Validation](07-real-world-validation.md)
