# daedalus

> クラウドインフラ構築エージェント。
> インフラ構成（spec）を渡すと、Terraform を生成して `plan`／`apply` し、
> エラーが出たら受け取って修正し再実行する——を自律的に繰り返す。

名前は、ギリシャ神話の名工 **Daedalus**（ラビュリントスを設計した建築家）から。
同 repo の `ariadne` と世界観をそろえている。

## しくみ

daedalus はループを自前で持たない。**ヘッドレス Claude Code を Claude Agent SDK で制御**し、
LLM のツール使用ループ（Bash で `terraform` 実行 → エラーを読む → `.tf` を修正 → 再実行）を
Claude Code 本体に回させる。daedalus が担うのは:

1. **構成入力** — spec(YAML) を読み、タスク指示に変換
2. **ガードレール＋承認ゲート** — `apply`/`destroy` をモードに応じて gate し、危険シェルを遮断
3. **記録** — 各 run のイベント・エラー・コストを JSONL で保存
4. **GitHub 連携** — プロジェクトごとのリポジトリと API でコードを pull / push
5. **GUI** — 操作・ライブログ・承認レビュー・履歴のための Web パネル

```
            GUI (FastAPI + SSE)  ←─ 承認 approve/reject ─ あなた
                  │
spec.yaml ──▶ daedalus ──(Agent SDK)──▶ headless Claude Code
                 │                            │  Bash: terraform init/plan/apply
                 │  PreToolUse gate ◀─────────┤  Read/Write/Edit: *.tf
                 │  (mode 別に apply を制御)    │  ↻ エラーを読んで自己修正
                 ▼                            ▼
       GitHub repo (pull/push)          workspace/*.tf, terraform.tfstate
       runs/*.jsonl (履歴)
```

## 実行モード

| モード | apply | 用途 |
|---|---|---|
| `plan`（デフォルト） | ❌ deny | dry-run。`terraform plan` まで。まず構成を確認したいとき |
| `approval` | ⏸ **人の承認後に実行** | 実環境への反映。apply/destroy のたびに GUI / ターミナルで承認 |
| `auto` | ✅ 自動 | **完全自動運転**。一から作る場合やサンドボックスアカウント向け |

`terraform destroy` はどのモードでも `--allow-destroy` を明示したときのみ
（approval モードではさらに承認が必要）。危険シェルは常時 deny。

## セットアップ

パッケージ管理は [uv](https://docs.astral.sh/uv/) を使う。

```bash
cd daedalus
uv sync          # .venv 作成 + 依存インストール（uv.lock 準拠）
```

コマンドは `uv run` 経由で実行する（venv の手動 activate 不要）:

```bash
uv run daedalus serve
```

> 📘 **AWS / Google Cloud / Cloudflare** を対象にした、Terraform 導入から各プロバイダの認証・実行まで
> の手順書は [`docs/setup-guide.md`](docs/setup-guide.md) にある。初めて使うときはこちらを参照。

### 環境変数（アカウント情報はすべてここ）

| 変数 | 必須 | 用途 |
|---|---|---|
| `ANTHROPIC_API_KEY` | ✅ | エージェント実行 |
| `GITHUB_TOKEN` | GitHub 連携時 | API での pull/push（contents read/write 権限の PAT） |
| `GITHUB_OWNER` | GitHub 連携時 | アカウント / Organization 名 |
| `GITHUB_API_URL` | – | GHES 等で API ベースを変える場合 |
| `AWS_*` / `GOOGLE_*` / `ARM_*` 等 | プロバイダ次第 | クラウド認証（プロバイダの認証チェーンに委ねる） |

spec 内の値は `${VAR}` 形式で環境変数を参照できる（アカウント ID をファイルに書かない）。

## 使い方

### GUI（操作・レビュー）

```bash
uv run daedalus serve     # → http://127.0.0.1:8420
```

- Spec を貼ってモードを選び **実行**。ログがリアルタイムに流れる
- approval モードでは **承認カード**が出る（直前の plan 出力つき）→ ✅承認 / ❌却下
- GitHub の pull / push も手動操作できる。実行時に「実行前 pull」「成功後 push」も選択可

### CLI

```bash
# dry-run（デフォルト）
uv run daedalus run examples/spec.example.yaml --workspace ./workspace

# 承認モード（apply のたびにターミナルで y/N）
uv run daedalus run <spec> --workspace <dir> --mode approval

# 完全自動運転（サンドボックス向け）
uv run daedalus run <spec> --workspace <dir> --mode auto

# GitHub 連携（spec の github: 設定を使用）
uv run daedalus pull <spec> --workspace <dir>
uv run daedalus push <spec> --workspace <dir> -m "update infra"
```

## プロジェクトごとの GitHub 管理

spec に `github:` を書くと、そのプロジェクトのコードを API 経由で取得・プッシュできる
（git バイナリ不要・トークンはメモリ内のみ）:

```yaml
github:
  repo: my-infra-project
  owner: ${GITHUB_OWNER}   # 省略時も GITHUB_OWNER を使う
  branch: main
```

- **pull**: ブランチの tarball を workspace に展開
- **push**: Git Data API で blob/tree/commit を作成（**追加・更新のみ**。リポジトリ側のファイル削除はしない）。
  state ファイル・`.terraform/`・`.tfvars`・`.daedalus/` は push 対象から除外

## 安全について

- デフォルトは **plan のみ**。実リソースは作らない。
- auto モードは承認なしで apply する。**検証用 / サンドボックスアカウントで使うこと**。
- 危険シェル（`rm -rf`, `sudo`, パイプして sh 等）はフックで一律 deny。
- まだ初期版。本番アカウントで使うなら approval モード＋検証済み spec で。

詳細は [`docs/concept.md`](docs/concept.md) / [`docs/architecture.md`](docs/architecture.md) を参照。
今後の機能アイデア（ユーザー/作者/管理者/エンジニア/ビジネスの5目線）は
[`docs/feature-ideas.md`](docs/feature-ideas.md) にまとめてある。
