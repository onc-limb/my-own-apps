import { createContext, useContext, useReducer, useState, type Dispatch, type ReactNode } from "react";

// ============================================================
// 8-1. useReducer：更新ロジックを 1 か所にまとめる
//      イベントハンドラは「何が起きたか（action）」を dispatch するだけ。
//      「どう更新するか」は reducer という純粋関数に集まる。
// ============================================================
type Todo = { id: number; text: string; done: boolean };

// 起こりうる出来事を型で列挙する。type の名前は「過去形」にすると「何が起きたか」が読みやすい
type TodoAction =
  | { type: "added"; id: number; text: string }
  | { type: "toggled"; id: number }
  | { type: "deleted"; id: number };

// reducer は純粋関数: (今の state, 起きたこと) => 次の state
// React を import しなくてもテストできる。StrictMode では 2 回呼ばれるので、中で push や API 呼び出しをしない
function todosReducer(todos: Todo[], action: TodoAction): Todo[] {
  switch (action.type) {
    case "added":
      return [...todos, { id: action.id, text: action.text, done: false }];
    case "toggled":
      return todos.map((t) => (t.id === action.id ? { ...t, done: !t.done } : t));
    case "deleted":
      return todos.filter((t) => t.id !== action.id);
  }
}

const INITIAL_TODOS: Todo[] = [
  { id: 1, text: "牛乳を買う", done: false },
  { id: 2, text: "React を学ぶ", done: true },
];

// id の採番はイベントハンドラ側で行う（reducer の中でやると StrictMode で 2 回進む）
let nextTodoId = 3;

export function TodoReducerDemo() {
  const [todos, dispatch] = useReducer(todosReducer, INITIAL_TODOS);
  const [text, setText] = useState("");

  function handleAdd() {
    if (text.trim() === "") return;
    dispatch({ type: "added", id: nextTodoId++, text });
    setText("");
  }

  return (
    <div className="card">
      <h3>8-1. useReducer</h3>
      <p>
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder="やること" />{" "}
        <button onClick={handleAdd}>追加</button>
      </p>
      <ul>
        {todos.map((todo) => (
          <li key={todo.id}>
            <label>
              <input
                type="checkbox"
                checked={todo.done}
                onChange={() => dispatch({ type: "toggled", id: todo.id })}
              />{" "}
              <span className={todo.done ? "done" : undefined}>{todo.text}</span>
            </label>{" "}
            <button onClick={() => dispatch({ type: "deleted", id: todo.id })}>削除</button>
          </li>
        ))}
      </ul>
      <p className="note">
        ハンドラには <code>setTodos(prev =&gt; prev.map(...))</code> のような更新ロジックが 1 行も無い。
        全部 todosReducer の switch に集まっている。
      </p>
    </div>
  );
}

// ============================================================
// 8-2. Context：props のバケツリレーを避ける
//      ① createContext で作る → ② 上で値を提供する → ③ 下のどこからでも useContext で読む
//      useContext は「自分より上にある、一番近い提供元」の値を読む。無ければ既定値。
// ============================================================
type ThemeName = "light" | "dark";

// 引数は「提供元が見つからなかったとき」の既定値
const ThemeContext = createContext<ThemeName>("light");

function ThemedButton({ children }: { children: ReactNode }) {
  const theme = useContext(ThemeContext);
  return <button className={`themed themed-${theme}`}>{children}（{theme}）</button>;
}

// Toolbar と Page は theme を受け取っていないし、渡してもいない（中継が不要になっている）
function Toolbar() {
  return (
    <p>
      <ThemedButton>保存</ThemedButton> <ThemedButton>キャンセル</ThemedButton>
    </p>
  );
}

function Page() {
  return <Toolbar />;
}

export function ThemeContextDemo() {
  // Context は「運ぶ仕組み」。値そのものは普通の useState で持っている
  const [theme, setTheme] = useState<ThemeName>("dark");

  return (
    <div className="card">
      <h3>8-2. Context</h3>
      <p>
        <button onClick={() => setTheme(theme === "dark" ? "light" : "dark")}>テーマを切り替える</button>
      </p>

      {/* React 19 の書き方。18 以前は <ThemeContext.Provider value={theme}> */}
      <ThemeContext value={theme}>
        <Page />
        {/* 内側で別の値を提供すると、その下はそちらを読む（一番近い提供元が勝つ） */}
        <ThemeContext value={theme === "dark" ? "light" : "dark"}>
          <p>
            内側で上書き: <ThemedButton>反転</ThemedButton>
          </p>
        </ThemeContext>
      </ThemeContext>

      <p>
        提供元の外: <ThemedButton>既定値</ThemedButton>
      </p>
      <p className="note">
        value が変わると、それを読んでいる全員が再レンダリングされる。
        だからログインユーザー・テーマ・言語のような「たまにしか変わらず、あちこちで読む」値に向く。
      </p>
    </div>
  );
}

// ============================================================
// 8-3. reducer + Context（実務でよく見る形）
//      todos と dispatch を別々の Context に分けて、ツリーのどこからでも読めるようにする。
//      dispatch は React が同一性を保証する（再レンダリングしても同じ関数）。
// ============================================================
const TodosContext = createContext<Todo[]>([]);
const TodosDispatchContext = createContext<Dispatch<TodoAction>>(() => {});

function TodosProvider({ children }: { children: ReactNode }) {
  const [todos, dispatch] = useReducer(todosReducer, INITIAL_TODOS);

  return (
    <TodosContext value={todos}>
      <TodosDispatchContext value={dispatch}>{children}</TodosDispatchContext>
    </TodosContext>
  );
}

// dispatch だけ読む。todos を読まないので、todos が変わっても再レンダリングの対象にならない
function AddTodo() {
  const dispatch = useContext(TodosDispatchContext);
  const [text, setText] = useState("");

  return (
    <p>
      <input value={text} onChange={(e) => setText(e.target.value)} placeholder="やること" />{" "}
      <button
        onClick={() => {
          if (text.trim() === "") return;
          dispatch({ type: "added", id: nextTodoId++, text });
          setText("");
        }}
      >
        追加
      </button>
    </p>
  );
}

function TodoList() {
  const todos = useContext(TodosContext);
  const dispatch = useContext(TodosDispatchContext);

  return (
    <ul>
      {todos.map((todo) => (
        <li key={todo.id}>
          <label>
            <input type="checkbox" checked={todo.done} onChange={() => dispatch({ type: "toggled", id: todo.id })} />{" "}
            <span className={todo.done ? "done" : undefined}>{todo.text}</span>
          </label>
        </li>
      ))}
    </ul>
  );
}

// 離れた場所にある集計。props を 1 つも受け取らずに同じ todos を読める
function TodoSummary() {
  const todos = useContext(TodosContext);
  const remaining = todos.filter((t) => !t.done).length;
  return <p>残り {remaining} 件</p>;
}

export function ReducerContextDemo() {
  return (
    <div className="card">
      <h3>8-3. reducer + Context</h3>
      <TodosProvider>
        <AddTodo />
        <TodoList />
        <TodoSummary />
      </TodosProvider>
      <p className="note">
        3 つの子はどれも props を受け取っていない。state の正本は TodosProvider の中の 1 か所だけ。
      </p>
    </div>
  );
}
