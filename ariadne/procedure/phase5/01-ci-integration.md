# Phase 5 / 01 — CI Integration

## Goal
GitHub Actions で Ariadne を自動実行し、複雑度しきい値超過で PR を落とす運用パイプラインを作る。差分モードと CI 実行最適化も含む。

## Prerequisites
- Phase 4 完了
- GitHub リポジトリで動かす想定

## Steps

### 1. exit code の確定

CI で意味を持つので Phase 4 / 02 で決めた仕様を改めて固定する。

| 状況 | exit |
|------|------|
| 違反なし | 0 |
| 違反あり | 1 |
| エラー（パース不能・ファイル不在等）| 2 |

`docs/cli.md` に明示。

### 2. GitHub Actions ワークフロー（フル解析版）

`.github/workflows/ariadne.yml`:
```yaml
name: Ariadne
on:
  pull_request:
  push:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup OCaml
        uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: "5.2.0"

      - name: Install deps
        run: opam install -y . --deps-only

      - name: Build
        run: opam exec -- dune build

      - name: Run Ariadne
        run: opam exec -- dune exec -- ariadne . --format=json --output=ariadne.json

      - uses: actions/upload-artifact@v4
        with:
          name: ariadne-report
          path: ariadne.json
```

### 3. ビルドキャッシュ

`setup-ocaml` は内部で opam キャッシュを使うが、`dune` ビルドキャッシュは別途。
```yaml
      - uses: actions/cache@v4
        with:
          path: _build
          key: dune-${{ runner.os }}-${{ hashFiles('**/dune-project', '**/dune') }}
```

差分が小さい PR ではビルドキャッシュが効きまくる。

### 4. 配布バイナリ運用（応用）

毎回ビルドするのは遅い。リリースに静的バイナリを置き、CI ではダウンロードする方式に切り替えられる。

```yaml
      - name: Download Ariadne
        run: |
          curl -L https://github.com/USER/ariadne/releases/latest/download/ariadne-linux-x86_64 \
            -o /usr/local/bin/ariadne
          chmod +x /usr/local/bin/ariadne

      - name: Run
        run: ariadne . --format=json --output=ariadne.json
```

リリースに `linux-x86_64`, `linux-arm64`, `macos-arm64` を含める準備は Phase 5 / 04 で。

### 5. 差分モード（PR 内の変更ファイルのみ）

PR では全体スキャンより「触ったファイル」だけ気にしたい。

```bash
git diff --name-only --diff-filter=AM origin/main...HEAD \
  | grep -E '\.(ts|tsx)$' \
  | xargs --no-run-if-empty ariadne --format=text
```

ワークフロー側:
```yaml
      - name: Changed files only
        run: |
          changed=$(git diff --name-only --diff-filter=AM origin/${{ github.base_ref }}...HEAD | grep -E '\.(ts|tsx)$' || true)
          if [ -n "$changed" ]; then
            echo "$changed" | xargs ariadne --format=text
          fi
```

Ariadne 側に `--diff-base REF` を実装してもよい:
```ocaml
let collect_diff_files base =
  let cmd = Printf.sprintf "git diff --name-only --diff-filter=AM %s...HEAD" base in
  ... (* Unix.open_process_in でリストを得る *)
```

### 6. PR コメント投稿

`ariadne.json` を JS で整形して PR コメント。

```yaml
      - uses: actions/github-script@v7
        if: always() && github.event_name == 'pull_request'
        with:
          script: |
            const fs = require('fs');
            const r = JSON.parse(fs.readFileSync('ariadne.json'));
            const violations = r.files
              .flatMap(f => f.functions
                .filter(fn => fn.cyclomatic.over || fn.cognitive.over || fn.lines.over)
                .map(fn => `- ${f.path}:${fn.startLine} ${fn.name} cc=${fn.cyclomatic.value} cog=${fn.cognitive.value}`))
              .join('\n');
            const body = violations
              ? `### Ariadne — ${r.summary.violationsTotal} violation(s)\n\n${violations}`
              : `### Ariadne — clean ✓`;
            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body
            });
```

### 7. レビュー運用ルールの素案

`docs/ci.md` に書く:

- 違反 → CI red、マージ拒否
- 既存違反は `ariadne.yaml` の `legacy-allow` で個別免除可能（実装は将来）
- しきい値変更は別 PR（コードの変更と混ぜない）

## Verification

- [ ] CI ワークフローが PR で自動実行される
- [ ] 違反のある PR が exit 1 で落ちる
- [ ] PR にコメントが投稿される（任意）
- [ ] 差分モードで変更ファイルだけ解析される
- [ ] キャッシュが効いて 2 回目以降のビルドが速い

## Pitfalls / Tips
- `fetch-depth: 0` を忘れると `git diff origin/main...` ができない
- 静的バイナリ配布は Linux musl ビルドで Alpine 系イメージとの互換も確保するなら一工夫
- PR コメントは PR ごとに 1 件にアップサートする方が荒れない（同じユーザの過去コメントを find して edit する）

## Outputs
- `.github/workflows/ariadne.yml`
- 差分モード実装（CLI 側 or shell ラップ）
- PR コメント投稿 script

## Next
- [02 Python Support](02-python-support.md)
