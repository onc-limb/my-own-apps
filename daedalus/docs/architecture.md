# daedalus — アーキテクチャ

## 全体像

```
        ブラウザ (web/) ── SSE / fetch ──┐
                                         ▼
              ┌──────────────── daedalus (Python) ────────────────────┐
              │  server.py (FastAPI)                                   │
              │   ├ POST /api/runs ───────────┐                        │
              │   ├ GET  /api/runs/{id}/events│ (SSE)                  │
              │   ├ POST /api/approvals/{id} ─┼─▶ future 解決          │
              │   └ POST /api/github/pull|push│                        │
              │                               ▼                        │
 spec.yaml ─▶ │  config.Spec ─▶ prompts ─▶ agent.run_agent()           │
              │                               │  (Agent SDK query)     │
              │   guardrails.classify_bash ◀─ PreToolUse hook          │
              │     allow / deny / approve ──▶ approver await          │
              │   journal.RunJournal ◀── events                        │
              │   github_sync ◀── pull(tarball) / push(Git Data API)   │
              │                               ▼                        │
              │                  ┌─────────────────────────┐           │
              │                  │  headless Claude Code   │           │
              │                  │  Bash: terraform ...    │─▶ workspace/*.tf
              │                  │  ↻ read error, self-fix │           │
              │                  └─────────────────────────┘           │
              └────────────────────────────────────────────────────────┘
```

## モジュール

| ファイル | 責務 |
|---|---|
| `config.py` | `Spec` / `RunConfig` / `Mode(plan・approval・auto)`。spec の `${VAR}` 環境変数展開。 |
| `prompts.py` | spec → タスクプロンプト、モード → システムプロンプト（承認ゲートの存在も伝える）。 |
| `guardrails.py` | `classify_bash()` → `allow / deny / approve` の3値判定。純粋関数。 |
| `terraform_output.py` | terraform plan / tfsec 出力の決定的パーサ（plan サマリ生成・スキャン結果判定）。LLM 不使用。 |
| `agent.py` | `run_agent()` — SDK 起動・フック接続・**承認待ち（approver await）**・ストリーム処理。 |
| `journal.py` | JSONL イベントログ + Markdown サマリ。listener で GUI へも配信。 |
| `github_sync.py` | プロジェクト repo との pull（tarball）/ push（Git Data API）。git バイナリ不要。 |
| `server.py` | FastAPI。Run 管理・SSE・承認 future・GitHub 操作・GUI 配信。 |
| `web/` | 操作パネル（素の HTML/JS、ビルド不要）。承認カード・ライブログ・履歴。 |
| `cli.py` | `run` / `serve` / `pull` / `push` サブコマンド。 |

## 実行モードと承認フロー

`classify_bash` が3値を返す:

- `allow` — そのまま実行
- `deny` — 即ブロック（理由は Claude に渡り、安全な代替へ誘導）
- `approve` — **人間の判断待ち**（approval モードの apply/destroy）

`approve` のとき PreToolUse フックは `approver(request)` を await する。

- **CLI**: ターミナルで y/N を聞く（`asyncio.to_thread(input)`）
- **GUI**: `asyncio.Future` を作って承認カードを配信し、`POST /api/approvals/{id}` で解決

却下時は deny を返し、システムプロンプトの指示により Claude は再試行せず状況を要約して終了する。
run タスク終了時に未解決の承認 future はすべて reject 解決され、ハングしない。

| モード | apply | destroy（--allow-destroy 時） |
|---|---|---|
| plan | deny | deny（フラグに関わらず apply 不可のため実質起きない） |
| approval | approve | approve |
| auto | allow | allow |

### セキュリティスキャンゲート（tfsec）

`classify_bash` の判定とは独立に、PreToolUse フックが **apply に第2のゲート**を掛ける:

- `RunState.security_scan_ok` が False の間、`terraform apply` は deny（理由は Claude に渡り、
  tfsec 実行へ誘導される）。
- PostToolUse が tfsec 出力をパースし、**CRITICAL/HIGH がゼロ**なら `security_scan_ok = True`。
- `.tf` の編集（Write/Edit フック、または Bash の `> / sed -i / tee` 書き込み）でフラグは無効化され、
  再スキャンが必要になる。
- 人間承認より先に評価される（レビュアーには「スキャン済みの plan」だけが届く）。
- tfsec 未導入の環境では run 開始時に警告してゲートを自動無効化。`--no-security-scan` で明示無効化も可。

### plan の人間向けサマリ

PostToolUse が `terraform plan` 出力を `terraform_output.parse_plan_output` で決定的にパースし、
「追加/変更/削除/置換」の件数と対象リソースの日本語サマリを生成する（`plan_summary` イベント）。
サマリは承認カード（`ApprovalRequest.plan_summary`）・GUI ログ・run サマリ（Markdown）に表示され、
削除/置換を含む plan には警告が付く。正規表現ベースで LLM を呼ばないため、追加コスト・遅延ゼロ。

## GitHub 連携（プロジェクトごと）

- spec の `github: {repo, owner?, branch?}` がプロジェクト ↔ リポジトリの対応。
  owner / トークンは環境変数（`GITHUB_OWNER` / `GITHUB_TOKEN`）。
- **pull**: `GET /repos/{o}/{r}/tarball/{branch}` を workspace に展開（パストラバーサル防御つき）。
- **push**: Git Data API で blob → tree（`base_tree` = ブランチ先頭）→ commit → ref 更新。
  ブランチが無ければ作成。**追加・更新のみでファイル削除はしない**（安全側、v1 の制限）。
- push 除外: `.terraform/` `.daedalus/` `.git/` `*.tfstate*` `*.tfvars` `crash.log`。

## GUI サーバ

- Run は同時 1 本（v1）。`RunHandle` がイベント列・承認 future・状態を保持（インメモリ）。
- イベントは journal listener 経由で `RunHandle.events` に集約し、SSE（0.4s ポーリング）で配信。
  永続記録は従来どおり workspace の `.daedalus/runs/*.jsonl|.md`。
- 認証なしの localhost 前提。公開する場合はリバースプロキシ等で保護すること。

## 成否判定

PostToolUse フックが Bash 出力を監視: `Apply complete!` → apply 成功、`Plan:`/`No changes.` → plan 成功、
`Error:` 行を収集。**成功の定義はモード依存**: plan モード = plan が通った、approval/auto = apply 完了。
また直近の出力 tail（最大4KB）を保持し、承認カードに「直前の plan 出力」として表示する。

## 既知の前提・限界

- `claude` CLI は `claude-agent-sdk` の wheel に同梱される前提。
- `terraform` バイナリとクラウド認証情報は実行環境に存在する前提（daedalus は埋め込まない）。
- Agent SDK の細かな型はバージョンで変わり得るため、`agent.py` は `getattr` で防御的に読む。
- 複数 Run の並行実行・リモート state・コストゲートは将来課題。
