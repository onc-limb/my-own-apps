---
name: llm-bridge
description: >-
  my-own-apps の各アプリに「任意（オプション）の LLM 機能」を足すときの定番セットアップを再現する。ユーザーが「AI 機能をつけたい」「LLM 連携を入れたい」「Claude / ChatGPT で〜できるように」「サブスクリプション（claude -p）で使えるように」「API キーをどこに置くか」と言ったり、クライアントサイドのアプリから LLM を呼びたい場面でこの skill を使う。ブラウザに API キーを持たせず、ローカルの薄い中継サーバ（ブリッジ）経由で claude -p（サブスク）と LiteLLM 互換 API（API キー）の2形態を切り替える構成を、Backend-for-Frontend / OpenAI 互換インターフェースの考え方に基づいて組む。telos の server/ がこのパターンの実装例。
---

# LLM Bridge — クライアントアプリに任意の LLM 機能を足す

クライアントサイド完結のアプリ（Vite + TS など）に LLM 機能を**後付けの任意機能**として足すときの定番構成。telos の `server/` で実証済みのパターンを再利用可能にしたもの。

## 基本姿勢（なぜブリッジを挟むのか）

**鉄則: API キーをブラウザに置かない。** フロントエンドのコードや環境変数（`VITE_*` / `REACT_APP_*`）に入れたキーは、ビルド時に JS 文字列へ埋め込まれ、Network タブやバンドルから誰でも読める。OWASP も localStorage / JS 変数への秘密情報保存を主要リスクに挙げ、対策として **Backend-for-Frontend（BFF）プロキシ**で秘密をサーバ側に隔離することを推奨している。

だから、フロントは「dumb client」のままにし、秘密が要る処理だけを薄い中継サーバ（ブリッジ）に委ねる。

加えて my-own-apps では2つ目の鉄則がある：**サブスクリプションを一級市民として扱う。** トークン課金の API キーがなくても、ローカルの `claude -p`（Claude Code の print モード）をサブプロセスで呼べば、既存の Claude 契約でそのまま動く。ブリッジはこの `claude-cli` 形式と、`litellm`（OpenAI 互換 API）形式を環境変数で切り替えられるようにする。

## 適用判断

- ✅ クライアントサイド完結のアプリに LLM 支援を**任意機能**として足したい
- ✅ ユーザーが API キー課金とサブスク利用の両方を選べるようにしたい
- ❌ すでにバックエンドがあるアプリ（そこに同じ2形態の `/api/complete` を生やせばよく、別サーバは不要）
- ❌ LLM が機能の前提（任意ではなく必須）の場合（フォールバック設計が変わる。下記「フォールバック原則」を読み替える）

## 構成（4ステップ）

### 1. ワークスペース化（まだなら）

フロント単体ディレクトリなら、pnpm workspace にして `app/` と `server/` を併置する。ルートに `pnpm-workspace.yaml`（`packages: [app, server]`）と、`dev` / `build` / `bridge` スクリプトを持つ `package.json` を置く。

### 2. ブリッジサーバ（`server/`）

Node 標準 `http` だけで書く（依存を増やさない）。実行は `node --experimental-strip-types src/index.ts`（Node 22+）。エンドポイントは2つだけ：

- `GET /api/health` → `{ ok, provider, model }`（接続テスト用）
- `POST /api/complete` ← `{ prompt, system? }` → `{ text }`

provider を環境変数 `TELOS_PROVIDER` で分岐：

- **`claude-cli`（既定）**: `spawn("claude", ["-p", "--output-format", "text", ...])` し、prompt を stdin に書く。`system` は `--append-system-prompt` で渡す。サブスク利用・キー不要。
- **`litellm`**: OpenAI 互換の `${BASE_URL}/chat/completions` に `{ model, messages }` を POST。`Authorization: Bearer <key>` を付ける。LiteLLM proxy / Anthropic / OpenAI など 100+ プロバイダを同一形式で叩ける。

必ず入れる: CORS ヘッダ（ローカル開発用に `Access-Control-Allow-Origin: *`）、OPTIONS への 204、タイムアウト（`AbortController` / `child.kill`）、エラーは `{ error }` で返す。`.env.example` に両形態の設定例を書く。`.env` は gitignore。

実装の雛形は telos の `server/src/index.ts` をそのまま参照・コピーしてよい。

### 3. フロント側クライアント（`app/src/llm.ts` + `settings.ts`）

- `settings.ts`: `{ llmEnabled: boolean, bridgeUrl: string }` を localStorage に持つ。既定 `http://localhost:8787`。
- `llm.ts`: `llmEnabled()` / `checkHealth(url)` / `complete(prompt, system?)` / `extractJson<T>(text)`。
  - `extractJson` は LLM 出力からコードフェンスや前置きを除いて最初の JSON を寛容に取り出すヘルパ。構造化出力を使う機能で必須。
- Settings 画面に「LLM 連携 ON/OFF」「Bridge URL」「接続テスト（health を叩いて provider/model を表示）」を置く。

### 4. 機能への接続（フォールバック原則）

**LLM は上乗せであって前提にしない。** 各機能はまずヒューリスティック（マーカー検出・テンプレート・正規表現）だけで完結させ、`llmEnabled()` が真のときだけ「✨ AIで〜」ボタンを活性化する。AI 呼び出しは必ず try/catch し、失敗してもヒューリスティック結果が残るようにする。これで、ブリッジ未起動・契約なしでもアプリは壊れない。

## 構造化出力のコツ

- JSON が欲しいときは system で役割を与え、prompt で「出力は次のキーの JSON のみ」と明示し、`extractJson` で受ける。
- 「推測で埋めるな・メモにない数値を作るな」を prompt に入れて hallucination を抑える。
- 1機能=1プロンプトに保ち、会話状態をサーバに持たせない（ブリッジはステートレス）。

## チェックリスト

- [ ] API キーがフロントのコード・バンドル・localStorage に一切入っていない
- [ ] `claude-cli` と `litellm` の両方が `/api/complete` で動く
- [ ] LLM OFF / ブリッジ未起動でも全機能がヒューリスティックで動く
- [ ] health で接続テストできる
- [ ] `.env` は gitignore、`.env.example` に両形態の例がある
- [ ] AI 呼び出しが try/catch され、失敗が画面に出る（黙って壊れない）

## 出典

- OWASP Top 10 Client-Side Security Risks / 秘密情報をクライアントに置かない原則。<https://owasp.org/www-project-top-10-client-side-security-risks/>
- Backend-for-Frontend (BFF) パターンで API キーをサーバ側に隔離する。GitGuardian, "Stop Leaking API Keys: The BFF Pattern Explained" (2026). <https://blog.gitguardian.com/stop-leaking-api-keys-the-backend-for-frontend-bff-pattern-explained/>
- LiteLLM — 100+ LLM を OpenAI 互換形式（`/chat/completions`）で叩く統一インターフェース。<https://github.com/BerriAI/litellm/> / <https://docs.litellm.ai/docs/providers/openai_compatible>
- 実装例: telos `server/`（このリポジトリ）。
