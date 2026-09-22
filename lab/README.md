# lab

> 自分の技術書棚を、**それを観測する計測基盤ごと自作する**サイト。
> 目的はプロダクトではなく **言語と技術の学習**。既存サービスの劣化コピーで構わない。

公開先は **`lab.onc-limb.com`**。名前のとおり実験室で、
その中に個々の実験（Lab）が増えていく。

## なぜ作るのか

TypeScript（フロントエンド / バックエンド）・Node.js・Python・Rust を、
**手を動かして学ぶ**ための公開ウェブアプリ。学習の優先度は次の通り。

1. **TS フロントエンド**（メイン）
2. **Node.js**（メイン）
3. Python（拡張）
4. Rust（拡張）

題材のオリジナリティは評価軸にしない。代わりに
**「学びたい技術が自然に必要になるか」** を題材の選定基準にしている。

## コアコンセプト

> **同じ機能を複数の言語・実装方式で並べ、切り替えて違いを体感できるサイト**

ページごとにバニラ JS か React かを選び、API は TS Worker 版と Node 版と Rust 版を並べ、
計算エンジンは JS 版と WASM 版を並べる。1 つの機能を実装するたびに
**実装 + 対照実験** が手に入る。

この設計には学習科学の裏付けがある（→ [docs/concept.md](docs/concept.md)）。

## 二層構造

```
技術書コレクション（アプリ層）───── 外部書誌 API に依存
        │                                │
        │ 各画面が計測される                │ その API が監視対象になる
        ↓                                ↓
     観測基盤（土台）──────────── 自サイトも監視対象
     ・自作アクセス解析
     ・外部サービス監視 / ステータスページ
```

**観測基盤が比較実験の測定装置そのものになる。**
`?impl=ts|node|rs` や `?engine=js|wasm` の応答時間を自作アナリティクスが記録し、
ダッシュボードで比較できる。ドッグフーディングの輪が閉じる。

## 進め方

- 機能は**少しずつ追加する**。最初にすべてを決めない。
- 決めるのは「何を扱うドメインか」だけ。機能は **学びたい技術から逆算して後付けする**。
  そのための受け皿が [docs/features.md](docs/features.md) の拡張マトリクス。
- **実装は完全に人の手で行う。** AI は題材・設計の壁打ちとドキュメントのみ担当する
  （→ [CLAUDE.md](CLAUDE.md)）。

## ドキュメント

| ファイル | 内容 |
| --- | --- |
| [CLAUDE.md](CLAUDE.md) | このディレクトリでの AI の役割と禁止事項 |
| [docs/concept.md](docs/concept.md) | コアコンセプトと学習科学のエビデンス（出典付き） |
| [docs/architecture.md](docs/architecture.md) | インフラ構成、Cloudflare の制約、**後から変えにくい判断** |
| [docs/features.md](docs/features.md) | 拡張マトリクス（学びたい技術 → 足す機能） |
| [docs/learnings.md](docs/learnings.md) | 実装中に気づいたこと・学びのメモ（日付ごと） |
| [roadmap/README.md](roadmap/README.md) | フェーズ概要と各フェーズの学習目標 |
| [roadmap/phase0-top-page.md](roadmap/phase0-top-page.md) | **いま取り組むもの**: トップページ 1 枚とデプロイ |
| [roadmap/phase0-learning-plan.md](roadmap/phase0-learning-plan.md) | Phase 0 の**学習テーマ 8 つ**（ゴールと到達判定つき）と、その下の細目 |

## 現在地

**Phase 0: トップページ 1 枚を素の HTML / CSS / JS で作り、`lab.onc-limb.com` で公開する。**
