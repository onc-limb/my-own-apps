# テーマ 1: state とイベント

> 扱う問い: **画面を変えるとは、React では何をすることか。**

## 0. 頭の切り替え

素の JS では「値を書き換えて、その結果 DOM を触る」を人間が両方やる。
React では **DOM を触るのをやめて、state を宣言し、画面をその関数として書く**。

```
素の JS :  イベント → 変数を更新 → 該当する DOM を探して書き換える（二重管理）
React   :  イベント → state を更新 → 画面は React が作り直す（state が唯一の正）
```

「どの DOM を書き換えるか」を考えなくてよくなる代わりに、
**state の設計**（何を state にするか、どこに置くか）が仕事になる。

## 1. 書き方の基本

```tsx
const [count, setCount] = useState(0);

<button onClick={() => setCount(count + 1)}>+1</button>
```

- `useState(初期値)` が `[現在の値, 更新関数]` を返す
- `onClick` に渡すのは **関数そのもの**。`onClick={handleClick()}` と書くと即実行される
- 更新関数を呼ぶのは「値の代入」ではなく **「再レンダリングの予約」**

## 2. state はスナップショット（ここが最大の山）

```tsx
function addThreeWrong() {
  setCount(count + 1);   // count は 0 のまま
  setCount(count + 1);   // count は 0 のまま
  setCount(count + 1);   // count は 0 のまま  → 結果は 1
}

function addThreeRight() {
  setCount((c) => c + 1);
  setCount((c) => c + 1);
  setCount((c) => c + 1); // → 結果は 3
}
```

**1 回のレンダーの間、`count` は固定された定数**。イベントハンドラはそのレンダー時点の値を
クロージャに閉じ込めている。だから `setCount` を呼んでも、その行の直後に `count` が変わることはない。

**実務上のルール: 次の値が「今の値」に依存するなら、必ず関数形式で書く。**
（非同期処理のあと、連続したイベント、タイマー内の更新などで事故る）

### 自動バッチング

同じイベント内の複数の更新は 1 回の再レンダリングにまとめられる（React 18 以降は
`setTimeout` や `fetch` の中でも同様）。途中経過が描画されることはない。

## 3. ミューテートしない

React が更新を知る手段は **更新関数が呼ばれたこと** だけ。

```tsx
items.push("x");           // NG: 何も起きない
setItems([...items, "x"]); // OK: 新しい配列を渡す
```

さらに、`setItems(items)` のように **同じ参照** を渡した場合も
React は `Object.is` で比較して「変化なし」と判断し、再レンダリングを省略する。
だから **必ず新しいオブジェクト / 配列を作る**。

| 操作 | NG | OK |
| --- | --- | --- |
| 配列に追加 | `arr.push(x)` | `[...arr, x]` |
| 配列から削除 | `arr.splice(i, 1)` | `arr.filter((_, j) => j !== i)` |
| 配列の要素を更新 | `arr[i].done = true` | `arr.map((v, j) => j === i ? {...v, done: true} : v)` |
| 並べ替え | `arr.sort()` | `[...arr].sort()` |
| オブジェクト更新 | `obj.a = 1` | `{ ...obj, a: 1 }` |

> ネストが深い state は更新が苦痛になる。その痛み自体が
> 「state の形が悪い」「useReducer に移すべき」のサイン。

## 4. 初期値は初回だけ使われる

```tsx
useState(expensive())   // NG: 毎レンダー実行され、2 回目以降は結果が捨てられる
useState(expensive)     // OK: 初回だけ実行される（遅延初期化）
```

`localStorage` の読み込みや大きな配列の生成をここでやるときに効く。

## 5. state にしてよいもの / ダメなもの

| 判定 | 例 |
| --- | --- |
| ✅ state にする | ユーザーの入力、開閉フラグ、選択中の id、サーバーから取得したデータ |
| ❌ しない（計算する） | 合計・フィルタ結果・ソート結果など、既存の state から導ける値 |
| ❌ しない | props をそのままコピーした値（同期ズレの原因） |
| ❌ しない | 再レンダリングに関係しない値（後のテーマの `ref` の領分） |

**派生値を state にすると、必ずどこかで更新を忘れて不整合が出る。** 迷ったら計算する。

## 6. state をどこに置くか

- 使うのが 1 コンポーネントだけなら、その中に置く
- 2 つ以上のコンポーネントが必要とするなら、**共通の親に上げる**（lifting state up）
- 子は `value` と `onChange` を props で受け取るだけにする（＝制御されたコンポーネント）

この「値と更新関数を props で降ろす」形が、次テーマのフォームでそのまま使われる。

## 7. 内部で何が起きているか（必要最小限）

state は **Fiber（コンポーネントの実体）に保存された連結リスト**に入っている。
どの `useState` がどの値かは **名前ではなく呼び出し順** で同定される。

```tsx
// これが hooks のルールの理由
if (cond) {
  const [a] = useState(0);  // ← 条件で呼ばれたり呼ばれなかったりすると順序がずれ、
}                           //    別の state を掴んでしまう
const [b] = useState(0);
```

→ **hook はコンポーネントのトップレベルで、常に同じ順序で呼ぶ。**
ループ・条件分岐・早期 return の後ろに置かない。ESLint の `react-hooks` プラグインが検出する。

更新関数を呼ぶと、その Fiber の更新キューに積まれ、React がスケジューリングして
再レンダリング → 差分計算 → DOM 反映を行う。詳細は調停（reconciliation）の話で、いまは不要。

## 8. よくある誤解

| 誤解 | 実際 |
| --- | --- |
| `setCount` は代入 | 再レンダリングの予約。直後に `count` は変わらない |
| 更新のたびに DOM が全部作り直される | 作り直されるのは Element。DOM は差分だけ |
| 再レンダリング＝重い | 関数の再実行とオブジェクト生成。重いのは中身次第 |
| 合計などは state にして同期する | 計算する。state は「導けないもの」だけ |
| `useState` はコンポーネントごとに共有される | インスタンスごと。同じコンポーネントを 2 つ置けば state も 2 つ |

## 9. 手を動かして確かめる

```bash
npm run dev
```

- 「2. state はスナップショット」で左右のボタンの差を確認する
- 「3. 直接書き換えない」で左を数回押した後に右を押すと、溜まっていた項目が一気に現れる
- 「4. 初期値」でボタンを押すたびに上のカウントだけが増える
- 「5. 反則デモ」で 1 クリックにつき 2 増えることを確認し、`main.tsx` の `StrictMode` を外すと
  1 ずつになることを試す（確認後は戻すこと）

## 出典

- [State: A Component's Memory — react.dev](https://react.dev/learn/state-a-components-memory)
- [State as a Snapshot — react.dev](https://react.dev/learn/state-as-a-snapshot)
- [Queueing a Series of State Updates — react.dev](https://react.dev/learn/queueing-a-series-of-state-updates)
- [Updating Objects in State / Updating Arrays in State — react.dev](https://react.dev/learn/updating-objects-in-state)
- [Choosing the State Structure — react.dev](https://react.dev/learn/choosing-the-state-structure)
- [Sharing State Between Components（lifting state up） — react.dev](https://react.dev/learn/sharing-state-between-components)
- [`useState` reference — react.dev](https://react.dev/reference/react/useState)
- [Rules of Hooks — react.dev](https://react.dev/reference/rules/rules-of-hooks)
