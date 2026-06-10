# 2026-06-10 クラウドインフラ構築エージェント — 言語・アーキテクチャ決定

## 背景・狙い

「インフラ構成を与えると自動で Terraform を生成してデプロイし、エラーが出たら
受け取って修正案を作って再デプロイ、を繰り返すエージェント」を新規アプリとして作る。
ユーザーからの相談ポイントは **使用言語のみ**。新ディレクトリ `daedalus` を作成。

## 検討の流れ（指示と判断の記録）

候補を Python / TS / Go / Rust / ハイブリッドで検討し、ユーザーの問いに沿って前提が二段変わった。

1. 当初は「LLM/エージェントのエコシステムの厚さ」だけ見て **Python** を推奨。
2. ユーザーが Rust を提案 → Rust は単一バイナリ・型の堅さは良いが、**LLM/Agent SDK が最も薄い**
   （Anthropic 公式 Rust SDK が無い）。難所の LLM オーケストレーションで支援が弱いと指摘。
3. ハイブリッド（Rust+Python）案 → **却下**。理由＝このループは「LLM で次手を決める→terraform 実行→
   結果を LLM に戻す」が密結合で、言語境界が**開発中いちばん試行錯誤するホットパス**に乗る。
   疎結合な部品が無いので過剰設計になる。
4. Go の検討 → このプロジェクト限定では Go が好バランス。`hashicorp/terraform-exec` `terraform-json`
   で **Terraform をネイティブ・型付きで扱え**、**公式 `anthropic-sdk-go`** もある。両サイド公式・repo 実績あり。
5. **決定打となったユーザーの指摘**: 「API を使わず `claude -p` を使うなら SDK があっても変わらないのでは？」
   → その通り。`claude -p`（ヘッドレス Claude Code）を subprocess で叩く構成なら、Anthropic **API SDK** の
   言語差は消える。さらに重要なのは、**ヘッドレス Claude Code が描いたループ（apply→stderr読む→.tf修正→再実行）を
   自前実装なしで自律的に回せる**こと。つまりループは作らなくて済む。

## 決定

- **アーキテクチャ: 路線B（ヘッドレス Claude Code を Claude Agent SDK で制御）**
- **言語: Python**（Agent SDK は Python / TS のみ提供。Go/Rust には無い）

理由（なぜ）:
- エージェントの中核ループが Claude Code の標準機能でそのまま賄え、車輪の再発明を避けられる。
- 自前実装の範囲を「構成入力の受け取り・Terraform のガードレール・試行履歴の記録」に絞れ、
  価値の出る所に集中できる。

どこで効くか（適用場面）:
- 「LLM がツールを回すループ」を作る系のエージェント全般。自前で API を叩いてループを書く前に、
  ヘッドレス Claude Code / Agent SDK で代替できないかを先に検討する、という判断の型。

## 確認した事実（出典つき）

- ヘッドレス: `claude -p`、`--output-format json|stream-json`、`--allowedTools "Bash(terraform *)"`、
  `--permission-mode acceptEdits`、`--bare`。どの言語からも subprocess で叩ける。
  https://code.claude.com/docs/en/headless
- Agent SDK: Python(3.10+)/TS のみ。`query()` は async generator。`ClaudeAgentOptions`（system_prompt,
  allowed_tools, permission_mode, cwd, max_turns, model, hooks）。PreToolUse/PostToolUse フックで
  ツール呼び出しを deny/allow/改変できる。`ANTHROPIC_API_KEY` 必須、`claude` CLI は wheel に同梱。
  https://code.claude.com/docs/en/agent-sdk/python.md , https://code.claude.com/docs/en/agent-sdk/overview

## 次にやること（宿題）

- v1 スコープ: dry-run（plan のみ）をデフォルト安全側にし、`--apply` で適用解禁。`terraform destroy` は別フラグ。
- ガードレール（PreToolUse フック）で apply/destroy をゲートし、危険シェルを遮断。
- 試行履歴を JSONL で記録（runtime のログ。本 journal とは別物）。
- 将来: skill 化候補＝「ヘッドレス Claude Code 上にガードレール付きエージェントを組む」型が 2 回以上出たら R-002 で検討。
