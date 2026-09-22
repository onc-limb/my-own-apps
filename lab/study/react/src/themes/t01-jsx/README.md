# テーマ A: 記述層 — JSX と React Element

> 扱う問い: **JSX で書いたものは、実行時には何になっているのか。**

## 1. JSX は構文でしかない（ランタイムではない）

JSX はブラウザも Node も理解できない。**ビルド時に必ず関数呼び出しへ変換される。**
変換には 2 方式ある。`npm run show:jsx` / `npm run show:jsx:classic` で実物を出力できる。

```jsx
// 書いたもの
<section className="card"><h3>Hello, {name}</h3></section>
```

```js
// classic runtime（React 16 までの標準）— React が名前空間として必要
React.createElement("section", { className: "card" },
  React.createElement("h3", null, "Hello, ", name))

// automatic runtime（React 17 以降の標準。いまはこちら）
import { jsx, jsxs } from "react/jsx-runtime";
jsx("section", { className: "card",
  children: jsxs("h3", { children: ["Hello, ", name] }) })
```

**automatic になって変わった実務上の点:**

- `import React from "react"` が不要になった（ビルダが `react/jsx-runtime` を自動で入れる）
- children が第 3 引数ではなく **props の一部**として渡るようになった
- 子が 1 つなら `jsx`、複数なら `jsxs` と関数が分かれる（React 側で配列かどうかを判定せずに済む＝わずかに速い）

> `/* @__PURE__ */` が付くのは、バンドラが「この呼び出しは副作用がない」と判断して
> 未使用なら削れるようにするため。Element の生成が純粋であることの裏づけでもある。

## 2. React Element は「ただのオブジェクト」

`jsx()` / `createElement()` が返すのは DOM でも仮想 DOM ノードでもなく、**不変な記述オブジェクト**。

```js
{
  $$typeof: Symbol(react.transitional.element),
  type: "section",       // 文字列 = ホスト要素 / 関数 = コンポーネント
  key: null,             // 兄弟の中での同一性（テーマ B で効いてくる）
  props: { className: "card", children: [...] },
}
```

押さえるべき 3 点:

1. **`type` が文字列か関数かで意味が変わる。**
   文字列なら実際の DOM タグになる。関数なら「後で React がこの関数を呼ぶ」という予約でしかない。
   `<Greeting />` と書いた時点で `Greeting` は **まだ実行されていない**。
   *いつ呼ぶかを React が握っている* ことが、再レンダリング制御（テーマ B / E）の前提になる。
2. **`props` は不変。** 開発モードでは `Object.freeze` される。
   受け取った側が書き換える設計にはできない。
3. **`$$typeof` は Symbol。** これは XSS 対策。`JSON.parse` で作った偽オブジェクトは
   Symbol を持てないので、サーバーから来た JSON をそのまま子要素として描画しても element とは見なされない。

## 3. 3 つの層を混同しない

| 層 | 実体 | 寿命 |
| --- | --- | --- |
| **React Element** | 上記のプレーンオブジェクト | レンダリングのたびに**毎回作り直される**（使い捨て） |
| **Fiber** | React 内部の作業単位。state・effect・DOM への参照を持つ | コンポーネントが画面にある限り**維持される** |
| **DOM ノード** | 実際のブラウザのノード | Fiber が作り、必要なときだけ更新される |

「毎回作り直される設計図（Element）」と「維持される実体（Fiber / DOM）」を
突き合わせるのが reconciliation。**テーマ B の中身はこれ。**

再レンダリングが速いのは、Element の生成が軽いオブジェクト生成にすぎず、
重い DOM 操作は差分のぶんだけに絞られるから。

## 4. コンポーネント = props → Element の純関数

```tsx
function Greeting({ name }: { name: string }) {
  return <h3>Hello, {name}</h3>;
}
```

- 引数は props **ひとつだけ**
- 返すのは Element であって DOM ではない
- **同じ props なら常に同じ結果**（レンダリング中に外部を書き換えない）

純粋であることを要求するのは行儀の問題ではない。React は
「呼ぶ / 呼ばない / 中断してやり直す / 2 回呼ぶ」を自由にやる前提で作られており、
StrictMode が開発時にわざと 2 回呼ぶのはこの違反を炙り出すため。

## 5. 合成 — `children` は特別な props にすぎない

```tsx
<Card title="…">
  <p>中身</p>
</Card>
```

タグで挟んだものは `props.children` に入るだけ。だから:

- 差し込み口は `children` に限らず、**好きな名前で何個でも作れる**（`left` / `right` など）
- 継承もミックスインも要らない。**穴の開いた箱を作って埋める**のが React の再利用手段
- この性質は後で効く: 親の再レンダリングから子を切り離す手段としても使われる（テーマ E）

## 6. よくある誤解

| 誤解 | 実際 |
| --- | --- |
| JSX は HTML | 別物。`class` ではなく `className`、値は JS 式 |
| JSX が画面を描いている | JSX は記述のみ。描くのは reconciler + react-dom |
| `<Foo />` と書くと Foo が実行される | されない。Element に関数が入るだけ |
| Element は仮想 DOM ノード | Element は使い捨ての記述。状態を持つのは Fiber |
| コンポーネントは class の代わり | 概念としては「props を受けて記述を返す関数」。継承はしない |

## 7. 手を動かして確かめる

```bash
npm run dev                # 画面で Element の中身と、JSX / createElement の一致を確認
npm run show:jsx           # 変換結果（automatic）
npm run show:jsx:classic   # 変換結果（classic）
```

確認したいこと:

- `Theme01.tsx` の JSX を書き換えると `npm run show:jsx` の出力がどう変わるか
- `handwritten.ts` を崩すと画面の「構造は同一か」が「不一致」に変わること
- `example.tsx` で `<Greeting>` の子を増やすと `jsx` が `jsxs` に変わること

## 出典

- [Writing Markup with JSX — react.dev](https://react.dev/learn/writing-markup-with-jsx)
- [Passing Props to a Component — react.dev](https://react.dev/learn/passing-props-to-a-component)
- [Keeping Components Pure — react.dev](https://react.dev/learn/keeping-components-pure)
- [`createElement` — react.dev reference](https://react.dev/reference/react/createElement)
- [Introducing the New JSX Transform (React Blog, 2020)](https://legacy.reactjs.org/blog/2020/09/22/introducing-the-new-jsx-transform.html)
- [Why Do React Elements Have a `$$typeof` Property? — Dan Abramov (2018)](https://overreacted.io/why-do-react-elements-have-typeof-property/)
