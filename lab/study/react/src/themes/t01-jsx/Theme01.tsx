import type { ReactNode } from "react";
import { describe } from "./inspect";
import { buildTreeByHand } from "./handwritten";

// ============================================================
// A2: コンポーネント = props を受け取って Element を返す「純関数」
//     - 引数は props ひとつ
//     - 返り値は Element（＝設計図）であって DOM ではない
//     - 同じ props なら常に同じ結果を返さなければならない（副作用を書かない）
// ============================================================
function Greeting({ name }: { name: string }) {
  return <h3>Hello, {name}</h3>;
}

// ============================================================
// A3-1: children による合成
//     JSX のタグで挟んだものは、ただの props.children として渡される。
//     「穴の開いた箱」を作れるので、継承なしで再利用できる。
// ============================================================
function Card({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="card">
      <h3>{title}</h3>
      {children}
    </section>
  );
}

// ============================================================
// A3-2: 要素そのものを props として渡す合成
//     children は「特別扱いされた props のひとつ」でしかないので、
//     好きな名前で複数の差し込み口を作れる（slot 的な使い方）。
// ============================================================
function SplitCard({ left, right }: { left: ReactNode; right: ReactNode }) {
  return (
    <section className="card">
      <div>{left}</div>
      <hr />
      <div>{right}</div>
    </section>
  );
}

export function Theme01() {
  // --- A1: JSX で書いたツリー。まだ DOM ではなく、ただのオブジェクト ---
  const jsxTree = (
    <section className="card" data-name="onc-limb">
      <h3>Hello, {"onc-limb"}</h3>
      <p>子要素も引数として渡されるだけ</p>
    </section>
  );

  // --- 同じものを createElement で手書きしたツリー ---
  const handTree = buildTreeByHand();

  // 2 つの構造が一致するか（= JSX は createElement の糖衣でしかない）
  const identical = describe(jsxTree) === describe(handTree);

  // コンポーネントは「まだ呼ばれていない」ことの確認用
  const componentElement = <Greeting name="onc-limb" />;

  return (
    <>
      <h1>テーマ 1: 記述層（JSX と React Element）</h1>
      <p className="note">
        このページの内容は React が DOM を作った結果です。index.html には空の #root しかありません。
      </p>

      <h2>1. JSX で書いたツリーの正体</h2>
      <p>次の JSX は、実行時にはこういうオブジェクトになっています。</p>
      <pre>{describe(jsxTree)}</pre>

      <h2>2. createElement で手書きしたツリー</h2>
      <p>JSX を使わずに書いたもの。構造は同一か: <strong>{identical ? "同一" : "不一致"}</strong></p>
      <pre>{describe(handTree)}</pre>

      <h2>3. コンポーネントは「まだ呼ばれていない」</h2>
      <p>
        {"<Greeting name=\"onc-limb\" />"} と書いても、Greeting 関数はこの時点では実行されません。
        type に関数そのものが入った Element ができるだけです。実際に呼ぶのは React（レンダリング時）。
      </p>
      <pre>{describe(componentElement)}</pre>
      <p className="note">
        → 「いつ関数が呼ばれるか」を React が握っていることが、後の再レンダリング制御（テーマ B / E）の土台になります。
      </p>

      <h2>4. 合成: children で穴を開ける</h2>
      <Card title="Card に挟んだ中身">
        <p>この段落は Card の props.children として渡されている</p>
        <Greeting name="children 経由" />
      </Card>

      <h2>5. 合成: 要素を props で渡す</h2>
      <SplitCard
        left={<Greeting name="left slot" />}
        right={<p>right slot に渡した要素</p>}
      />
      <p className="note">
        children は「name が children という props」にすぎません。だから差し込み口はいくつでも作れます。
      </p>
    </>
  );
}
