# Phase 0 / 01 — Environment Setup

## Goal
opam / dune / utop / エディタ拡張をそろえ、`dune exec` で "Hello World" が走る最小プロジェクトを用意する。
ただ手順をなぞるだけでなく、**それぞれの道具が何の役割で、なぜ必要なのか**を理解する。道具の地図が頭にあると、後でエラーが出たとき「どの層の問題か」を切り分けられる。

## Prerequisites
- macOS / Linux / WSL2 のいずれかの環境
- Homebrew（macOS の場合）または apt / brew 相当のパッケージマネージャ

## このドキュメントの読み方
環境構築は「動けば正義」になりがちだが、ここでは**各ツールの役割**を一度だけ丁寧に押さえる。
コマンドを打つ前に「これは何をするコマンドか」を読み、打った後に「何が起きたか」を確認する。

---

## OCaml ツールチェインの全体像（先に地図を持つ）

個別コマンドに入る前に、登場人物の役割を掴む。これらは層になっている。

| ツール | 役割 | 例えるなら |
|--------|------|-----------|
| **opam** | OCaml 版のパッケージ＆**コンパイラバージョン管理**ツール | npm + nvm を合わせたもの |
| **switch** | opam が管理する「独立した OCaml 環境」 | プロジェクトごとの仮想環境（venv） |
| **dune** | ビルドシステム。`.ml` をコンパイルし実行ファイルを作る | make / cargo |
| **utop** | 対話的に式を試せる REPL（read-eval-print loop） | Node の対話シェル |
| **merlin / ocaml-lsp-server** | エディタに「型・補完・定義ジャンプ」を提供する頭脳 | 言語サーバ（LSP） |
| **ocamlformat** | コード整形 | prettier / rustfmt |

> **なぜ switch が要るのか**：OCaml はライブラリがコンパイラのバージョンに強く紐づく。プロジェクト A は 5.2.0、B は 4.14、と環境を分けたい。switch はその「分けた環境」一つ一つを指す。

---

## Steps

### 1. opam のインストール

opam は土台。これがないと OCaml のコンパイラもライブラリも入れられない。

macOS:
```bash
brew install opam
```

Linux / WSL2:
```bash
bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"
```

**観察**：`opam --version` が版を返せばインストール成功。

### 2. opam の初期化と switch 作成

```bash
opam init --bare -y          # opam の作業領域(~/.opam)を用意。コンパイラはまだ入れない(--bare)
opam switch create 5.2.0     # 5.2.0 のコンパイラを持つ switch を新規作成
eval $(opam env)             # ★今のシェルに「この switch を使え」と環境変数を流し込む
```

- `opam switch list` で作った switch が `→`（使用中）になっているか確認
- **`eval $(opam env)` の意味**：opam は「どの switch を使うか」をシェルの環境変数（PATH 等）で表現する。この 1 行がそれを現在のシェルに設定する。**シェルを開き直すと消える**ので、`.zshrc` / `.bashrc` に書いておく。

> ここが最頻出のつまずきポイント。後述の Pitfalls 参照。

### 3. dune / utop / lsp / formatter のインストール

作った switch の中に、開発に使う道具を入れる。

```bash
opam install -y dune utop ocaml-lsp-server merlin ocamlformat
```

**観察**：`which dune` / `which utop` が `~/.opam/5.2.0/bin/...` のようなパスを返す。`/usr/bin` でなく **switch 内**を指しているのが正しい状態（switch が効いている証拠）。

### 4. エディタ拡張

VS Code:
- 拡張機能 `OCaml Platform` をインストール
- ワークスペースで `ocaml-lsp-server` が見つかることを確認する

Neovim / Emacs も `ocaml-lsp-server` か `merlin` を経由する。

**なぜ必要か**：型推論言語である OCaml は、**エディタが型を表示してくれること**が学習効率を劇的に変える。「この式の型は何か」を常にホバーで確認できる状態を作るのが、この節の本当のゴール。

### 5. Hello World プロジェクト作成

dune プロジェクトの**最小構造**を理解しながら作る。

```bash
mkdir -p ariadne/playground/hello && cd $_

# dune-project: 「ここがプロジェクトのルート」と dune に教える宣言。lang は dune の文法バージョン
cat > dune-project <<'EOF'
(lang dune 3.0)
EOF

mkdir bin
# bin/dune: この階層に「main という実行ファイルを作る」というビルド指示
cat > bin/dune <<'EOF'
(executable (name main))
EOF

# main.ml: エントリポイント。let () = ... は「unit を返す式を即実行」する慣用句
cat > bin/main.ml <<'EOF'
let () = print_endline "Hello, Ariadne!"
EOF
```

各ファイルの役割：
- **`dune-project`** … プロジェクトの目印。dune はこれを探して「ここがルート」と判断する。
- **`bin/dune`** … 「この `.ml` 群から `main` という実行ファイルを作れ」というレシピ。`(name main)` は `main.ml` を指す。
- **`main.ml`** … 実際のコード。`let () = ...` は「`()`（unit 型）を返す式を束縛＝即実行する」OCaml の `main` 相当の書き方。

### 6. ビルドと実行

```bash
dune build                    # コンパイル。成功すると _build/ が生成される
dune exec ./bin/main.exe      # ビルドして実行。.exe は dune の論理名(OS 問わず)
```

**観察**：`Hello, Ariadne!` が出れば一連の土台が通った証拠。`_build/` ディレクトリが生成されていることも確認（成果物はここに置かれる。手で触らない）。

---

## Verification

- [ ] `dune exec ./bin/main.exe` が `Hello, Ariadne!` を出力する
- [ ] `utop` を起動して `1 + 1;;` が評価でき、`- : int = 2` が返る
- [ ] エディタで `main.ml` を開き、`print_endline` にホバーすると型 `string -> unit` が出る
- [ ] `which dune` が **switch 内のパス**を返す（`/usr/bin` ではない）

---

## 理解度確認問題

> 解答は載せていません。調べた／試した結果と**理由**をメモしてから「レビューして」と声をかけてください。

### Q1. ツールの役割
opam・dune・utop・ocaml-lsp-server のそれぞれを、**一言ずつ**自分の言葉で説明せよ。「npm に例えると」のような対応づけでもよい。

### Q2. switch とは
`opam switch` は何のためにあるか。「プロジェクト A は OCaml 5.2、B は 4.14 を使いたい」という状況を例に説明せよ。

### Q3. `eval $(opam env)` を忘れると
このコマンドを実行せずに `dune build` すると何が起きるか（実際に新しいシェルで試してよい）。**なぜ**そうなるのかを、PATH の観点で説明せよ。

### Q4. dune-project の役割
`dune-project` ファイルを削除して `dune build` するとどうなると予想するか。試して確かめ、このファイルが何のためにあるか述べよ。

### Q5. `let () = ...` の意味
`main.ml` の `let () = print_endline "..."` の `let ()` は何をしているか。`print_endline` の型 `string -> unit` をヒントに、なぜ束縛先が `()` なのかを説明せよ。

---

## Pitfalls / Tips
- **`dune: command not found` の 9 割は `eval $(opam env)` 忘れ**。新しいシェルを開くたびに必要なので、rc ファイルに登録する。「さっきまで動いてたのに別ターミナルで動かない」はこれ。
- WSL2 では Windows 側パス（`/mnt/c/...`）でなく **Linux ホーム内**に置く（I/O が桁違いに速い）。
- OCaml バージョンは **5.x** を選ぶ（roadmap 後半の Domain / Eio は 5 系前提）。
- `_build/` は dune の生成物。`.gitignore` に入れる。中身を手で編集しない。

## Outputs
- 動作確認済みの opam switch（5.x）
- `ariadne/playground/hello/` の最小プロジェクト
- エディタの OCaml 補完・型表示が効く状態

## Next
- [02 Language Fundamentals](02-language-fundamentals.md)
