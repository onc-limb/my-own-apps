import { useState, type ReactNode } from "react";

// ============================================================
// 6-1. 制御コンポーネント（controlled）
//      input の値の正本は React の state。
//      1 文字ごとに setName → 再レンダリング → value に反映、のループが回る。
//      だから「入力中に何かする」処理を素直に書ける。
// ============================================================
const MAX_LENGTH = 10;

export function ControlledInputDemo() {
  const [name, setName] = useState("");
  const [submitted, setSubmitted] = useState<string | null>(null);

  // エラーは state にしない。name から計算できる（→ 7-1）
  const trimmed = name.trim();
  const error = trimmed.length === 0 ? "必須です" : trimmed.length > MAX_LENGTH ? `${MAX_LENGTH} 文字以内にしてください` : null;

  return (
    <div className="card">
      <h3>6-1. 制御コンポーネント（value + onChange）</h3>
      <p>
        {/* 受け取った値をそのまま入れず、整形してから state に入れられる（ここでは大文字化） */}
        <input value={name} onChange={(e) => setName(e.target.value.toUpperCase())} placeholder="ユーザー名" />{" "}
        {name.length}/{MAX_LENGTH}
      </p>
      <p>{error ? <span className="ng">{error}</span> : <span className="ok">OK</span>}</p>
      <p>
        <button disabled={error !== null} onClick={() => setSubmitted(trimmed)}>
          送信
        </button>{" "}
        {submitted && <>送信した値: {submitted}</>}
      </p>
      <p className="note">
        入力中のバリデーション表示・整形・送信ボタンの活性制御は、すべて state から計算しているだけ。
      </p>
    </div>
  );
}

// ============================================================
// 6-2. 非制御コンポーネント（uncontrolled）
//      値の正本は DOM。React は defaultValue で初期値を渡すだけ。
//      送信時に FormData でまとめて読む。1 文字ごとの再レンダリングは起きない。
// ============================================================
export function UncontrolledFormDemo() {
  const [result, setResult] = useState<string | null>(null);

  return (
    <div className="card">
      <h3>6-2. 非制御コンポーネント（defaultValue + FormData）</h3>
      <form
        onSubmit={(e) => {
          e.preventDefault(); // ブラウザ標準の送信（ページ遷移）を止める
          const data = new FormData(e.currentTarget);
          setResult(`name=${String(data.get("name"))} / plan=${String(data.get("plan"))}`);
        }}
      >
        <p>
          {/* name 属性が FormData のキーになる */}
          <input name="name" defaultValue="ゲスト" />{" "}
          <select name="plan" defaultValue="free">
            <option value="free">Free</option>
            <option value="pro">Pro</option>
          </select>{" "}
          <button type="submit">送信</button>
        </p>
      </form>
      {result && <p>読み取った値: {result}</p>}
      <p className="note">
        入力中は React が何も知らない。送信時に読めば足りるフォームならこれで十分。
        React Hook Form もこの方式を土台にしている（テーマ 3）。
      </p>
    </div>
  );
}

// ============================================================
// 6-3. フォームでよく出る警告と型の罠
//      ブラウザの DevTools の Console を開いてから触ること。
// ============================================================
export function FormPitfallsDemo() {
  // 初期値が undefined → 最初は「非制御」扱い。文字を打つと「制御」に切り替わって警告が出る
  const [maybe, setMaybe] = useState<string>();
  const [agreed, setAgreed] = useState(false);
  const [age, setAge] = useState("");

  return (
    <div className="card">
      <h3>6-3. よく出る警告と型の罠</h3>
      <ol>
        <li>
          {/* ❌ value だけ渡して onChange がない → 打てない。Console に警告 */}
          value だけ: <input value="固定値" />
        </li>
        <li>
          {/* ❌ value が undefined → 文字列 に変わる。Console に "uncontrolled to controlled" 警告 */}
          初期値 undefined: <input value={maybe} onChange={(e) => setMaybe(e.target.value)} />
          <span className="note">（useState("") にすれば出ない）</span>
        </li>
        <li>
          {/* チェックボックスは value ではなく checked / e.target.checked */}
          <label>
            <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} /> 同意する
          </label>{" "}
          → agreed = {String(agreed)}
        </li>
        <li>
          {/* type="number" でも e.target.value は文字列 */}
          年齢: <input type="number" value={age} onChange={(e) => setAge(e.target.value)} size={5} /> → typeof ={" "}
          <code>{typeof age}</code>、age + 1 = <code>{age + 1}</code>
          <span className="note">（数値が欲しければ Number(age) か e.target.valueAsNumber）</span>
        </li>
      </ol>
    </div>
  );
}

// ============================================================
// 6-4. state のリフトアップ（lifting state up）
//      兄弟で state を共有したいときは、共通の親に上げる。
//      子は「値は props で受け取り、変えたいときは関数で親に頼む」だけになる。
//      これは 6-1 の input と同じ構造なので、この子も「制御コンポーネント」と呼ぶ。
// ============================================================

// ❌ 各パネルが自分の開閉を持つ → 「1 つだけ開く」を表現できない
function SelfManagedPanel({ title, children }: { title: string; children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <section className="panel">
      <button onClick={() => setIsOpen(!isOpen)}>{title}</button>
      {isOpen && <p>{children}</p>}
    </section>
  );
}

// ✅ 開閉は親が決める。子は state を持たない
function Panel({
  title,
  isOpen,
  onOpen,
  children,
}: {
  title: string;
  isOpen: boolean;
  onOpen: () => void;
  children: ReactNode;
}) {
  return (
    <section className="panel">
      <button onClick={onOpen} aria-expanded={isOpen}>
        {title}
      </button>
      {isOpen && <p>{children}</p>}
    </section>
  );
}

export function LiftingAccordionDemo() {
  // 正本は親に 1 か所だけ。どのパネルが開いているかを id で持つ
  const [openId, setOpenId] = useState<string | null>(null);

  return (
    <div className="card">
      <h3>6-4. リフトアップ：アコーディオン</h3>
      <div className="row">
        <div>
          <span className="ng">NG</span> 各自が state を持つ
          <SelfManagedPanel title="概要">概要の本文</SelfManagedPanel>
          <SelfManagedPanel title="料金">料金の本文</SelfManagedPanel>
        </div>
        <div>
          <span className="ok">OK</span> 親が state を持つ
          <Panel title="概要" isOpen={openId === "about"} onOpen={() => setOpenId("about")}>
            概要の本文
          </Panel>
          <Panel title="料金" isOpen={openId === "price"} onOpen={() => setOpenId("price")}>
            料金の本文
          </Panel>
        </div>
      </div>
      <p className="note">
        NG 側は両方同時に開けてしまう。OK 側は常に 1 つだけ開く。
        手順は「子から state を消す → 共通の親に移す → 値と関数を props で渡す」。
      </p>
    </div>
  );
}
