import { createElement, Fragment } from "react";
import type { ReactElement } from "react";

// JSX を一切使わず、変換後に相当するコードを手で書いたもの。
// Theme01 の画面で、JSX 版と「完全に同じ形のオブジェクト」になることを確認する。
//
// createElement(type, props, ...children)
//   type     : 文字列 = ホスト要素(DOM タグ) / 関数 = コンポーネント
//   props    : 属性。children は props.children に入る
export function buildTreeByHand(): ReactElement {
  return createElement(
    "section",
    { className: "card", "data-name": "onc-limb" },
    createElement("h3", null, "Hello, ", "onc-limb"),
    createElement("p", null, "子要素も引数として渡されるだけ"),
  );
}

// <>...</> は Fragment という特別な type。DOM ノードを作らずに複数の子をまとめる。
export function buildFragmentByHand(): ReactElement {
  return createElement(Fragment, null, createElement("span", null, "a"), createElement("span", null, "b"));
}
