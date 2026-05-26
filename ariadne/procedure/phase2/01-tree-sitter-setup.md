# Phase 2 / 01 — tree-sitter Setup

## Goal
tree-sitter 本体と tree-sitter-typescript 文法をローカルにセットアップし、OCaml から呼び出すバインディング方針を決める。

## Prerequisites
- Phase 1 完了
- `cc`（C コンパイラ）が使える環境
- `git` / `make` が入っている

## Steps

### 1. tree-sitter 本体のインストール

macOS:
```bash
brew install tree-sitter
```

Linux / WSL2:
```bash
git clone https://github.com/tree-sitter/tree-sitter.git
cd tree-sitter
make
sudo make install
```

`tree-sitter --version` が動けば OK。

### 2. tree-sitter-typescript 文法

文法は別リポジトリで配布されている C ソース。
```bash
mkdir -p ariadne/vendor
cd ariadne/vendor
git clone https://github.com/tree-sitter/tree-sitter-typescript.git
```

`tree-sitter-typescript/typescript/src/parser.c` と `scanner.c` が本体。これを自分のビルドからリンクする。

### 3. C レベルで先に動作確認する

OCaml バインディングに進む前に、まず C で「TypeScript をパースして root node を取れる」ことを確認しておくと FFI のデバッグが楽。

`vendor/sandbox/main.c`:
```c
#include <tree_sitter/api.h>
#include <stdio.h>

TSLanguage *tree_sitter_typescript(void);

int main() {
  TSParser *p = ts_parser_new();
  ts_parser_set_language(p, tree_sitter_typescript());
  const char *src = "function add(a, b) { return a + b; }";
  TSTree *tree = ts_parser_parse_string(p, NULL, src, (uint32_t)strlen(src));
  TSNode root = ts_tree_root_node(tree);
  char *s = ts_node_string(root);
  printf("%s\n", s);
  free(s);
  ts_tree_delete(tree);
  ts_parser_delete(p);
  return 0;
}
```

```bash
cc main.c \
  vendor/tree-sitter-typescript/typescript/src/parser.c \
  vendor/tree-sitter-typescript/typescript/src/scanner.c \
  -I/usr/local/include \
  -L/usr/local/lib -ltree-sitter \
  -o tsdump
./tsdump
```

ノード構造が出力されればハードウェア・文法側は問題なし。

### 4. OCaml バインディング方針の選択

選択肢:

| 方針 | 概要 | コスト | 学習量 |
|------|------|--------|--------|
| (A) 既存 ocaml-tree-sitter | 自動生成バインディング系 | 低 | 中 |
| (B) ctypes で薄く包む | C API を直接 OCaml から呼ぶ | 中 | 高 |
| (C) external 宣言 + C スタブ | 最も低レベル | 高 | 高 |

**推奨: (B) ctypes**。
- 学習が一番ロードマップの "FFI を理解する" 目的に合う
- 既存 ocaml-tree-sitter は活発さに波があり、ハマったときの脱出ルートが C API 直叩きになる
- Phase 2 の本義（FFI の仕組みを体得する）に最も近い

### 5. ctypes インストール

```bash
opam install -y ctypes ctypes-foreign
```

### 6. ビルド構成の最小骨格

`vendor/dune`（手で書いてもよい / コピーして使い回す）:
```
(rule
 (targets ts-typescript.o)
 (deps tree-sitter-typescript/typescript/src/parser.c
       tree-sitter-typescript/typescript/src/scanner.c)
 (action
  (run %{cc} -c -o %{targets}
        tree-sitter-typescript/typescript/src/parser.c
        tree-sitter-typescript/typescript/src/scanner.c)))
```

実際のビルドは [02 FFI / Binding](02-ffi-binding.md) で詰める。ここでは「どのファイルをどうつなぐかの地図」を持って次へ進む。

## Verification

- [ ] `tree-sitter --version` が動く
- [ ] `vendor/tree-sitter-typescript/` がチェックアウトされている
- [ ] C の `tsdump` が動いて TypeScript の AST が出る
- [ ] `opam list ctypes` で ctypes が入っている
- [ ] Phase 2 で使う FFI 方針を選び終わっている

## Pitfalls / Tips
- macOS の Apple Silicon では `pkg-config tree-sitter --cflags --libs` でパスを取るのが確実
- tree-sitter-typescript は `typescript/` と `tsx/` 2 つの文法を含む。最初は `typescript/` だけでよい
- `scanner.c` のリンクを忘れるとパースが途中で壊れる（外部スキャナ依存の構文がある）

## Outputs
- `vendor/tree-sitter-typescript/` のチェックアウト
- 動作確認済みの C サンドボックスバイナリ
- 採用する FFI 方針のメモ（ASSUMPTIONS.md に追記推奨）

## Next
- [02 FFI / Binding](02-ffi-binding.md)
