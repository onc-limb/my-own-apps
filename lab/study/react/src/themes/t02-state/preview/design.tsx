import { useState } from "react";

// ============================================================
// 7-1. 計算で出せるものは state にしない（最重要）
//      絞り込み結果を state にすると、元データの更新時に同期し忘れる。
// ============================================================
const INITIAL_FRUITS = ["apple", "banana", "cherry"];
const EXTRA_FRUITS = ["mango", "papaya", "grape"];

export function DerivedStateDemo() {
  const [items, setItems] = useState(INITIAL_FRUITS);
  const [query, setQuery] = useState("");

  // ❌ NG: 絞り込み結果を state で持つ。query を変えたときしか更新していない
  const [filteredNg, setFilteredNg] = useState(INITIAL_FRUITS);

  function handleQuery(next: string) {
    setQuery(next);
    setFilteredNg(items.filter((item) => item.includes(next)));
  }

  function addItem() {
    const next = EXTRA_FRUITS[items.length - INITIAL_FRUITS.length];
    if (!next) return;
    setItems((prev) => [...prev, next]);
    // ← ここで filteredNg を更新し忘れている。state が 2 つあると、こういう「忘れ」が必ずどこかで起きる
  }

  // ✅ OK: レンダリング中に計算する。items か query が変われば、次のレンダリングで必ず正しくなる
  const filtered = items.filter((item) => item.includes(query));

  return (
    <div className="card">
      <h3>7-1. 計算で出せるものは state にしない</h3>
      <p>
        <input value={query} onChange={(e) => handleQuery(e.target.value)} placeholder="絞り込み（例: a）" />{" "}
        <button onClick={addItem} disabled={items.length >= INITIAL_FRUITS.length + EXTRA_FRUITS.length}>
          果物を 1 つ追加
        </button>
      </p>
      <div className="row">
        <div>
          <span className="ng">NG</span> 絞り込み結果を state で持つ
          <ul>
            {filteredNg.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </div>
        <div>
          <span className="ok">OK</span> レンダリング中に計算する
          <ul>
            {filtered.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </div>
      </div>
      <p className="note">
        「a」で絞り込んでから追加すると、NG 側だけ新しい果物が出ない。
        これを useEffect で同期させるのも典型的なアンチパターン（1 回古い画面を描いてから直る）。
        計算が重いときに初めて useMemo を検討する（テーマ 6）。
      </p>
    </div>
  );
}

// ============================================================
// 7-2. 矛盾する組み合わせを作れないようにする
//      boolean を 2 つ持つと 2×2=4 通りの状態が表現できてしまい、
//      「送信中かつ失敗」のような、ありえない状態が生まれる。
// ============================================================
type Status = "idle" | "sending" | "success" | "error";

const FAKE_DELAY_MS = 800;

export function StatusUnionDemo() {
  const [shouldFail, setShouldFail] = useState(true);

  // ❌ NG: 独立した boolean 2 つ
  const [isLoading, setIsLoading] = useState(false);
  const [isError, setIsError] = useState(false);

  function sendNg() {
    setIsLoading(true);
    // ← 前回の isError を戻し忘れている。再送中に「送信中」と「失敗」が同時に出る
    setTimeout(() => {
      setIsLoading(false);
      if (shouldFail) setIsError(true);
    }, FAKE_DELAY_MS);
  }

  // ✅ OK: 取りうる状態を 1 つの値で表す。ありえない組み合わせは型で書けない
  const [status, setStatus] = useState<Status>("idle");

  function sendOk() {
    setStatus("sending");
    // shouldFail はクリックした時点のスナップショット（テーマ 1 の復習）
    setTimeout(() => setStatus(shouldFail ? "error" : "success"), FAKE_DELAY_MS);
  }

  return (
    <div className="card">
      <h3>7-2. 矛盾する組み合わせを作れないようにする</h3>
      <p>
        <label>
          <input type="checkbox" checked={shouldFail} onChange={(e) => setShouldFail(e.target.checked)} /> 送信を失敗させる
        </label>
      </p>
      <div className="row">
        <div>
          <span className="ng">NG</span> isLoading + isError
          <p>
            <button onClick={sendNg}>送信</button>
          </p>
          <p>
            {isLoading && <span>送信中… </span>}
            {isError && <span className="ng">失敗しました </span>}
            {!isLoading && !isError && <span>待機中</span>}
          </p>
        </div>
        <div>
          <span className="ok">OK</span> status 1 つ
          <p>
            <button onClick={sendOk} disabled={status === "sending"}>
              送信
            </button>
          </p>
          <p>
            {status === "idle" && <span>待機中</span>}
            {status === "sending" && <span>送信中…</span>}
            {status === "success" && <span className="ok">成功しました</span>}
            {status === "error" && <span className="ng">失敗しました</span>}
          </p>
        </div>
      </div>
      <p className="note">
        失敗させたまま両方 2 回送信すると、NG 側は 2 回目に「送信中… 失敗しました」が同時に出る。
        チェックを外して送信しても NG 側は「失敗しました」が消えない。
      </p>
    </div>
  );
}

// ============================================================
// 7-3. 同じデータを二重に持たない（選択は id で持つ）
//      一覧の 1 件をオブジェクトごと state にコピーすると、
//      一覧側を編集してもコピー側は古いまま。
// ============================================================
type Doc = { id: number; title: string };

const INITIAL_DOCS: Doc[] = [
  { id: 1, title: "企画書" },
  { id: 2, title: "見積書" },
  { id: 3, title: "議事録" },
];

export function SelectByIdDemo() {
  const [docs, setDocs] = useState(INITIAL_DOCS);

  // ❌ NG: 選択中のオブジェクトをコピーして持つ
  const [selectedDocNg, setSelectedDocNg] = useState<Doc>(INITIAL_DOCS[0]);

  // ✅ OK: id だけ持ち、表示するときに探す
  const [selectedId, setSelectedId] = useState(INITIAL_DOCS[0].id);
  const selectedDoc = docs.find((d) => d.id === selectedId);

  function select(doc: Doc) {
    setSelectedDocNg(doc);
    setSelectedId(doc.id);
  }

  function rename(id: number, title: string) {
    setDocs((prev) => prev.map((d) => (d.id === id ? { ...d, title } : d)));
  }

  return (
    <div className="card">
      <h3>7-3. 選択は id で持つ</h3>
      <ul>
        {docs.map((doc) => (
          <li key={doc.id}>
            <input value={doc.title} onChange={(e) => rename(doc.id, e.target.value)} size={10} />{" "}
            <button onClick={() => select(doc)} aria-current={doc.id === selectedId}>
              選択
            </button>
          </li>
        ))}
      </ul>
      <p>
        <span className="ng">NG</span> 選択中（オブジェクトのコピー）: <strong>{selectedDocNg.title}</strong>
        <br />
        <span className="ok">OK</span> 選択中（id から検索）: <strong>{selectedDoc?.title}</strong>
      </p>
      <p className="note">選択中の行のタイトルを書き換えると、NG 側だけ古いタイトルのまま残る。</p>
    </div>
  );
}

// ============================================================
// 7-4. 常に一緒に変わるものはまとめる
//      x と y は必ずセットで変わる。別々の state にする理由がない。
// ============================================================
export function GroupedStateDemo() {
  const [position, setPosition] = useState({ x: 0, y: 0 });

  return (
    <div className="card">
      <h3>7-4. 一緒に変わるものは 1 つにまとめる</h3>
      <div
        className="pad"
        onPointerMove={(e) => {
          const rect = e.currentTarget.getBoundingClientRect();
          // 更新は常に「新しいオブジェクト」で。position.x = ... と書き換えない
          setPosition({ x: Math.round(e.clientX - rect.left), y: Math.round(e.clientY - rect.top) });
        }}
      >
        <span className="dot" style={{ left: position.x, top: position.y }} />
        ここでマウスを動かす
      </div>
      <p>
        position = <code>{JSON.stringify(position)}</code>
      </p>
      <p className="note">
        逆に、一部のフィールドだけ更新したいときは <code>{"{ ...prev, x }"}</code> のようにスプレッドで残りを保つ。
      </p>
    </div>
  );
}
