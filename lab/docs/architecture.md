# アーキテクチャ

> 機能は少しずつ足す。しかし **デプロイの形だけは後から変えにくい**。
> このドキュメントは、先に決めておくべきことだけを扱う。

## 二層構造

```
技術書コレクション（アプリ層）───── 外部書誌 API に依存
        │                                │
        │ 各画面が計測される                │ その API が監視対象になる
        ↓                                ↓
     観測基盤（土台）──────────── 自サイトも監視対象
```

依存は一方向に閉じている。アプリ層を足しても土台は変わらない。

### 観測基盤で 2 機能を 1 本のパイプラインにする

自作アクセス解析と外部サービス監視は、別機能として作らない。
どちらも本質は「時系列イベントを集めて・集計して・見せる」なので、
**1 つのスキーマに正規化できる**。

```
event(timestamp, source, kind, target, value, attrs)
         ↑
   source = 'web'   → 自サイトのアクセス（アクセス解析）
   source = 'probe' → 外部監視の結果（ステータスページ）
```

違いは `source` だけ。収集 → キュー → 集計 → 表示のパイプラインを 1 本作れば、
`/dash`（解析）と `/status`（監視）は**同じデータの見せ方の違い**になる。

## 後から変えにくい判断（Phase 0 で確定させる）

| # | 判断 | 採用 | なぜ後から変えにくいか |
| --- | --- | --- | --- |
| 1 | ホスティング | **Workers + Static Assets** | Pages から移すと設定と CI をやり直す。新規開発は Workers に寄っている |
| 2 | ドメイン | **`lab.onc-limb.com` を最初から繋ぐ** | `*.workers.dev` で運用を始めると、後で Worker を分割・改名したとき URL が変わる |
| 3 | URL 名前空間 | **下の予約表で確定** | 後から変えると外部リンク・ブックマーク・計測データの継続性が壊れる |
| 4 | リポジトリ構成 | **モノレポ**（`apps/` + `services/` + `packages/`） | 移動自体は `git mv` で済むが、CI とデプロイ設定を巻き込む |
| 5 | Worker の形 | **assets-only Worker で始め、必要になったら `main` を足す** | この順序なら URL が変わらずに Worker コードを追加できる |

**#2 がとくに重要。** `lab.onc-limb.com` をルートで受けてしまえば、
内部の Worker 構成（1 個 → 複数個、Container 追加）を後から自由に組み替えても
公開 URL は一切変わらない。逆にここを後回しにすると、
サイトが育ったあとで全部の URL を引っ越すことになる。

## URL 名前空間の予約表

Phase 0 で使うのは `/` と `/assets/*` だけだが、**全部を先に予約しておく**。

| パス | 用途 | 登場フェーズ |
| --- | --- | --- |
| `/` | トップ（Lab インデックス） | Phase 0 |
| `/assets/*` | CSS / JS / 画像 | Phase 0 |
| `/books` | 技術書コレクション（React 版） | Phase 1 |
| `/books-vanilla` | 同じ画面の素の JS 版 | Phase 1 |
| `/labs/<name>-<impl>` | 個別 Lab。`<impl>` は `vanilla` / `react` / `signals` | Phase 1 以降 |
| `/dash` | 観測ダッシュボード | Phase 2 |
| `/status` | ステータスページ | Phase 4 |
| `/collect` | 計測イベント収集エンドポイント | Phase 2 |
| `/api/ts/*` | Worker 上の TS API | Phase 1 |
| `/api/node/*` | Container 上の Node API | Phase 3 |
| `/api/rs/*` | Container 上の Rust API | Phase 5 |
| `/api/py/*` | Container 上の Python API | Phase 6 |
| `/ws/*` | WebSocket | Phase 4 |

**実装方式はクエリではなくパスで分ける**（`/books-vanilla`）。
静的な HTML をそのまま配れるので、ビルドもキャッシュも素直になる。
一方 API の実装切り替えはパス（`/api/<impl>/`）、
同一ページ内のエンジン切り替えはクエリ（`?engine=js|wasm`）にする。

## ディレクトリ構成

```
lab/
├── README.md
├── CLAUDE.md
├── docs/
├── roadmap/
├── apps/
│   └── web/
│       └── public/          # Phase 0: 素の HTML / CSS / JS を直置き（ビルドなし）
├── services/                # Phase 1 以降: Worker と Container
└── packages/                # Phase 1 以降: 共有スキーマ・型
```

Phase 0 で `apps/` の階層を切っておくのは、後で `web/` を移動しないため。
コストはゼロで、`git mv` と CI 修正を 1 回省ける。

> **命名について**: ディレクトリ名 `lab`（サイト全体 = 実験室）と、
> URL の `/labs/<name>`（個々の実験ページ）は別のものを指す。
> 前者は単数で「場」、後者は複数で「そこに並ぶ実験」。

## 将来の全体構成（Phase 6 時点の姿）

```
lab.onc-limb.com/*  →  gateway Worker（Hono + Static Assets）
│
├─ フロント（Vite MPA / ページ単位で技術を選択）
│   /  /books  /books-vanilla  /labs/*  /dash  /status
│
├─ Workers（エッジ・常時起動・即応）
│   /collect        収集エンドポイント（超軽量 → Queues へ produce）
│   /api/ts/*       Hono + Drizzle + D1
│   /ws/*           Durable Object（ライブ表示）
│
├─ Containers（Durable Object 経由で起きて寝る）
│   /api/node/*     本物の Node（ws / worker_threads / streams）
│   /api/rs/*       Rust ネイティブ（axum）
│   /api/py/*       Python + pandas / DuckDB
│
└─ データ
    D1                蔵書・タグ・読了、監視対象、集計済みメトリクス
    Durable Objects   ライブ接続、監視スケジューラ、Container ハンドル
    Queues            収集イベント、書誌取り込み、監視プローブ
    R2                生イベント NDJSON / Parquet、書影
    KV                集計キャッシュ、Lab の feature flag
    Analytics Engine  比較実験の実測値
```

## Cloudflare 側の制約（設計に効くもの）

### Containers は常駐サーバではない

Container は Durable Object のライフサイクルで**起きて寝るプロセス**。
`sleepAfter` で idle 停止し、ディスクはエフェメラル、イメージは `linux/amd64` が必須。

→ **インメモリ状態は失われる前提で設計する**（状態は D1 / Durable Objects / R2 へ外部化）。
これ自体が学習テーマになる（コールドスタート、Worker と Container の役割分担）。

### コスト設計

Workers Paid に含まれるのは月あたり メモリ **25 GiB-hours** / vCPU **375 分** /
ディスク 200 GB-hours。メモリとディスクは**プロビジョニング量**で課金される（CPU は実使用分のみ）。

| 使い方 | 無料枠内か | コスト |
| --- | --- | --- |
| `lite`（1/16 vCPU, 256 MiB）を約 100 時間/月 | ○ | $0 |
| `lite` を 24 時間常駐 | ✗ | 月 $2 弱 |
| `basic`（1/4 vCPU, 1 GiB）を 24 時間常駐 | ✗ | 月 $7 前後 |
| `standard-1` を Cron で 1 日 5 分 | ○ | $0 |

方針: **常駐させたいものは `lite` + 短い `sleepAfter`、重い集計は Cron で `standard-1` を数分だけ起動。**

### WebSocket は Container にもプロキシできる

Worker から Container への WebSocket は `fetch()` で通る（`containerFetch()` では通らない）。
→ **同じリアルタイム機能を Durable Object 版と Container の `ws` 自作版の 2 実装で比較できる。**

## 出典

- [Cloudflare Containers — Overview](https://developers.cloudflare.com/containers/)
- [Containers — Limits（インスタンスタイプ）](https://developers.cloudflare.com/containers/platform/limits/)
- [Containers — Pricing](https://developers.cloudflare.com/containers/platform/pricing/)
- [Containers — Websocket to Container](https://developers.cloudflare.com/containers/examples/websocket/)
- [Containers — Container Interface（`fetch` と `containerFetch` の違い）](https://developers.cloudflare.com/containers/container-class)
