# Phase 5 / 04 — Documentation & Distribution

## Goal
Ariadne を「自分以外でもインストールして使える状態」に仕上げる。README、設定リファレンス、インストール手順、リリースバイナリを揃え、ポートフォリオとして提示できる完成形にする。

## Prerequisites
- Phase 5 / 03 まで完了

## Steps

### 1. README の整備

`ariadne/README.md` に必須:

1. **What** — 1 段落で目的を説明
2. **Why** — 既存の ESLint complexity と何が違うか・なぜ作ったか
3. **Install** — opam / バイナリの両方
4. **Quick start** — 最小コマンドと出力例
5. **Configuration** — `ariadne.yaml` の最小例
6. **CLI Reference** — フラグ一覧（リンク）
7. **Metrics** — CC / Cog の定義と参考文献
8. **Roadmap / Status** — 現時点のサポート言語と既知の制限
9. **License**

スクリーンショット 1 枚（出力サンプル）が効く。

### 2. CLI リファレンス

`docs/cli.md`:

```markdown
# ariadne CLI

## Usage
ariadne [options] PATH [PATH...]

## Options

### Input
- `--language LANG` — 拡張子に依らず言語を強制
- `--exclude GLOB` — 除外パターン（複数指定可）

### Thresholds
- `--max-cc N`
- `--max-cog N`
- `--max-lines N`

### Output
- `--format text|json` — 出力形式
- `--sort name|lines|cc|cog`
- `--color auto|always|never`
- `--output FILE`

### Behavior
- `--warn-only` — 違反でも exit 0
- `--quiet` — 違反のみ表示
- `--progress` — 進捗を stderr に
- `--jobs N` — 並列数
- `--config PATH` — 設定ファイル指定

## Exit codes
- 0: clean
- 1: violations found
- 2: error
```

### 3. 設定リファレンス

`docs/config-reference.md` を完成形に。各フィールド:

```markdown
## thresholds

### thresholds.cyclomatic
- type: integer
- default: 15
- description: 関数当たりの循環的複雑度の上限...

### thresholds.cognitive
- type: integer
- default: 20
...
```

### 4. メトリクスのドキュメント

`docs/metrics.md` に CC / Cog / LOC の定義、Ariadne の数え方ルール、参考文献。
- McCabe 1976
- Sonar Cognitive Complexity ホワイトペーパー
- ESLint complexity rule

### 5. インストール手順

`docs/install.md`:

**opam:**
```bash
opam pin add ariadne https://github.com/USER/ariadne.git
opam install ariadne
```

**Pre-built binary:**
```bash
curl -L https://github.com/USER/ariadne/releases/latest/download/ariadne-$(uname -s)-$(uname -m) \
  -o /usr/local/bin/ariadne
chmod +x /usr/local/bin/ariadne
```

**From source:**
```bash
git clone https://github.com/USER/ariadne.git
cd ariadne
opam install -y . --deps-only
dune build
sudo cp _build/install/default/bin/ariadne /usr/local/bin/
```

### 6. リリースワークフロー

`.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: linux-x86_64
          - os: macos-latest
            target: macos-arm64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: "5.2.0"
      - run: opam install -y . --deps-only
      - run: opam exec -- dune build --release
      - name: Rename
        run: cp _build/default/bin/main.exe ariadne-${{ matrix.target }}
      - uses: softprops/action-gh-release@v2
        with:
          files: ariadne-${{ matrix.target }}
```

タグを打つと GitHub Release にバイナリが上がる。

### 7. opam ファイル

`ariadne.opam`:
```
opam-version: "2.0"
synopsis: "Static analysis: cyclomatic & cognitive complexity for TypeScript/Python"
description: """
Ariadne is a single-binary tool that computes cyclomatic and
cognitive complexity per function across TypeScript and Python codebases.
"""
maintainer: ["You <you@example.com>"]
authors: ["You"]
license: "MIT"
homepage: "https://github.com/USER/ariadne"
bug-reports: "https://github.com/USER/ariadne/issues"
depends: [
  "ocaml" {>= "5.2"}
  "dune" {>= "3.0"}
  "ppxlib"
  "ctypes"
  "ctypes-foreign"
  "re"
  "yaml"
  "yojson"
  "domainslib"
]
build: [["dune" "build" "-p" name "-j" jobs]]
```

将来 opam-repository に publish する場合は本物のリリース URL + checksum が必要。

### 8. ポートフォリオ向けまとめ

`docs/design-notes.md`（任意・推奨）:
- なぜ tree-sitter を選んだか
- なぜ「IR + アダプタ」設計にしたか
- 何が技術的な難所だったか（FFI、Cog のネスト計算、CI 連携）
- 数値で示せる結果（自分のプロジェクトでの違反検出数、リファクタ後の数値推移）

ブログ／ポートフォリオに貼るときの「言語化された設計判断」になる。

## Verification

- [ ] README だけ読めば動かし始められる
- [ ] `docs/cli.md` の全フラグが実装と一致
- [ ] tag push でバイナリが GitHub Release に上がる
- [ ] opam install できる（pin でもよい）
- [ ] `docs/design-notes.md` に「自分のツールの設計判断を一通り言葉で説明」できている

## Pitfalls / Tips
- README は「初見の人が 5 分で使えるか」を基準に書く
- CLI / 設定リファレンスは **実装の真実** に揃える — 嘘ドキュメントが最悪
- リリースバイナリは「静的リンクされているか」を確認する（`ldd` でランタイム依存を見る）

## Outputs
- 完成した README とドキュメント群
- リリースワークフロー
- opam ファイル
- design notes（ポートフォリオ材料）

## Next
- Phase 5 完了 = プロジェクト完成。roadmap 全体の Completion Criteria を確認
- 実プロジェクトの CI で運用を回し続け、改修ネタを `docs/findings.md` に追記し続ける
