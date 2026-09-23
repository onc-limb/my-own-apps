import { useState } from "react";

// 各デモで使い回す、state を 1 つだけ持つカウンター
function Counter({ fancy = false }: { fancy?: boolean }) {
  const [count, setCount] = useState(0);

  return (
    <span className={fancy ? "fancy" : undefined}>
      count: <strong>{count}</strong>{" "}
      <button onClick={() => setCount((c) => c + 1)}>+1</button>
    </span>
  );
}

// ============================================================
// 5-1. state は「ツリー上の位置」に紐づく
//      React は前回と今回を「位置・型・key」で突き合わせる。
//      同じ位置に同じ型があれば state を引き継ぎ、型が変われば破棄する。
// ============================================================
export function SamePositionDemo() {
  const [isFancy, setIsFancy] = useState(false);
  const [isPaused, setIsPaused] = useState(false);

  return (
    <div className="card">
      <h3>5-1. 同じ位置・同じ型なら state は残る</h3>

      <p>
        <label>
          <input type="checkbox" checked={isFancy} onChange={(e) => setIsFancy(e.target.checked)} /> fancy にする
        </label>
        <br />
        {/* 書いた人には「別の Counter」に見えるが、React には「同じ位置の Counter の props が変わっただけ」 */}
        {isFancy ? <Counter fancy /> : <Counter />}
      </p>

      <p>
        <label>
          <input type="checkbox" checked={isPaused} onChange={(e) => setIsPaused(e.target.checked)} /> 一時停止する
        </label>
        <br />
        {/* 同じ位置の型が Counter ⇄ span で入れ替わる → Counter の state は破棄される */}
        {isPaused ? <span>一時停止中</span> : <Counter />}
      </p>

      <p className="note">
        上は何度切り替えても count が残る。下は一時停止して戻すと 0 に戻る。
      </p>
    </div>
  );
}

// ============================================================
// 5-2. 【反則デモ】コンポーネントの中でコンポーネントを定義する
//      親がレンダリングされるたびに新しい関数（＝新しい型）が作られるので、
//      React は「前回とは別のコンポーネント」と判断して state を破棄する。
// ============================================================
export function InnerDefinitionDemo() {
  const [text, setText] = useState("");

  // ❌ 反則: InnerCounter は InnerDefinitionDemo のレンダリングごとに作り直される別の関数
  function InnerCounter() {
    const [count, setCount] = useState(0);
    return (
      <span>
        count: <strong>{count}</strong> <button onClick={() => setCount((c) => c + 1)}>+1</button>
      </span>
    );
  }

  return (
    <div className="card">
      <h3>5-2. 【反則デモ】コンポーネント内でコンポーネントを定義する</h3>
      <p>
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder="ここに 1 文字打つ" />
      </p>
      <p>
        <span className="ng">NG</span> 内側で定義: <InnerCounter />
      </p>
      <p>
        <span className="ok">OK</span> トップレベルで定義: <Counter />
      </p>
      <p className="note">
        両方のカウンターを増やしてから上の input に 1 文字打つと、NG 側だけ 0 に戻る。
        コンポーネントは必ずファイルのトップレベルで定義する。
      </p>
    </div>
  );
}

// ============================================================
// 5-3. key を変えて state を意図的にリセットする
//      key が変わると React は「別のコンポーネントになった」と判断し、作り直す。
//      「props が変わったら state を初期値に戻したい」の正解はたいていこれ。
// ============================================================
type Contact = { id: string; name: string };

const CONTACTS: Contact[] = [
  { id: "taylor", name: "Taylor" },
  { id: "alice", name: "Alice" },
  { id: "bob", name: "Bob" },
];

function Chat({ contact }: { contact: Contact }) {
  // 入力途中の下書き。Chat が作り直されない限り残り続ける
  const [draft, setDraft] = useState("");

  return (
    <input
      value={draft}
      onChange={(e) => setDraft(e.target.value)}
      placeholder={`${contact.name} へのメッセージ`}
    />
  );
}

export function KeyResetDemo() {
  const [toId, setToId] = useState(CONTACTS[0].id);
  const [withKey, setWithKey] = useState(false);

  // 選択中の連絡先は id から計算する（オブジェクトを state にコピーしない → 7-3）
  const contact = CONTACTS.find((c) => c.id === toId) ?? CONTACTS[0];

  return (
    <div className="card">
      <h3>5-3. key で state をリセットする</h3>
      <p>
        {CONTACTS.map((c) => (
          <button key={c.id} onClick={() => setToId(c.id)} aria-current={c.id === toId}>
            {c.name}
          </button>
        ))}
      </p>
      <p>
        <label>
          <input type="checkbox" checked={withKey} onChange={(e) => setWithKey(e.target.checked)} /> Chat に{" "}
          <code>key={"{contact.id}"}</code> を付ける
        </label>
      </p>
      <p>{withKey ? <Chat key={contact.id} contact={contact} /> : <Chat contact={contact} />}</p>
      <p className="note">
        key なし: 下書きを打ってから宛先を切り替えると、別の人宛てに下書きが残る（誤送信の元）。
        key あり: 宛先を切り替えるたびに Chat が作り直され、下書きが消える。
        （チェックボックス自体の切り替えでも key の有無が変わるので、そのときもリセットされる）
      </p>
    </div>
  );
}

// ============================================================
// 5-4. リストの key に index を使うと state がずれる
//      key は「どの要素が前回のどれと同じか」を示す目印。
//      index は並びが変わると別の要素を指してしまう。
// ============================================================
type Row = { id: number; label: string };

function NoteRow({ label }: { label: string }) {
  // 各行が自分の state を持つ。これが key で対応づけられる
  const [note, setNote] = useState("");

  return (
    <li>
      {label}: <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="メモ" size={10} />
    </li>
  );
}

// id の採番はイベントハンドラ内で行う（更新関数やレンダリング中に外部を書き換えない）
let nextRowId = 3;

export function IndexKeyDemo() {
  const [rows, setRows] = useState<Row[]>([
    { id: 1, label: "りんご" },
    { id: 2, label: "みかん" },
  ]);

  function prepend() {
    const id = nextRowId++;
    setRows((prev) => [{ id, label: `追加 ${id}` }, ...prev]);
  }

  return (
    <div className="card">
      <h3>5-4. リストの key に index を使わない</h3>
      <p>
        <button onClick={prepend}>先頭に 1 行追加</button>
      </p>
      <div className="row">
        <div>
          <span className="ng">NG</span> <code>key={"{i}"}</code>
          <ul>
            {rows.map((row, i) => (
              <NoteRow key={i} label={row.label} />
            ))}
          </ul>
        </div>
        <div>
          <span className="ok">OK</span> <code>key={"{row.id}"}</code>
          <ul>
            {rows.map((row) => (
              <NoteRow key={row.id} label={row.label} />
            ))}
          </ul>
        </div>
      </div>
      <p className="note">
        両方の「りんご」のメモに何か打ってから先頭に追加すると、NG 側はメモが「追加 N」の行に移る。
        index 0 の state は「位置 0 の人」に残り続けるため。データ固有の id を key にする。
      </p>
    </div>
  );
}
