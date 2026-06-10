# daedalus — Claude Code Rules

> クラウドインフラ構築エージェント。インフラ構成（spec）を与えると Terraform を生成して
> デプロイし、エラーが出たら受け取って修正し再デプロイする——を繰り返す。
> ルート `../CLAUDE.md` の共通ルールに従いつつ、本アプリ固有の方針を以下に定める。

## アーキテクチャ（路線B）

中核ループは **ヘッドレス Claude Code を Claude Agent SDK で制御**して実現する。
LLM のツール使用ループ（Bash で `terraform` 実行 → stderr を読む → `.tf` を編集 → 再実行）は
Claude Code 本体が自律的に回す。**このループを自前で実装しない**。

daedalus 自身の責務は次の3点に絞る:
1. **構成入力の受け取り** — spec（YAML）を読み、タスクプロンプトに変換（`config.py` / `prompts.py`）
2. **ガードレール** — PreToolUse フックで apply/destroy をゲートし、危険シェルを遮断（`guardrails.py`）
3. **試行履歴の記録** — 各 run のイベント・エラー・コストを JSONL で残す（`journal.py`）

## 言語・依存

- Python 3.10+
- `claude-agent-sdk`（`claude` CLI を同梱）、`pyyaml`
- 認証: 環境変数 `ANTHROPIC_API_KEY`

## 安全側のデフォルト（重要）

- **デフォルトは dry-run（`terraform plan` まで）**。実適用は `--apply` を明示したときのみ。
- `terraform destroy` は `--allow-destroy` を明示したときのみ許可。
- 危険シェル（`rm -rf`, `sudo`, パイプして sh に流す等）はフックで一律 deny。
- クラウド認証情報（AWS_*, GOOGLE_*, ARM_* 等）は daedalus がコードに埋め込まず、実行環境の環境変数に委ねる。

## 開発コマンド

- 構文チェック: `python -m py_compile src/daedalus/*.py`
- 実行: `python -m daedalus run examples/spec.example.yaml --workspace ./workspace`
- 実適用: `python -m daedalus run <spec> --workspace <dir> --apply`

## 実装方針

- ループや「次に何をするか」の判断ロジックを Python 側に持たせない（Claude Code に委ねる原則）。
  Python が増えてきたら「それは Claude Code 側の責務では？」と立ち止まる。
- ガードレールは**ホワイトリストではなく gate**: terraform は自由に走らせ、apply/destroy と危険シェルだけ止める。
