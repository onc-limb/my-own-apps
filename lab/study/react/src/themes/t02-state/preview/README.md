# テーマ 1-補2: state の発展（後のテーマの予習）

> 扱う問い: **state を「どこに・どんな形で」置くか。**
> テーマ 1 で学んだスナップショット・更新関数・イミュータブル更新を前提に、
> 後のテーマ（2 / 3 / 5）で本格的に扱う話題を先に一通り触っておく。

各デモは **NG と OK を並べて、触って差を見る** 構成。コードは次の 4 ファイルに分かれている。

| ファイル | 節 | 本編のテーマ |
| --- | --- | --- |
| [`position.tsx`](position.tsx) | 5. state は位置に紐づく／key でリセット | テーマ 2（条件分岐・リスト・key） |
| [`controlled.tsx`](controlled.tsx) | 6. 制御コンポーネントとリフトアップ | テーマ 3（フォーム） |
| [`design.tsx`](design.tsx) | 7. state の設計 | テーマ 5（状態の設計） |
| [`reducerContext.tsx`](reducerContext.tsx) | 8. useReducer と Context | テーマ 5（状態の設計） |

## 5. state はコンポーネントの「位置」に紐づく

state はコンポーネント関数や変数の中ではなく、**ツリー上の位置** に紐づけて React が保管している。

| 前回と今回で、同じ位置にあるもの | 結果 |
| --- | --- |
| 同じ型（props だけ違う） | state を **引き継ぐ** |
| 違う型、または消えた | state を **破棄する** |
| 同じ型だが key が違う | state を **破棄して作り直す** |

- **5-2 の罠**: コンポーネントの中でコンポーネントを定義すると、親のレンダリングごとに新しい関数（＝新しい型）になるので、毎回 state が消える。フォーカスが外れる症状の原因にもなる。
- **5-3 の使い方**: 「props が変わったら state を初期値に戻したい」ときは、`useEffect` で `setX(初期値)` と書かずに **`key` を付ける**。`useEffect` 版は、古い state で一度描画してから直る。
- **5-4 の罠**: リストの key に index を使うと、先頭挿入や並べ替えで **行の state が別の行へずれて移る**。データ固有の id を使う。

> 内部の話: React は前回と今回のツリーを **位置・型・key** の 3 つで対応づける。
> 3 つとも一致すれば同じ Fiber を再利用して state を引き継ぎ、どれかが違えば Fiber ごと作り直す
> （参考テーマの「Element は捨てられ、Fiber は維持される」の、維持される側の条件）。

## 6. 制御コンポーネントとリフトアップ

「制御（controlled）」という言葉は 2 つの場面で使うが、根っこは同じ考え方。
**値の正本を持たず、props で受け取り、変えたいときは関数で親に頼む** 側を「制御されている」と言う。

### フォーム入力の制御／非制御（6-1〜6-3）

| | 制御 | 非制御 |
| --- | --- | --- |
| 値の正本 | React の state | DOM |
| 書き方 | `value` + `onChange` | `defaultValue` + 送信時に `FormData` |
| 再レンダリング | 1 文字ごと | 起きない |
| 向く場面 | 入力中のバリデーション、整形、項目の連動、ボタンの活性制御 | 送信時に読めば足りるフォーム |

実務では React Hook Form（非制御ベース）がよく使われる。React 19 では `<form action={fn}>` で
`FormData` を直接受け取る書き方もある（テーマ 3 で扱う）。

よく出る警告と型の罠（6-3。DevTools の Console を開いて確認する）:

- `value` だけ渡して `onChange` がない → 入力できない読み取り専用の input になり、警告が出る
- 初期値が `undefined` → 後から文字列になる → 「uncontrolled から controlled に切り替わった」という警告が出る。**初期値は `""`**
- チェックボックスは `checked` と `e.target.checked` を使う
- `type="number"` でも `e.target.value` は **文字列**（`"3" + 1` は `"31"`）

### リフトアップ（6-4）

兄弟で state を共有したいときは、次の手順で共通の親に上げる。
**① 子から state を消す → ② 共通の親に移す → ③ 値と関数を props で渡す。**
state の正本は 1 か所だけにし、共有が必要になるまでは使う場所のなるべく近くに置く。

## 7. state の設計

| 原則 | NG | OK | デモ |
| --- | --- | --- | --- |
| 計算で出せるものは state にしない | `filteredItems` を state で持つ | `items.filter(...)` をレンダリング中に計算 | 7-1 |
| 矛盾する組み合わせを作れなくする | `isLoading` + `isError` | `status: "idle" \| "sending" \| "success" \| "error"` | 7-2 |
| 同じデータを二重に持たない | 選択中のオブジェクトをコピー | `selectedId` だけ持って `find` | 7-3 |
| 一緒に変わるものはまとめる | `x` と `y` を別々に持つ | `{ x, y }` の 1 つ | 7-4 |
| 深いネストを避ける | 木構造をそのまま入れ子で持つ | id をキーにした平らな形（正規化） | （デモなし） |

- 7-1 の NG を `useEffect` で同期させるのも典型的なアンチパターン。計算が重いときに初めて `useMemo` を検討する（テーマ 6）。
- props を state にコピーするのも 7-1 と同じ問題。props をそのまま使うか、リセットしたいなら key（5-3）を使う。

### それはそもそも useState で持つべき state か

| 種類 | 例 | 置き場所 |
| --- | --- | --- |
| UI の状態 | モーダルの開閉、入力途中の値 | `useState` |
| サーバーのデータ | API から取った一覧 | TanStack Query などのキャッシュ（テーマ 4） |
| URL の状態 | 検索条件、ページ番号、タブ | URL のクエリパラメータ（テーマ 8） |
| アプリ全体で共有する状態 | ログインユーザー、テーマ | Context や外部ストア（8） |

## 8. useReducer と Context

### useReducer（8-1）

```tsx
const [todos, dispatch] = useReducer(todosReducer, initialTodos);
dispatch({ type: "added", id, text }); // ハンドラは「何が起きたか」だけを伝える
```

- 更新ロジックが reducer（`(state, action) => 次の state`）の 1 か所に集まる。React なしで単体テストできる
- **reducer もレンダリングと同じく純粋でなければならない**（StrictMode では 2 回呼ばれる）。id の採番や API 呼び出しはハンドラ側で行う
- 更新の種類が多いとき、複数の state が連動するときに使う。単純な state なら useState で十分

### Context（8-2）

```tsx
const ThemeContext = createContext<ThemeName>("light"); // ① 作る（引数は提供元が無いときの既定値）
<ThemeContext value={theme}>...</ThemeContext>          // ② 提供する（React 18 以前は .Provider）
const theme = useContext(ThemeContext);                  // ③ 読む（一番近い提供元の値）
```

| 誤解 | 実際 |
| --- | --- |
| Context は状態管理ライブラリ | **運ぶ仕組み**。state 自体は useState や useReducer で持っている |
| 読んでいる部分だけが更新される | **value が変わると、読んでいる全員が再レンダリングされる** |
| `value={{ user, setUser }}` で問題ない | 毎回新しいオブジェクトになるので、読み手が毎回全員再レンダリングされる（対策はテーマ 6） |
| 何でも Context に入れればよい | たまにしか変わらず、あちこちで読む値向き。頻繁に変わる共有 state は外部ストア（Zustand など） |
| props の中継がつらいなら Context | まず **`children` で組み立て直す** と中継が要らなくなることが多い |

### reducer + Context（8-3）

todos と dispatch を **別々の Context に分ける** のが定石。
`dispatch` は React が同一性を保証する（再レンダリングしても同じ関数）ので、dispatch だけ読む
`AddTodo` は、todos が変わっても再レンダリングの対象にならない。
実務では `useTodos()` / `useTodosDispatch()` のようなカスタムフックで包むことが多い（テーマ 5）。

## 全体のつながり

```
state をどこに置くか
  ├ 1 コンポーネントで閉じる        → useState（5: 位置に紐づく、key でリセット）
  ├ 兄弟で共有する                  → 共通の親にリフトアップ（6-4）
  ├ 遠くの子孫まで届ける            → Context（8-2）
  └ 更新ロジックが複雑              → useReducer（8-1）
何を state にするか                 → 最小限にし、残りは計算で出す（7）
```

## 手を動かして確かめる

```bash
npm run dev   # 「1-補2. state の発展（予習）」タブを開く。DevTools の Console も開いておく
```

- **5-1**: 両方のカウンターを増やす → fancy を切り替えても残る／一時停止して戻すと 0 になる
- **5-2**: 両方のカウンターを増やす → input に 1 文字打つと NG 側だけ 0 に戻る
- **5-3**: key なしで下書きを打つ → 宛先を切り替えると残る。key ありにして同じ操作をすると消える
- **5-4**: 両方の「りんご」行にメモを打つ → 先頭に追加すると NG 側のメモが別の行にずれる
- **6-3**: Console に警告が 2 種類出る（2 番目は input に 1 文字打った瞬間に出る）。年齢に `3` を入れると `age + 1` が `31` になる
- **6-4**: NG 側は 2 つ同時に開ける。OK 側は常に 1 つだけ開く
- **7-1**: 「a」で絞り込む → 果物を追加すると NG 側にだけ出ない
- **7-2**: 失敗させたまま両方 2 回送信 → NG 側は「送信中… 失敗しました」が同時に出る
- **7-3**: 選択中の行のタイトルを書き換える → NG 側だけ古いタイトルのまま
- **8-2**: テーマを切り替える → Page・Toolbar を経由せずにボタンの色が変わる。内側の提供元は反転し、外側は既定値の light のまま
- **発展**: 7-1 の NG 版を `useEffect` で直してみて、OK 版より何が悪いかを考える（テーマ 4 の入口）

## 出典

- [Preserving and Resetting State — react.dev](https://react.dev/learn/preserving-and-resetting-state)
- [Rendering Lists（key の規則） — react.dev](https://react.dev/learn/rendering-lists)
- [`<input>` reference（controlled input / よくある警告） — react.dev](https://react.dev/reference/react-dom/components/input)
- [Sharing State Between Components — react.dev](https://react.dev/learn/sharing-state-between-components)
- [Choosing the State Structure — react.dev](https://react.dev/learn/choosing-the-state-structure)
- [You Might Not Need an Effect — react.dev](https://react.dev/learn/you-might-not-need-an-effect)
- [Extracting State Logic into a Reducer — react.dev](https://react.dev/learn/extracting-state-logic-into-a-reducer)
- [Passing Data Deeply with Context — react.dev](https://react.dev/learn/passing-data-deeply-with-context)
- [Scaling Up with Reducer and Context — react.dev](https://react.dev/learn/scaling-up-with-reducer-and-context)
- [`createContext` reference — react.dev](https://react.dev/reference/react/createContext)
