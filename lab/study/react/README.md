# react-study — 読んで学ぶ React

> lab の他の部分（`apps/`）は **人間が素の HTML / CSS / JS を手で書く** 場所。
> ここはその逆で、**完成したコードを読んで内部の動きを理解する** ための区画。
> デプロイ対象外・URL 予約表（`../../docs/architecture.md`）とも無関係。

目的は「業務で React を扱えるレベル」に最短で到達すること。
そのために、React がフロントエンドで担う役割を A〜G に分類し、
1 テーマずつ「最小の動くコード → 内部で何が起きているか → typical な誤り」の順で進める。

## 学習の地図

**方針**: 「文法・API を書けるようになる」が主線。内部の仕組みは各テーマの末尾に
「なぜそうなっているか」として必要最小限だけ添える（2026-09-22 に優先度を組み替え）。

| # | テーマ | 業務での用途 | 状態 |
| --- | --- | --- | --- |
| **1** | **state とイベント** | 全ての起点。React の書き味の 8 割 | **完了** → [t02-state](src/themes/t02-state/README.md) |
| 1-補 | useState の内部（ミニ React 実装つき） | 「なぜ動くのか」が要るときに降りる | 完了 → [internals](src/themes/t02-state/internals/README.md) |
| 2 | 条件分岐・リスト・key | 一覧画面。key の事故は実務で頻出 | 未着手 |
| 3 | フォーム（制御 / 非制御） | 入力画面 | 未着手 |
| 4 | 副作用とデータ取得 | API 連携。事故が最も多い | 未着手 |
| 5 | 状態の設計（lifting / Context / カスタムフック） | 画面が育った時の構造 | 未着手 |
| 6 | 再レンダリングと最適化 | 遅くなった時の対処 | 未着手 |
| 7 | TypeScript での型付け | 業務では必須。横断テーマ | 未着手 |
| 8 | 境界（ルーティング / データ取得 / スタイル）と技術選定 | Next.js が何をやっているか | 未着手 |

### 参考（優先度は低い）

| テーマ | 内容 | 状態 |
| --- | --- | --- |
| 記述層 | JSX → React Element、コンポーネント＝純関数、合成 | 完了 → [t01-jsx](src/themes/t01-jsx/README.md) |

変換の詳細そのものは業務では使わないが、次の 2 点は後のテーマで必ず戻ってくる地点なので残してある。

- `<Foo />` と書いても関数はまだ実行されない（呼ぶタイミングを React が握っている）
- Element は毎回捨てられ、Fiber は維持される（だから state が残る）

### 技術選定との関係

React / Preact / Solid の差は「JSX の変換結果」ではなく **更新モデル** に出る。

| | 更新モデル | コンポーネント関数が走る回数 | 選定理由になるのは |
| --- | --- | --- | --- |
| React | Element を作り直して差分を取る（VDOM 調停） | 更新のたびに毎回 | エコシステム・人材・RSC |
| Preact | 同じ VDOM モデル。ランタイムが小さい | 更新のたびに毎回 | バンドルサイズ。パラダイムは同じ |
| Solid | JSX が DOM 生成 + 細粒度購読にコンパイルされる | 初回の 1 回だけ | 更新性能。`memo` 系が不要になる |

Solid ではコンポーネントが 1 回しか走らないため、React の再レンダリング制御（テーマ 6）の話題が
丸ごと消える。この比較の実地検証は lab 本体の Phase 1（vanilla / react / signals の 3 実装比較）の領分。

## 自分の理解メモ

- [`docs/my-understanding.md`](docs/my-understanding.md) — 自分の言葉で立てた仮説と、その検証結果の記録。
  教科書ではなく「どこをどう誤解していたか」が残る側の文書。
- [`docs/hooks-order-tradeoff.md`](docs/hooks-order-tradeoff.md) — hook の順序規約はなぜあるのか。
  Preact / Solid / Vue / Svelte との比較（テーマ 8「技術選定」の素材）。

## 使い方

```bash
npm run dev            # 画面を開く（テーマの実物）
npm run show:jsx       # JSX が何に変換されるかを見る（automatic runtime = 現代）
npm run show:jsx:classic  # 同じものの classic runtime 版（React.createElement）
npm run typecheck
npm run build
```

## 構成

```
src/
├── main.tsx              # createRoot + StrictMode によるマウント（唯一の命令的な手続き）
├── style.css
├── App.tsx               # テーマ切り替え（それ自体がテーマ 1 の実例）
└── themes/
    ├── t02-state/        # テーマ 1: state とイベント
    │   ├── README.md     # ← 解説
    │   ├── Theme02.tsx   # 画面に出るコード
    │   └── internals/    # 1-補: useState の内部
    │       ├── README.md
    │       ├── miniReact.ts  # useState の最小再現実装（60 行）
    │       └── Internals.tsx
    └── t01-jsx/          # 参考: 記述層
        ├── README.md
        ├── Theme01.tsx
        ├── handwritten.ts# createElement で手書きした等価物
        ├── inspect.ts    # React Element を覗く道具
        └── example.tsx   # 変換結果を見るためだけのファイル
```
