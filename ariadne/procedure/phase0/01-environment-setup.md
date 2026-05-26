# Phase 0 / 01 — Environment Setup

## Goal
opam / dune / utop / エディタ拡張をそろえ、`dune exec` で "Hello World" が走る最小プロジェクトを用意する。

## Prerequisites
- macOS / Linux / WSL2 のいずれかの環境
- Homebrew（macOS の場合）または apt / brew 相当のパッケージマネージャ

## Steps

### 1. opam のインストール

macOS:
```bash
brew install opam
```

Linux / WSL2:
```bash
bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"
```

### 2. opam の初期化

```bash
opam init --bare -y
opam switch create 5.2.0
eval $(opam env)
```

- `opam switch list` でスイッチが有効か確認する
- シェルの rc ファイルに `eval $(opam env)` を入れておく

### 3. dune / utop / ocaml-lsp-server / merlin のインストール

```bash
opam install -y dune utop ocaml-lsp-server merlin ocamlformat
```

### 4. エディタ拡張

VS Code:
- 拡張機能 `OCaml Platform` をインストール
- ワークスペースで `ocaml-lsp-server` が見つかることを確認する

Neovim / Emacs を使う場合も `ocaml-lsp-server` か `merlin` を経由する。

### 5. Hello World プロジェクト作成

```bash
mkdir -p ariadne/playground/hello && cd $_
cat > dune-project <<'EOF'
(lang dune 3.0)
EOF

mkdir bin
cat > bin/dune <<'EOF'
(executable (name main))
EOF

cat > bin/main.ml <<'EOF'
let () = print_endline "Hello, Ariadne!"
EOF
```

### 6. ビルドと実行

```bash
dune build
dune exec ./bin/main.exe
```

## Verification

- [ ] `dune exec ./bin/main.exe` が `Hello, Ariadne!` を出力する
- [ ] `utop` を起動して `1 + 1;;` が評価できる
- [ ] エディタで `main.ml` を開いたとき、型情報がホバーで出る
- [ ] `which dune` / `which utop` がパスを返す

## Pitfalls / Tips
- `eval $(opam env)` を忘れると `dune: command not found` が出る。新しいシェルを開くたびに必要なら rc ファイルに登録する
- WSL2 では Windows 側のパスでなく Linux ホームディレクトリ内に置く（I/O 速度のため）
- OCaml バージョンは `5.x` を選ぶ（roadmap 後半の Domain / Eio は 5 系前提）

## Outputs
- 動作確認済みの opam switch
- `ariadne/playground/hello/` の最小プロジェクト
- エディタの OCaml 補完が効く状態

## Next
- [02 Language Fundamentals](02-language-fundamentals.md)
