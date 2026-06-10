# 2026-06-10 daedalus v2 — 実行モード・GitHub 連携・GUI の指示

## ユーザーからの実装指示（R-001: 実装の指示の記録）

1. **2つの実行モードを実装する**
   - **自動運転モード（auto）**: 完全に一から作る場合や、サンドボックスアカウントで使う場合に、
     人の承認なしで apply まで完全自動で回すモード。
   - **承認モード（approval）**: 実際のインフラに反映させる前に、人の承認を必要とするモード。
   - （既存の plan-only dry-run は安全側デフォルトとして残す）

2. **ソースコード管理はプロジェクトごとに GitHub で管理**
   - daedalus（アプリ）からは **API 経由**でコードを取得（pull）したりプッシュしたりできるようにする。
   - → spec ごとに `github: { repo, branch }` を持たせ、GitHub REST API（Git Data API）で
     tarball 取得・blob/tree/commit 作成を行う設計にした。git バイナリ非依存・トークンはメモリ内のみ。

3. **アカウント ID などは環境変数で扱う**
   - `GITHUB_TOKEN` / `GITHUB_OWNER` / `ANTHROPIC_API_KEY`、クラウド認証は環境の認証チェーン。
   - spec 内では `${VAR}` 形式の環境変数展開をサポート（ID をファイルにハードコードしない）。

4. **操作・レビュー用の GUI を作る**
   - Run の開始・ライブログ閲覧・**承認（apply の approve/reject）**・履歴・GitHub pull/push 操作。

## 設計判断と理由

- **GUI スタック = FastAPI + 素の HTML/JS（ビルド不要）**: エージェントと同じ Python に揃え、
  依存とビルド工程を最小化。操作パネルの規模なら React 等は過剰。
- **承認の実装 = PreToolUse フックで apply/destroy を待機**: ガードレールの deny と同じ場所で
  「approve（人に聞く）」という第3の判定を返し、CLI ならターミナル y/N、GUI なら承認カードで解決する。
  ループ自体は引き続き Claude Code 任せ（v1 の設計原則を維持）。
- **GitHub push は base_tree 方式**: 追加・更新のみでファイル削除はしない（安全側）。v1 の制限として明記。

## 宿題

- 実機検証（sandbox アカウントで auto モード、本番想定で approval モード）
- 複数 Run の並行実行（v2 は同時 1 Run のみ）
- plan のコスト評価ゲート
