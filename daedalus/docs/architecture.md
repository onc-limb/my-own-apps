# daedalus — アーキテクチャ

## 全体像

```
                ┌──────────────────────── daedalus (Python) ────────────────────────┐
                │                                                                    │
 spec.yaml ──▶  │  config.Spec ──▶ prompts.build_task_prompt ──┐                     │
                │  RunConfig    ──▶ prompts.build_system_prompt ─┤                    │
                │                                                ▼                    │
                │                                   claude_agent_sdk.query()          │
                │                                                │                    │
                │   guardrails.classify_bash ◀── PreToolUse hook │  (Agent SDK)       │
                │   journal.RunJournal       ◀── Post/streaming  ▼                    │
                │                                   ┌─────────────────────────┐       │
                │                                   │  headless Claude Code   │       │
                │                                   │  Bash: terraform ...    │──▶ workspace/*.tf
                │                                   │  Read/Write/Edit: *.tf  │──▶ terraform.tfstate
                │                                   │  ↻ read error, self-fix │       │
                │                                   └─────────────────────────┘       │
                └────────────────────────────────────────────────────────────────────┘
```

## モジュール

| ファイル | 責務 |
|---|---|
| `config.py` | `Spec`（作りたいもの）と `RunConfig`（どう動かすか）。YAML ロード。安全側デフォルト。 |
| `prompts.py` | spec → タスクプロンプト、RunConfig → システムプロンプト（apply/destroy 可否を反映）。 |
| `guardrails.py` | `classify_bash()` — Bash コマンドを allow/deny 判定。純粋関数でテストしやすい。 |
| `journal.py` | `RunJournal` — JSONL イベントログ + Markdown サマリを workspace 下に保存。 |
| `agent.py` | `run_agent()` — Agent SDK を起動し、フックを接続し、ストリームを処理して `RunResult` を返す。 |
| `cli.py` | `daedalus run <spec>` の argparse 入口。env チェック・終了コード。 |

## 制御フロー

1. `cli._run` が spec をロードし `RunConfig` を組む（`ANTHROPIC_API_KEY` を確認）。
2. `agent.run_agent` が workspace を用意し、システム/タスクプロンプトを作る。
3. `ClaudeAgentOptions` に `cwd=workspace`・`allowed_tools`・`permission_mode="acceptEdits"`・
   PreToolUse/PostToolUse フックを設定して `query()` を実行。
4. **Claude Code 本体がループを回す**：`.tf` を書き、`init/validate/plan`(/`apply`) を実行し、
   エラーを読んで自己修正。daedalus はメッセージを stream で受け、記録する。
5. 終了後、`RunResult` と Markdown サマリを残す。

## ガードレール設計（gate 方式）

ホワイトリストではなく **gate**：terraform も通常シェルも自由に走らせ、次だけ止める。

- **危険シェル**（`rm -rf`, `sudo`, パイプして sh 等）→ 常に deny。
- **`terraform apply`** → `--apply` 未指定なら deny（dry-run）。
- **`terraform destroy`** → `--allow-destroy` 未指定なら deny。

deny は PreToolUse フックの戻り値
`{"hookSpecificOutput": {"permissionDecision": "deny", "permissionDecisionReason": ...}}`
で表現し、理由は Claude に渡るので、エージェントは代替手段（plan に留める等）へ切り替えられる。

## 成否判定

PostToolUse フックが Bash 出力を監視し、`Apply complete!` で apply 成功、
`Plan:` / `No changes.` で plan 成功、`Error:` 行を収集する。これにより
SDK の結果だけでなく **terraform の実際の出力** から成否を推定する。

## 既知の前提・限界

- `claude` CLI は `claude-agent-sdk` の wheel に同梱される前提。
- `terraform` バイナリとクラウド認証情報は実行環境に存在する前提（daedalus は埋め込まない）。
- Agent SDK の細かな型（`ResultMessage` のフィールド名等）はバージョンで変わり得るため、
  `agent.py` は `getattr` で防御的に読む。
