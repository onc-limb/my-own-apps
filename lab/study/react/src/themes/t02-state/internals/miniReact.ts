// ============================================================
// useState の最小再現実装
//
// 本物の React から削ぎ落としたもの:
//   - Fiber ツリー（ここでは Instance 1 個だけ）
//   - 優先度つきスケジューリング（ここでは flush() を手で呼ぶ）
//   - DOM への差分反映
// 逆に、ここに残してあるのが useState の本質:
//   ① 値の置き場所はコンポーネント関数の「外」
//   ② どの hook かは「呼び出し順」だけで同定する
//   ③ setState は値を書き換えず「更新キューに積む」
//   ④ キューはイベントの最後にまとめて畳み込まれる（バッチング）
//   ⑤ 初回と 2 回目以降で useState の実装そのものが差し替わる（dispatcher）
// ============================================================

/** キューに積まれる 1 件の更新 */
type Update =
  | { kind: "value"; value: unknown } // setCount(1)
  | { kind: "fn"; fn: (prev: unknown) => unknown }; // setCount(c => c + 1)

type Hook = {
  /** 確定済みの値 */
  state: unknown;
  /** まだ適用されていない更新の列 */
  queue: Update[];
};

export type Instance = {
  hooks: Hook[];
  /** レンダリング中に「今何番目の hook か」を指すカーソル */
  cursor: number;
  /** 一度でもレンダリングを終えたか。本物では Fiber の current が存在するかで判定する */
  mounted: boolean;
  renderCount: number;
  log: string[];
  dirty: boolean;
  isRendering: boolean;
};

type SetState<T> = (next: T | ((prev: T) => T)) => void;

/** useState の実装を差し替えるための窓口。本物の ReactCurrentDispatcher に相当 */
type Dispatcher = {
  useState: <T>(initial: T) => [T, SetState<T>];
};

let currentInstance: Instance | null = null;
/** いま有効な useState の実装。レンダリング外では null */
let currentDispatcher: Dispatcher | null = null;

/** React が無限ループを打ち切る回数（本物も 25） */
export const RE_RENDER_LIMIT = 25;

export function createInstance(): Instance {
  return {
    hooks: [],
    cursor: 0,
    mounted: false,
    renderCount: 0,
    log: [],
    dirty: false,
    isRendering: false,
  };
}

// ------------------------------------------------------------
// 公開 API は「いまの dispatcher に委譲するだけ」の薄い関数。
// 本物の useState もこれと同じで、中身は一切持っていない。
// ------------------------------------------------------------
export function useMiniState<T>(initial: T): [T, SetState<T>] {
  if (!currentDispatcher) {
    // レンダリング外で呼ばれた = 宛先も実装も決まらない
    throw new Error(
      "Invalid hook call. Hooks can only be called inside of the body of a function component.",
    );
  }
  return currentDispatcher.useState(initial);
}

// ------------------------------------------------------------
// 初回レンダリング用の実装: hook を「作る」
// ------------------------------------------------------------
function mountState<T>(initial: T): [T, SetState<T>] {
  const inst = currentInstance as Instance;
  const index = inst.cursor;
  inst.cursor += 1;

  const hook: Hook = { state: initial, queue: [] };
  inst.hooks[index] = hook;
  inst.log.push(`  mountState: hook[${index}] を新規作成 → ${fmt(initial)}`);

  return [hook.state as T, makeSetState(inst, hook, index)];
}

// ------------------------------------------------------------
// 2 回目以降用の実装: hook を「読む」。初期値は受け取るが使わない
// ------------------------------------------------------------
function updateState<T>(initial: T): [T, SetState<T>] {
  const inst = currentInstance as Instance;
  const index = inst.cursor;
  inst.cursor += 1;

  const hook = inst.hooks[index];
  if (hook === undefined) {
    // 前回より hook が増えた = 呼び出し順が崩れている
    throw new Error("Rendered more hooks than during the previous render.");
  }
  inst.log.push(`  updateState: hook[${index}] を読み出し → ${fmt(hook.state)}（引数 ${fmt(initial)} は捨てる）`);

  return [hook.state as T, makeSetState(inst, hook, index)];
}

// ------------------------------------------------------------
// setState は Instance と hook を束縛済みの関数として作られる。
// 本物では dispatchSetState.bind(null, fiber, queue)。
// ------------------------------------------------------------
function makeSetState<T>(inst: Instance, hook: Hook, index: number): SetState<T> {
  return (next: T | ((prev: T) => T)) => {
    const update: Update =
      typeof next === "function"
        ? { kind: "fn", fn: next as (prev: unknown) => unknown }
        : { kind: "value", value: next };

    hook.queue.push(update); // ★ ここでは値を確定させない
    inst.dirty = true;
    inst.log.push(
      `setState(hook[${index}]): キューに積む ${describe(update)}` +
        `（この時点で state は ${fmt(hook.state)} のまま）` +
        (inst.isRendering ? "  ※レンダリング中に呼ばれた" : ""),
    );
  };
}

const HooksDispatcherOnMount: Dispatcher = { useState: mountState };
const HooksDispatcherOnUpdate: Dispatcher = { useState: updateState };

/** コンポーネント関数を呼ぶ = レンダリング */
export function renderInstance<T>(inst: Instance, component: () => T): T {
  const isMount = !inst.mounted;

  currentInstance = inst;
  inst.cursor = 0; // ★ 毎回カーソルを先頭へ。だから呼び出し順が一致していなければならない
  inst.renderCount += 1;
  inst.isRendering = true;

  // ★ ここが「1 回目か 2 回目以降か」の判定のすべて。
  //   useState の中でフラグを見るのではなく、実装ごと差し替える。
  currentDispatcher = isMount ? HooksDispatcherOnMount : HooksDispatcherOnUpdate;

  inst.log.push(
    `--- render #${inst.renderCount}: dispatcher = ${isMount ? "Mount（作る）" : "Update（読む）"} ---`,
  );

  try {
    return component();
  } finally {
    inst.isRendering = false;
    inst.mounted = true; // 次からは Update 側になる
    currentInstance = null;
    currentDispatcher = null; // ★ レンダリング外で hook を呼べない理由
  }
}

/** 溜まったキューを畳み込んで確定させる */
function applyQueues(inst: Instance): void {
  inst.hooks.forEach((hook, index) => {
    if (hook.queue.length === 0) return;
    const before = hook.state;
    let value = before;
    inst.log.push(`キュー適用 hook[${index}]: ${fmt(before)} を起点に ${hook.queue.length} 件`);
    for (const update of hook.queue) {
      // ★ value 更新は「上書き」、fn 更新は「直前の結果に適用」
      value = update.kind === "value" ? update.value : update.fn(value);
      inst.log.push(`    ${describe(update)} → ${fmt(value)}`);
    }
    hook.queue = [];
    if (Object.is(before, value)) {
      inst.log.push(`  確定: ${fmt(value)}（前回と同じ → React なら再レンダリングを省略）`);
    } else {
      inst.log.push(`  確定: ${fmt(value)}`);
    }
    hook.state = value;
  });
}

/**
 * イベントハンドラが最後まで走り終わった後に React がやること。
 * キューを畳み込み → 再レンダリング。レンダリング中にまた setState されたら繰り返す。
 */
export function flush<T>(inst: Instance, component: () => T): T | null {
  let result: T | null = null;
  let passes = 0;

  while (inst.dirty) {
    inst.dirty = false;
    applyQueues(inst);
    result = renderInstance(inst, component);
    passes += 1;

    if (passes > RE_RENDER_LIMIT) {
      inst.log.push(
        `!! ${RE_RENDER_LIMIT} 回を超えても収束しない → 打ち切り` +
          `（本物の React は "Too many re-renders." で例外を投げる）`,
      );
      inst.dirty = false;
      break;
    }
  }
  return result;
}

function fmt(v: unknown): string {
  return JSON.stringify(v) ?? String(v);
}

function describe(u: Update): string {
  return u.kind === "value" ? `[値 ${fmt(u.value)}]` : "[関数 c => ...]";
}
