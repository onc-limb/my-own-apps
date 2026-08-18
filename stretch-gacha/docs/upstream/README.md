# docs/upstream — veronica 成果物のスナップショット

このディレクトリは、veronica（iron-legion の上流工程パイプライン）で確定させた
仕様ドキュメントの**写し（スナップショット）**です。

- **正本**: iron-legion リポジトリの `veronica-docs/stretch-gacha/`（git 管理外・ローカル）
- **取得日**: 2026-08-18（L1 → L2 → L3 を完走した時点）
- 更新の流れ: 仕様変更は veronica 側（L1 reopen / L2 差し戻し）で行い、
  確定後にここへ写しを取り直す。このディレクトリを直接編集しない。

## 内容

| パス | 内容 |
|---|---|
| `product-definition.md` | L1 プロダクト定義（目的・スコープ・非機能優先順位・機能一覧） |
| `features/<id>-spec.md` | L2 機能仕様（MVP 7 機能。L3 レビュー承認済み） |
| `issues/<id>.md` | L3 が整形した実装 issue（受け入れ条件つき） |

MVP 7 機能: stretch-catalog / gacha-draw / stretch-card / stretch-timer /
practice-record / stretch-collection / safety-notice
（後回し: collection-progress / appstore-release-prep）
