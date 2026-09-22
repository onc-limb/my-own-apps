# テーマ 1-補: useState の内部

> 扱う問い: **なぜ変数を直接書き換えても反映されないのに、`setCount` だと `count` の値が変わるのか。
> `count` のスコープはどうなっているのか。ポインタで参照先を書き換えているのか。**

先に結論:

1. **`count` は変わっていない。** コンポーネント関数が**もう一度呼ばれ**、新しい `count` が作られている
2. 値の実体はコンポーネント関数の**外**（Fiber 上の hook）にあり、`useState` はそこから読んでいるだけ
3. ポインタでもグローバル変数でもない。**React は変数を監視していない**。動く引き金は `setState` の呼び出しだけ

## 1. `count` のスコープ

```tsx
function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(count + 1)}>{count}</button>;
}
```

`count` は **`const`**。1 回の関数呼び出しの中のローカル定数で、再代入は言語仕様として不可能。
`setCount` がこの定数を書き換えることは原理的にできない。

起きているのはこう:

```
1 回目の呼び出し ─ スコープ①: const count = 0   ← この onClick は 0 を閉じ込めた
2 回目の呼び出し ─ スコープ②: const count = 1   ← 別の関数オブジェクト。1 を閉じ込めている
3 回目の呼び出し ─ スコープ③: const count = 2
```

レンダーごとにスコープが丸ごと作り直される。画面に出ているのは常に**最新のスコープの `count`**。
だから「値が変わった」ように見える。

この性質は `Internals.tsx` の **デモ B** で体感できる。3 秒後に `count` を表示するハンドラは、
押した時点のスコープの値しか見えない（その間に何回更新しても変わらない）。

## 2. 値の実体はどこにあるか

コンポーネントの実体である **Fiber** が、hook の連結リストを持っている。

```
Fiber（画面にある限り維持される）
 └ memoizedState → hook0 { state: 2 } → hook1 { state: "..." } → ...
                     ↑
        useState はここから読み、setState はここを書き換える
```

`useState` の仕事は 2 つだけ:

1. 「いまレンダリング中の Fiber」の「何番目の hook か」を見て、**保存された値を返す**
2. その hook に紐づく `setState` を返す

**どの `useState` がどの hook かは、変数名ではなく呼び出し順（カーソル）で決まる。**
`miniReact.ts` の `inst.cursor` がそれ。レンダーのたびに 0 に戻り、`useMiniState` が呼ばれるたびに +1 する。

→ これが **hooks のルール**（トップレベルで、常に同じ順序で呼ぶ）の理由。
条件分岐の中に入れると順序がずれ、別の hook の値を掴む。

## 2-2. 「初回か 2 回目以降か」はどこで判定されているか

**回数は数えていない。** React はコンポーネント関数を呼ぶ直前に、
`useState` の**実装そのものを差し替えている**。

```js
// 本物の useState。中身を持っていない
function useState(initialState) {
  const dispatcher = resolveDispatcher();   // ← いま有効な実装を取ってくるだけ
  return dispatcher.useState(initialState);
}
```

`resolveDispatcher()` が返すのは `ReactCurrentDispatcher.current`。
React はレンダリング開始時にここへ関数テーブルを入れる。

| 状況 | 入る dispatcher | `useState` の実体 | 初期値 |
| --- | --- | --- | --- |
| 初回レンダリング | `HooksDispatcherOnMount` | `mountState` — hook を**作る** | **使う** |
| 2 回目以降 | `HooksDispatcherOnUpdate` | `updateState` — hook を**読む** | 受け取るが**捨てる** |
| レンダリング外 | `ContextOnlyDispatcher` / null | 例外を投げる | — |

どちらを入れるかの判定は 1 行で、**その Fiber が一度でもコミットされているか**
（`current !== null && current.memoizedState !== null`）。
ミニ実装では `inst.mounted` がこれに当たる。

つまり「2 回目以降は初期値が無視される」の正体は、
**`updateState` が引数を受け取るだけで一度も参照しない**、それだけ。

### なぜフラグ分岐ではなく実装ごと差し替えるのか

1. `useState` の中で毎回 `if (mount)` を判定しなくて済む
2. **レンダリング外で hook を呼んだことを検出できる**。レンダー終了時に dispatcher を戻すので、
   外で呼ぶと `Invalid hook call. Hooks can only be called inside of the body of a function component.` になる
3. 用途別の実装（開発用の警告つき、SSR 用、Server Components 用）を丸ごと差し込める

### その結果、hook の同定は「呼び出し順」だけになる

`mountState` / `updateState` はどちらもカーソルを 1 進めるだけで、変数名は見ていない。
そのため **順序が崩れると壊れる**。しかも壊れ方が 2 通りある。

| 崩れ方 | React の反応 |
| --- | --- |
| 前回より hook が**増えた** | `Rendered more hooks than during the previous render.` |
| 前回より hook が**減った** | `Rendered fewer hooks than expected.` |
| 個数は同じで**順序だけ入れ替わった** | **エラーにならない。静かに別の値を掴む** |

3 つ目が一番危険。分岐の両側で `useState` を呼ぶと個数が変わらないので検出できない。

```tsx
const [flag, setFlag] = useState(true);   // hook[0]
if (flag) {
  const [a] = useState("A 用の値");        // hook[1]
} else {
  const [b] = useState("B 用の値");        // hook[1] ← 同じ枠を共有する
}
```

デモ E の実行結果:

```
1 回目 flag=true : branch="A 用の値"
2 回目 flag=false: branch="A 用の値"   ← else 側なのに A の値。例外は出ない
```

これが「hook はトップレベルで、常に同じ順序で呼ぶ」が**強い規約**である理由。
実務では `eslint-plugin-react-hooks` を必ず入れて静的に落とす。

## 3. なぜ直接書き換えても反映されないのか

**React は変数を監視していないから。** Proxy も getter/setter も使っていない。

| 方式 | 変更の検知 | 代表 |
| --- | --- | --- |
| 明示的な通知 | **更新関数が呼ばれたときだけ** | React |
| 自動追跡（リアクティブ） | 読み書きを Proxy / signal で捕捉 | Vue, Solid, Svelte 5 |

React は「いつ再計算するか」を開発者からの通知に委ねている。通知がなければ、
値が変わっていようと React は何も知らない。

実際、**オブジェクトの state は参照が共有されている**（デモ C）。
`profile.age += 1` は本当に state に届いている。届いているのに画面が変わらない。
つまり「コピーを渡されたから反映されない」のではなく、**通知がないから反映されない**。

> だから `setItems(items)` のように同じ参照を渡すのも効かない。
> React は `Object.is` で前後を比較し、同じなら再レンダリングを省略する（bailout）。
> **必ず新しいオブジェクト / 配列を作る。**

## 4. `setCount` が実際にやること

```
setCount(1)
  ① 更新を hook の更新キューに積む（この時点では値は確定していない）
  ② このコンポーネントに「再レンダリングが必要」の印を付ける
  ③ イベントハンドラが最後まで走り終わる
  ④ React がキューを畳み込んで値を確定させる（バッチング）
     ※ 本物は再レンダリング中に `useState` が呼ばれた時点で畳み込む。
       ミニ実装は分かりやすさのためレンダー前にまとめて処理している
  ⑤ コンポーネント関数をもう一度呼ぶ → 新しいスコープの count ができる
  ⑥ 返された Element を前回と比較し、変わった DOM だけ書き換える
```

`setCount` は **代入ではなく「再レンダリングの予約」**。①〜③があるので、
呼んだ直後に `count` を読んでも古い値のまま。

### 「useState(0) が useState(1) に書き換わる」わけではない

挙動の予想としては近いが、機構としては違う。**初期値は書き換わらず、2 回目以降は単に無視される**。
この違いは次の 3 か所で表に出る。

| 場面 | 「初期値が書き換わる」モデルだと | 実際 |
| --- | --- | --- |
| `useState(() => heavy())` | 書き換え後も関数が渡っている | 初回以降 **関数は一度も呼ばれない** |
| 同じ値を渡す | 書き換えて再実行 | `Object.is` で同値なら **再レンダリングを省略** |
| 同じイベントで複数回更新 | 最後の値で上書き | **キューを順に畳み込む** |

### キューは「最後の値が勝つ」わけではない

積まれるのは値そのものではなく **更新の列**。畳み込みのルールは 2 種類。

| 積んだもの | 畳み込み方 |
| --- | --- |
| 値（`setCount(1)`） | それまでの結果を**上書き** |
| 関数（`setCount(c => c + 1)`） | それまでの結果に**適用** |

```
setCount(count + 1) を 3 回   → [値1, 値1, 値1]        → 1      （結果的に最後が勝つ）
setCount(c => c + 1) を 3 回  → [関数, 関数, 関数]      → 3      （全部適用される）
setCount(10); setCount(c=>c+1) → [値10, 関数]          → 11     （混ざっても順に適用）
```

値だけを積んだときは「最後が勝つ」ように見えるが、それは上書きが繰り返された結果にすぎない。
**関数を積めば 3 件すべてが適用される。** デモ A の ① / ② を分けて押すと、
キューの中身と畳み込みの過程がそのまま見える。

### なぜ setCount は「どこを更新するか」を知っているのか

`useState` が値を返す前に、React はモジュールスコープの変数
（本物では `currentlyRenderingFiber`、ここでは `currentInstance`）に
「いまレンダリング中のコンポーネント」を入れている。`useState` はそれを読み、
**その Fiber と hook を束縛した `setState` を作って返す**
（本物では `dispatchSetState.bind(null, fiber, queue)`）。

つまり、

- 宛先を知っているのは `useState` ではなく、**返ってきた `setCount` 自身**
- だから `setCount` だけを `setTimeout` や別モジュールに渡しても正しく動く
- 逆に **`useState` はレンダリング中にしか呼べない**（モジュール変数が空なので宛先が決まらない）

## 5. 基本形で気をつけること

| # | 注意点 | 理由 |
| --- | --- | --- |
| 1 | `onClick={handleClick}` と書く。`onClick={handleClick()}` は即実行される | 渡すのは関数そのもの |
| 2 | `setCount` の直後に `count` を読んでも古い | 予約であって代入ではない |
| 3 | 次の値が今の値に依存するなら `setCount(c => c + 1)` | クロージャが古い値を掴む |
| 4 | 同じ値を渡すと再レンダリングされない | `Object.is` による bailout |
| 5 | state を直接書き換えない | 通知が飛ばない。参照が同じだと bailout もする |
| 6 | hook はトップレベルで、常に同じ順序で | カーソルで同定しているから |
| 7 | 初期値の計算が重いなら `useState(() => f())` | `useState(f())` は毎レンダー実行される |
| 8 | レンダリング中に `setState` を無条件で呼ばない | 収束せず `Too many re-renders.` になる（下記） |
| 9 | `setCount` 自体は毎レンダー同じ関数 | 依存配列に入れる必要はない（後のテーマで効く） |

## 6. レンダリング中の setState

```tsx
function Bad() {
  const [n, setN] = useState(0);
  setN(n + 1);          // ← 無条件。レンダーのたびに必ずまた更新が積まれる
  return <p>{n}</p>;    //    React は 25 回で打ち切り Too many re-renders. を投げる
}
```

止まらないのは、**レンダー → 更新 → レンダー** の輪が閉じるから。
ただしブラウザがフリーズするわけではなく、React が回数上限（25）で例外にしてくれる。

一方、**条件付きなら React は公式に許している**（`n` が条件を抜ければ積まれなくなるので収束する）。

```tsx
function Ok({ items }) {
  const [prev, setPrev] = useState(items);
  const [selected, setSelected] = useState(null);
  if (items !== prev) {   // props が変わった時だけ
    setPrev(items);
    setSelected(null);
  }
  ...
}
```

この場合 React は **DOM に反映する前に**もう一度レンダーし直すので、中間状態は画面に出ない。
とはいえ使う場面は限られる（`useEffect` で同じことをやると一度描画されてからちらつく）。

> より現実に多いのは `useEffect` の中で無条件に `setState` して
> 依存配列を書き忘れる形のループ。これはテーマ 4 で扱う。

デモ D で、無条件版が打ち切られ、条件付き版が n = 3 で収束するログを見られる。

## 7. 手を動かして確かめる

```bash
npm run dev   # 「1-補. useState の内部」タブ
```

- **デモ A**: ① で積む → hook の `queue` が伸びるが `state` は動かない → ② で畳み込まれる。
  「count + 1 を 3 回」と「c =&gt; c + 1 を 3 回」でキューの中身を比べる
- **デモ B**: 「3 秒後に表示」を押してから +1 を連打 → 出るのは押した時点の値
- **デモ C**: 直接書き換えを数回 → 「実際の中身を確認」で画面とのズレを見る
- **デモ D**: 無条件 / 条件付きで収束の有無を比べる
- **デモ E**: dispatcher の切り替わりをログで見る。順序崩れの 3 パターンを実行する

`miniReact.ts` を読んで、`inst.cursor = 0` の行をコメントアウトすると何が壊れるか試すとよい。

## 出典

- [State as a Snapshot — react.dev](https://react.dev/learn/state-as-a-snapshot)
- [Queueing a Series of State Updates — react.dev](https://react.dev/learn/queueing-a-series-of-state-updates)
- [`useState` reference（bailout と遅延初期化） — react.dev](https://react.dev/reference/react/useState)
- [Rules of Hooks — react.dev](https://react.dev/reference/rules/rules-of-hooks)
- [React ソース: `ReactHooks.js`（`resolveDispatcher`）](https://github.com/facebook/react/blob/main/packages/react/src/ReactHooks.js)
- [React ソース: `ReactFiberHooks.js`（`HooksDispatcherOnMount` / `OnUpdate`）](https://github.com/facebook/react/blob/main/packages/react-reconciler/src/ReactFiberHooks.js)
- [React hooks: not magic, just arrays — Rudi Yardley](https://medium.com/@ryardley/react-hooks-not-magic-just-arrays-cd4f1857236e)
