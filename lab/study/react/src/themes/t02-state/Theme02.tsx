import { useState } from "react";

// ============================================================
// 1. 基本形: state とイベントハンドラ
//    useState は [現在の値, 更新関数] のペアを返す。
//    更新関数を呼ぶと React に「再レンダリングの予約」が入る。
//    その場で count の値が変わるわけではない。
// ============================================================
function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div className="card">
      <h3>1. 基本形</h3>
      <p>count: <strong>{count}</strong></p>
      {/* onClick に渡すのは「関数そのもの」。onClick={handle()} と書くと即実行されてしまう */}
      <button onClick={() => setCount(count + 1)}>+1</button>{" "}
      <button onClick={() => setCount(0)}>reset</button>
    </div>
  );
}

// ============================================================
// 2. state はスナップショット（最重要）
//    1 回のイベント処理の間、count の値は固定されている。
//    だから setCount(count + 1) を 3 回書いても +1 にしかならない。
//    「次の値」ではなく「前の値からどう変えるか」を渡すのが関数形式の更新。
// ============================================================
function SnapshotDemo() {
  const [count, setCount] = useState(0);

  // count は「このレンダー時点での定数」。3 回とも同じ値を見ている
  function addThreeWrong() {
    setCount(count + 1); // count=0 なら → 1
    setCount(count + 1); // count はまだ 0 → 1
    setCount(count + 1); // count はまだ 0 → 1
  }

  // 更新関数に関数を渡すと、React がキューに積んで順番に適用する
  function addThreeRight() {
    setCount((c) => c + 1);
    setCount((c) => c + 1);
    setCount((c) => c + 1);
  }

  return (
    <div className="card">
      <h3>2. state はスナップショット</h3>
      <p>count: <strong>{count}</strong></p>
      <button onClick={addThreeWrong}>setCount(count + 1) を 3 回</button>{" "}
      <button onClick={addThreeRight}>setCount(c =&gt; c + 1) を 3 回</button>
      <p className="note">
        左は +1、右は +3。同じイベント内の更新はまとめて処理される（自動バッチング）ので、
        途中経過の再レンダリングは起きない。
      </p>
    </div>
  );
}

// ============================================================
// 3. state を直接書き換えても React は気づけない
//    React が更新を知る手段は「更新関数が呼ばれたこと」だけ。
//    配列やオブジェクトを push / 代入で変えても通知は行われない。
// ============================================================
function MutationDemo() {
  const [items, setItems] = useState<string[]>(["React", "TypeScript"]);

  // NG: 配列を直接変更している。更新関数を呼んでいないので画面は変わらない
  function addWrong() {
    items.push(`項目 ${items.length + 1}`);
  }

  // OK: 新しい配列を作って渡す
  function addRight() {
    setItems((prev) => [...prev, `項目 ${prev.length + 1}`]);
  }

  return (
    <div className="card">
      <h3>3. 直接書き換えない</h3>
      <ul>
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
      <button onClick={addWrong}>items.push(...) だけ</button>{" "}
      <button onClick={addRight}>setItems([...prev, ...])</button>
      <p className="note">
        左を押しても画面は変わらないが、配列の中身は壊れている（次に他の操作で再レンダリングされた瞬間に
        増えた項目がまとめて現れる）。これが「ミューテートしてはいけない」の実害。
      </p>
    </div>
  );
}

// ============================================================
// 4. 初期値は初回だけ使われる
//    useState(f()) は毎回 f を実行してから結果を捨てる。
//    useState(f) と渡せば初回だけ実行される（遅延初期化）。
// ============================================================
let eagerCalls = 0;
let lazyCalls = 0;

function eagerInitial(): number {
  eagerCalls += 1;
  return 0;
}

function lazyInitial(): number {
  lazyCalls += 1;
  return 0;
}

function LazyInitDemo() {
  // NG: レンダリングのたびに eagerInitial() が実行される（結果は 2 回目以降捨てられる）
  const [a, setA] = useState(eagerInitial());
  // OK: React が必要なときだけ呼ぶ。初回のみ
  const [b, setB] = useState(lazyInitial);

  return (
    <div className="card">
      <h3>4. 初期値は初回だけ使われる</h3>
      <p>
        useState(eagerInitial()) の実行回数: <strong>{eagerCalls}</strong>（a = {a}）
        <br />
        useState(lazyInitial) の実行回数: <strong>{lazyCalls}</strong>（b = {b}）
      </p>
      <button onClick={() => setA(a + 1)}>a を更新して再レンダリング</button>{" "}
      <button onClick={() => setB(b + 1)}>b を更新して再レンダリング</button>
      <p className="note">
        押すたびに上だけが増える。初期値の計算が重いとき（localStorage 読み込み、大きな配列生成など）に効く。
      </p>
    </div>
  );
}

// ============================================================
// 5. 【反則デモ】レンダリング中に外部を書き換えるとどうなるか
//    本来やってはいけない。StrictMode が開発時にわざと 2 回呼ぶので、
//    純粋でないコンポーネントは数が合わなくなって露見する。
// ============================================================
let impureRenderCount = 0;

function ImpureDemo() {
  impureRenderCount += 1; // ← 反則。レンダリング中に外部を変更している
  const [, force] = useState(0);

  return (
    <div className="card">
      <h3>5. 【反則デモ】純粋でないコンポーネント</h3>
      <p>この関数が実行された回数: <strong>{impureRenderCount}</strong></p>
      <button onClick={() => force((n) => n + 1)}>再レンダリングさせる</button>
      <p className="note">
        1 回押すと 2 増える。StrictMode（開発時のみ）がコンポーネント関数を意図的に 2 回呼ぶため。
        これは嫌がらせではなく、「React はいつ何回呼んでもよい」という前提を守れていないコードを
        本番で事故る前に見つけるための仕掛け。
      </p>
    </div>
  );
}

// ============================================================
// 6. state をどこに置くか
//    同じ state を 2 つのコンポーネントが必要とするなら、共通の親に上げる（lifting state up）。
//    下の例では合計を親が持ち、子は props で受け取るだけ。
// ============================================================
function Stepper({ label, value, onChange }: { label: string; value: number; onChange: (next: number) => void }) {
  // このコンポーネントは state を持たない（制御されている側）
  return (
    <span>
      {label}: <strong>{value}</strong>{" "}
      <button onClick={() => onChange(value + 1)}>+</button>{" "}
      <button onClick={() => onChange(value - 1)}>-</button>
    </span>
  );
}

function LiftingDemo() {
  const [left, setLeft] = useState(0);
  const [right, setRight] = useState(0);

  return (
    <div className="card">
      <h3>6. state を親に上げる</h3>
      <p>
        <Stepper label="左" value={left} onChange={setLeft} />
        {" / "}
        <Stepper label="右" value={right} onChange={setRight} />
      </p>
      {/* 合計は state にしない。既存の state から計算できるものは state にしてはいけない */}
      <p>合計: <strong>{left + right}</strong></p>
      <p className="note">
        合計は useState で持たない。持つと「左を更新したのに合計の更新を忘れた」という不整合が発生しうる。
        派生する値はレンダリングのたびに計算する。
      </p>
    </div>
  );
}

export function Theme02() {
  return (
    <>
      <h1>テーマ 1: state とイベント</h1>
      <p className="note">
        React の書き味の 8 割はここ。「値を書き換えて DOM を触る」のではなく
        「state を宣言して、その関数として画面を書く」に頭を切り替える。
      </p>
      <Counter />
      <SnapshotDemo />
      <MutationDemo />
      <LazyInitDemo />
      <ImpureDemo />
      <LiftingDemo />
    </>
  );
}
