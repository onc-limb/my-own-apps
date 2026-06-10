# daedalus

> クラウドインフラ構築エージェント。
> インフラ構成（spec）を渡すと、Terraform を生成して `plan`／`apply` し、
> エラーが出たら受け取って修正し再実行する——を自律的に繰り返す。

名前は、ギリシャ神話の名工 **Daedalus**（ラビュリントスを設計した建築家）から。
同 repo の `ariadne` と世界観をそろえている。

## しくみ

daedalus はループを自前で持たない。**ヘッドレス Claude Code を Claude Agent SDK で制御**し、
LLM のツール使用ループ（Bash で `terraform` 実行 → エラーを読む → `.tf` を修正 → 再実行）を
Claude Code 本体に回させる。daedalus が担うのは次の3点だけ:

1. **構成入力** — spec(YAML) を読み、タスク指示に変換
2. **ガードレール** — `apply`/`destroy` をゲートし、危険シェルを遮断（PreToolUse フック）
3. **記録** — 各 run のイベント・エラー・コストを JSONL で保存

```
spec.yaml ──▶ daedalus ──(Agent SDK)──▶ headless Claude Code
                 │                            │  Bash: terraform init/plan/apply
                 │  PreToolUse guard ◀────────┤  Read/Write/Edit: *.tf
                 │  (apply/destroy gate)      │  ↻ エラーを読んで自己修正
                 ▼                            ▼
            runs/*.jsonl (履歴)          workspace/*.tf, terraform.tfstate
```

## セットアップ

```bash
cd daedalus
python -m venv .venv && source .venv/bin/activate
pip install -e .
export ANTHROPIC_API_KEY=...   # 必須
# クラウド認証は実行環境の環境変数に委ねる（例: AWS_PROFILE / AWS_ACCESS_KEY_ID ...）
```

## 使い方

```bash
# dry-run（plan まで。デフォルト・安全側）
python -m daedalus run examples/spec.example.yaml --workspace ./workspace

# 実際に適用する
python -m daedalus run examples/spec.example.yaml --workspace ./workspace --apply

# 破棄まで許可（注意）
python -m daedalus run <spec> --workspace <dir> --apply --allow-destroy
```

主なオプション:

| フラグ | 既定 | 説明 |
|---|---|---|
| `--workspace DIR` | `./workspace` | Terraform を生成・実行する作業ディレクトリ |
| `--apply` | off | `terraform apply` を許可（未指定なら plan まで） |
| `--allow-destroy` | off | `terraform destroy` を許可 |
| `--max-turns N` | 40 | エージェントの最大反復回数 |
| `--model NAME` | SDK 既定 | `opus` / `sonnet` / `haiku` |

## 安全について

- デフォルトは **plan のみ**。実リソースは作らない。
- `apply`/`destroy` はフラグで明示したときだけ、PreToolUse フックが許可する。
- 危険シェルはフックで一律 deny。
- まだ初期版（v1）。本番アカウントではなく検証用アカウント／ローカルバックエンドで試すこと。

詳細は [`docs/concept.md`](docs/concept.md) / [`docs/architecture.md`](docs/architecture.md) を参照。
