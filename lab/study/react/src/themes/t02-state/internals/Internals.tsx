import { useState } from "react";
import {
  createInstance,
  flush,
  renderInstance,
  useMiniState,
  RE_RENDER_LIMIT,
  type Instance,
} from "./miniReact";

// ============================================================
// A. ミニ React で useState を動かす
//    「① ハンドラ内で積む」→「② イベント終了後に React が処理する」
//    の 2 段階を手で分けてあるので、バッチングの正体が見える。
// ============================================================
type MiniView = {
  count: number;
  incByValue: () => void;
  incByFn: () => void;
  thriceByValue: () => void;
  thriceByFn: () => void;
  mixed: () => void;
  same: () => void;
};

function miniCounter(): MiniView {
  // count はこの「呼び出し」のローカル定数。次の呼び出しでは別の定数になる
  const [count, setCount] = useMiniState(0);

  return {
    count,
    // 下の関数はすべて、この呼び出し時点の count を閉じ込めている（クロージャ）
    incByValue: () => setCount(count + 1),
    incByFn: () => setCount((c) => c + 1),
    thriceByValue: () => {
      setCount(count + 1);
      setCount(count + 1);
      setCount(count + 1);
    },
    thriceByFn: () => {
      setCount((c) => c + 1);
      setCount((c) => c + 1);
      setCount((c) => c + 1);
    },
    mixed: () => {
      setCount(10);
      setCount((c) => c + 1);
    },
    same: () => setCount(count),
  };
}

function MiniRuntimeDemo() {
  // 初期値に関数を渡す = 遅延初期化。インスタンスは初回だけ作られる
  const [instance, setInstance] = useState<Instance>(createInstance);
  const [view, setView] = useState<MiniView | null>(null);
  // instance は React の管理外の可変オブジェクトなので、表示更新用に手動で再描画させる
  const [, bump] = useState(0);

  function mount() {
    setView(renderInstance(instance, miniCounter));
  }

  /** ① イベントハンドラの中。キューに積むだけで、まだ何も確定しない */
  function enqueue(action: () => void) {
    action();
    bump((n) => n + 1);
  }

  /** ② イベントハンドラが終わった後に React がやること */
  function commit() {
    const next = flush(instance, miniCounter);
    if (next) setView(next);
    bump((n) => n + 1);
  }

  function reset() {
    setInstance(createInstance());
    setView(null);
  }

  const pending = instance.hooks[0]?.queue.length ?? 0;

  return (
    <div className="card">
      <h3>A. 更新キューとバッチングを見る</h3>
      {view === null ? (
        <p>
          <button onClick={mount}>① マウント（コンポーネント関数の 1 回目の呼び出し）</button>
        </p>
      ) : (
        <>
          <p>
            画面に出ている count: <strong>{view.count}</strong>
            {"  /  "}関数が呼ばれた回数: <strong>{instance.renderCount}</strong>
            {"  /  "}未処理のキュー: <strong>{pending}</strong> 件
          </p>
          <p className="note">① イベントハンドラの中で呼ぶ（積むだけ。まだ画面は変わらない）</p>
          <p>
            <button onClick={() => enqueue(view.incByValue)}>setCount(count + 1)</button>{" "}
            <button onClick={() => enqueue(view.incByFn)}>setCount(c =&gt; c + 1)</button>{" "}
            <button onClick={() => enqueue(view.thriceByValue)}>count + 1 を 3 回</button>{" "}
            <button onClick={() => enqueue(view.thriceByFn)}>c =&gt; c + 1 を 3 回</button>{" "}
            <button onClick={() => enqueue(view.mixed)}>setCount(10) → c =&gt; c + 1</button>{" "}
            <button onClick={() => enqueue(view.same)}>同じ値を渡す</button>
          </p>
          <p className="note">② イベントハンドラが終わったところ（React が自動でやる部分）</p>
          <p>
            <button onClick={commit} disabled={pending === 0}>
              キューを畳み込んで再レンダリング
            </button>{" "}
            <button onClick={reset}>リセット</button>
          </p>
        </>
      )}

      <p className="note">hook の中身（state = 確定値、queue = 未処理の更新）:</p>
      <pre>{JSON.stringify(instance.hooks, null, 2)}</pre>

      <p className="note">内部で起きたこと:</p>
      <pre>{instance.log.length === 0 ? "(まだ何も起きていない)" : instance.log.join("\n")}</pre>
    </div>
  );
}

// ============================================================
// B. count のスコープを体感する
// ============================================================
function ClosureDemo() {
  const [count, setCount] = useState(0);
  const [message, setMessage] = useState("-");

  function showLater() {
    // この関数が作られたときの count がクロージャに捕まっている
    setTimeout(() => {
      setMessage(`3 秒前のレンダーが見ていた count = ${count}`);
    }, 3000);
  }

  return (
    <div className="card">
      <h3>B. count のスコープ（クロージャ）</h3>
      <p>count: <strong>{count}</strong></p>
      <p>
        <button onClick={() => setCount((c) => c + 1)}>+1</button>{" "}
        <button onClick={showLater}>3 秒後に count を表示</button>
      </p>
      <p>結果: <strong>{message}</strong></p>
      <p className="note">
        「3 秒後に表示」を押してから +1 を連打する。3 秒後に出るのは押した時点の値。
        count は「今の値を指す窓」ではなく、そのレンダー限りの定数だから。
      </p>
    </div>
  );
}

// ============================================================
// C. オブジェクトの state は参照が共有されている
// ============================================================
function ReferenceDemo() {
  const [profile, setProfile] = useState({ name: "onc-limb", age: 0 });
  const [peek, setPeek] = useState("-");

  function mutate() {
    // 参照は共有されているので、この書き換えは実際に state に届いている
    profile.age += 1;
  }

  return (
    <div className="card">
      <h3>C. 参照は共有されている（が、React は見ていない）</h3>
      <p>画面に出ている値: <strong>{JSON.stringify(profile)}</strong></p>
      <p>実際の中身: <strong>{peek}</strong></p>
      <p>
        <button onClick={mutate}>profile.age += 1（直接書き換え）</button>{" "}
        <button onClick={() => setPeek(JSON.stringify(profile))}>実際の中身を確認</button>{" "}
        <button onClick={() => setProfile((p) => ({ ...p, age: p.age + 1 }))}>
          setProfile(新しいオブジェクト)
        </button>
      </p>
      <p className="note">
        直接書き換えを数回 → 「実際の中身を確認」で画面の値とのズレが見える。
        値は届いているのに画面が変わらない ＝ React が変数を監視していない証拠。
      </p>
    </div>
  );
}

// ============================================================
// D. レンダリング中に setState を呼ぶとどうなるか
//    無条件に呼ぶと収束しない。条件付きなら収束する（React も許している）。
// ============================================================
function loopingComponent(): { n: number } {
  const [n, setN] = useMiniState(0);
  setN(n + 1); // ← 無条件。レンダーのたびに必ずまた更新が積まれる
  return { n };
}

function adjustingComponent(): { n: number } {
  const [n, setN] = useMiniState(0);
  if (n < 3) setN(n + 1); // ← 条件付き。n が 3 になれば積まれなくなる
  return { n };
}

function RenderPhaseUpdateDemo() {
  const [log, setLog] = useState<string>("");

  function run(component: () => { n: number }) {
    const inst = createInstance();
    renderInstance(inst, component); // マウント
    flush(inst, component); // 以降は React がやる処理
    setLog(inst.log.join("\n"));
  }

  return (
    <div className="card">
      <h3>D. レンダリング中の setState</h3>
      <p>
        <button onClick={() => run(loopingComponent)}>無条件に setN(n + 1)</button>{" "}
        <button onClick={() => run(adjustingComponent)}>条件付き if (n &lt; 3) setN(n + 1)</button>{" "}
        <button onClick={() => setLog("")}>クリア</button>
      </p>
      <p className="note">
        無条件版は {RE_RENDER_LIMIT} 回で打ち切られる（本物の React は "Too many re-renders." で例外）。
        条件付き版は n = 3 で収束し、DOM への反映は最後の 1 回だけ。
      </p>
      <pre>{log === "" ? "(未実行)" : log}</pre>
    </div>
  );
}


// ============================================================
// E. 「1 回目か 2 回目以降か」はどこで決まるか
//    回数を数えているのではなく、dispatcher（useState の実装）が差し替わっている。
//    その結果、hook の同定は完全に「呼び出し順」任せになる。
// ============================================================

/** 分岐の両側で hook を呼ぶ。hook の個数は変わらないので React はエラーを出せない */
function conditionalComponent(): {
  flag: boolean;
  branch: string;
  tail: string;
  toggle: () => void;
} {
  const [flag, setFlag] = useMiniState(true); // hook[0]
  let branch: string;
  if (flag) {
    const [a] = useMiniState("A 用の値"); // hook[1]（true のとき）
    branch = a;
  } else {
    const [b] = useMiniState("B 用の値"); // hook[1]（false のとき）← 同じ枠を共有してしまう
    branch = b;
  }
  const [tail] = useMiniState("末尾の値"); // hook[2]
  return { flag, branch, tail, toggle: () => setFlag((f) => !f) };
}

/** 2 回目だけ hook が増える。個数が変わるので React は検出できる */
function growingComponent(): { n: number; bump: () => void } {
  const [n, setN] = useMiniState(0); // hook[0]
  if (n > 0) {
    useMiniState("2 回目だけ現れる hook"); // hook[1]（2 回目以降だけ）
  }
  return { n, bump: () => setN((v) => v + 1) };
}

function DispatcherDemo() {
  const [output, setOutput] = useState("");

  function runShifting() {
    const inst = createInstance();
    const lines: string[] = [];
    const v1 = renderInstance(inst, conditionalComponent);
    lines.push(`1 回目 flag=${v1.flag}: branch=${JSON.stringify(v1.branch)} / tail=${JSON.stringify(v1.tail)}`);
    v1.toggle();
    const v2 = flush(inst, conditionalComponent);
    lines.push(
      `2 回目 flag=${v2?.flag}: branch=${JSON.stringify(v2?.branch)} / tail=${JSON.stringify(v2?.tail)}`,
    );
    lines.push("↑ else 側に入ったのに A 用の値が出ている。エラーも出ない（個数が変わらないため）");
    setOutput(lines.join("\n") + "\n\n" + inst.log.join("\n"));
  }

  function runGrowing() {
    const inst = createInstance();
    const lines: string[] = [];
    try {
      const v1 = renderInstance(inst, growingComponent);
      lines.push(`1 回目: n=${v1.n}（hook は 1 個）`);
      v1.bump();
      const v2 = flush(inst, growingComponent);
      lines.push(`2 回目: n=${v2?.n}`);
    } catch (e) {
      lines.push(`例外: ${(e as Error).message}`);
      lines.push("↑ hook の個数が前回と変わったので React は検出できる");
    }
    setOutput(lines.join("\n") + "\n\n" + inst.log.join("\n"));
  }

  function runOutsideRender() {
    try {
      // レンダリング外 = dispatcher が null
      useMiniState(0);
      setOutput("(エラーにならなかった)");
    } catch (e) {
      setOutput(
        `例外: ${(e as Error).message}\n\n` +
          "↑ レンダリング中だけ dispatcher が入る。外で呼ぶと実装も宛先も決まらない。",
      );
    }
  }

  return (
    <div className="card">
      <h3>E. 初回と 2 回目以降はどう区別されるか</h3>
      <p className="note">
        useState は中身を持たない薄い関数で、実体は dispatcher（Mount 用 / Update 用）にある。
        React はコンポーネントを呼ぶ直前にこれを差し替える。
      </p>
      <p>
        <button onClick={runShifting}>分岐の両側で hook（個数は同じ）</button>{" "}
        <button onClick={runGrowing}>2 回目だけ hook が増える</button>{" "}
        <button onClick={runOutsideRender}>レンダリング外で hook を呼ぶ</button>{" "}
        <button onClick={() => setOutput("")}>クリア</button>
      </p>
      <pre>{output === "" ? "(未実行)" : output}</pre>
    </div>
  );
}

export function Theme02Internals() {
  return (
    <>
      <h1>テーマ 1-補: useState の内部</h1>
      <p className="note">
        問い: なぜ変数を直接書き換えても反映されないのに、setCount だと count の値が変わるのか。
        答えは「count は変わっていない。関数がもう一度呼ばれ、新しい count が作られている」。
      </p>
      <MiniRuntimeDemo />
      <ClosureDemo />
      <ReferenceDemo />
      <RenderPhaseUpdateDemo />
      <DispatcherDemo />
    </>
  );
}
