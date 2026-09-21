# ロードマップ

学習の優先度（TS フロント → Node → Python / Rust）に合わせてフェーズを並べている。
**各フェーズには「まだ使わないもの」が定義されている。** 便利だからという理由で先取りしない
（理由は [../docs/concept.md](../docs/concept.md) の「A Time for Telling」）。

## フェーズ一覧

| Phase | 作るもの | 学習の主目的 | 状態 |
| --- | --- | --- | --- |
| **0** | トップページ 1 枚 + `lab.onc-limb.com` へのデプロイ | セマンティック HTML、CSS、素の JS による DOM 操作と状態管理 | **進行中** |
| 1 | 技術書コレクション（`/books-vanilla` → `/books`）、D1、`/api/ts` | 状態管理の 3 実装比較、フォーム、外部 API、RDB | 未着手 |
| 2 | 自作アクセス解析（`/collect` + Queues + 集計 → `/dash`） | キュー、時系列スキーマ設計、集計、チャート | 未着手 |
| 3 | Container で Node API を立て、Worker 版と比較 | Node.js の本領、Dockerfile、コールドスタート | 未着手 |
| 4 | 外部監視（`/status`）+ WebSocket ライブ更新 | 並行処理、レート制限、リトライ、WebSocket を 2 通り | 未着手 |
| 5 | Rust（書影処理 WASM / `/api/rs` / 全文検索） | Rust をブラウザとサーバの両面で | 未着手 |
| 6 | Python（分析 Container、異常検知、Parquet） | Python + データ分析 | 未着手 |

Phase 0〜2 は Workers のみで完結する。Containers の課金が始まるのは Phase 3 から。

## MVP の定義

このリポジトリでいう MVP は「人に使わせられる状態」ではなく
**「比較実験が回り始めた状態」**。具体的には **Phase 2 の完了**。

- 技術書コレクションが 1 機能ぶん、素の JS 版と React 版の両方で存在する
- 自作アクセス解析がその 2 つの実装の差を数字で見せている

ここまで到達すると、以降の機能追加はすべて「既にある器に足す」作業になる。

## 各フェーズ共通の完了条件

- `lab.onc-limb.com` で公開され、実際に見られる
- そのフェーズで「まだ使わない」としたものを使っていない
- 学んだことと詰まったことがリポジトリルートの `journal/` に残っている
- コミットが Conventional Commits で、機能変更とリファクタリングが分かれている

## 詳細

- [phase0-top-page.md](phase0-top-page.md) — **いま取り組むもの**。スコープ、不可逆の判断、作業順序、完了基準
- [phase0-learning-plan.md](phase0-learning-plan.md) — Phase 0 の学習項目と、それを担うページ要素の対応表
