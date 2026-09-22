import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./style.css";

// React アプリの入口。ここだけは命令的な手続き。
// 「この DOM ノードを React の管理下に置く」という宣言を 1 回だけ行う。
const container = document.getElementById("root");
if (!container) throw new Error("#root not found");

// createRoot が返す root が、このサブツリーの所有者になる。
// root.render() に渡すのは「画面そのもの」ではなく「画面の設計図（React Element）」。
//
// StrictMode は開発時のみ有効で、コンポーネント関数と一部の処理をわざと 2 回呼ぶ。
// 「純粋でないコンポーネント」を本番前に炙り出すための仕掛け（テーマ 1 の反則デモで体感できる）。
const root = createRoot(container);
root.render(
  <StrictMode>
    <App />
  </StrictMode>,
);
