# telos LLM bridge

telos の **任意（オプション）** の LLM 機能を有効にするローカル中継サーバ。
ブラウザに API キーを持たせず、サーバ側で利用形態を切り替える。

## 何ができるか

- **Goals**: 会話ログからの要望抽出と「なぜ」の問いを AI が支援
- **Brief**: 箇条書きメモからビジネス説明資料の下書きを生成
- **Slides**: 箇条書きから報告サマリーを整形

LLM を使わなくても、これらはヒューリスティックで動作する（AI はあくまで上乗せ）。

## 2つの利用形態

| 形態 | `TELOS_PROVIDER` | 認証 | 用途 |
|------|------------------|------|------|
| サブスクリプション | `claude-cli`（既定） | ローカルの `claude -p` | Claude Pro/Max/Team 契約をそのまま使う。API キー不要 |
| API | `litellm` | API キー | LiteLLM proxy / Anthropic / OpenAI などトークン課金 |

## 起動

```bash
# ワークスペース直下で
pnpm install
cp server/.env.example server/.env   # 必要なら編集
pnpm bridge                          # http://localhost:8787 で待ち受け
```

その後、app の Settings 画面で「LLM 連携」を ON にし、Bridge URL
（既定 `http://localhost:8787`）を指定して「接続テスト」する。

## エンドポイント

- `GET /api/health` → `{ ok, provider, model }`
- `POST /api/complete` ← `{ prompt, system? }` → `{ text }`
