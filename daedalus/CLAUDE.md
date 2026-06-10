# daedalus — Claude Code Rules

> クラウドインフラ構築エージェント。インフラ構成（spec）を与えると Terraform を生成して
> デプロイし、エラーが出たら受け取って修正し再デプロイする——を繰り返す。
> ルート `../CLAUDE.md` の共通ルールに従いつつ、本アプリ固有の方針を以下に定める。

## アーキテクチャ（路線B）

中核ループは **ヘッドレス Claude Code を Claude Agent SDK で制御**して実現する。
LLM のツール使用ループ（Bash で `terraform` 実行 → stderr を読む → `.tf` を編集 → 再実行）は
Claude Code 本体が自律的に回す。**このループを自前で実装しない**。

daedalus 自身の責務:
1. **構成入力** — spec（YAML）→ タスクプロンプト（`config.py` / `prompts.py`）。`${VAR}` で環境変数参照可
2. **ガードレール＋承認ゲート** — PreToolUse フックで apply/destroy をモード別に gate（`guardrails.py`）
3. **試行履歴の記録** — JSONL + Markdown サマリ（`journal.py`）
4. **GitHub 連携** — プロジェクトごとの repo と API で pull/push（`github_sync.py`、git バイナリ不使用）
5. **GUI** — FastAPI + SSE + 素の HTML/JS（`server.py` / `web/`、ビルド工程なし）

## 実行モード（3値ゲート）

- `plan`（デフォルト）: dry-run。apply は deny
- `approval`: apply/destroy は **approve** 判定 → 人間の承認を await（GUI カード / CLI y/N）
- `auto`: 完全自動運転（サンドボックス向け）。apply は allow

`classify_bash` は `allow / deny / approve` の3値を返す純粋関数。テストしやすさのため
フック配線（`agent.py`）と判定ロジック（`guardrails.py`）を分離している。この分離を崩さない。

## 言語・依存

- Python 3.10+ / `claude-agent-sdk`, `pyyaml`, `httpx`, `fastapi`, `uvicorn`
- **パッケージ管理は uv**。依存変更は `uv add` / `uv remove`（pyproject.toml の直接編集より優先）、
  セットアップは `uv sync`、実行は `uv run`。`uv.lock` はコミットする。pip は使わない。
- 認証・アカウント ID はすべて環境変数: `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `GITHUB_OWNER`、クラウド認証はプロバイダのチェーン

## 安全側のデフォルト（重要）

- デフォルトは plan のみ。auto モードはサンドボックスアカウント前提。
- `terraform destroy` は `--allow-destroy` 明示時のみ（approval モードではさらに承認）。
- 危険シェル（`rm -rf`, `sudo`, パイプして sh 等）はフックで一律 deny。
- GitHub push は追加・更新のみ（削除しない）。state/`.tfvars` 等は push 除外。
- GUI は localhost 前提・認証なし。公開しない。

## 開発コマンド

- セットアップ: `uv sync`
- 構文チェック: `uv run python -m py_compile src/daedalus/*.py`
- CLI: `uv run daedalus run <spec> --workspace <dir> [--mode plan|approval|auto]`
- GUI: `uv run daedalus serve` → http://127.0.0.1:8420
- GitHub: `uv run daedalus pull|push <spec> --workspace <dir>`

## 実装方針

- ループや「次に何をするか」の判断ロジックを Python 側に持たせない（Claude Code に委ねる原則）。
  Python が増えてきたら「それは Claude Code 側の責務では？」と立ち止まる。
- ガードレールは**ホワイトリストではなく gate**: terraform は自由に走らせ、apply/destroy と危険シェルだけ止める。
- GUI に重いフレームワークを足さない（ビルド不要を維持）。
