import { useState } from "react";
import { Theme01 } from "./themes/t01-jsx/Theme01";
import { Theme02 } from "./themes/t02-state/Theme02";
import { Theme02Internals } from "./themes/t02-state/internals/Internals";

// テーマ一覧。component には「関数そのもの」を入れる（呼び出さない）
const THEMES = [
  { id: "t02", label: "1. state とイベント", component: Theme02 },
  { id: "t02i", label: "1-補. useState の内部", component: Theme02Internals },
  { id: "t01", label: "参考. 記述層（JSX / Element）", component: Theme01 },
] as const;

export function App() {
  // 選択中のテーマ id を state で持つ。これ自体がテーマ 1 の実例になっている
  const [currentId, setCurrentId] = useState<string>(THEMES[0].id);

  // 派生する値は state にせず、そのつど計算する
  const current = THEMES.find((t) => t.id === currentId) ?? THEMES[0];
  const Current = current.component;

  return (
    <main>
      <nav className="nav">
        {THEMES.map((theme) => (
          <button
            key={theme.id}
            onClick={() => setCurrentId(theme.id)}
            aria-current={theme.id === currentId}
          >
            {theme.label}
          </button>
        ))}
      </nav>
      <Current />
    </main>
  );
}
