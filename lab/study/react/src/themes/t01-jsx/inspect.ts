import { isValidElement } from "react";
import type { ReactNode } from "react";

// React Element を「ただのオブジェクト」として覗くための道具。
// JSON.stringify だと $$typeof（Symbol）が消えてしまうので自前で文字列化する。
export function describe(node: ReactNode, depth = 0): string {
  const pad = "  ".repeat(depth);
  const pad2 = "  ".repeat(depth + 1);

  if (node === null || node === undefined || typeof node === "boolean") {
    // null / undefined / boolean は「何も描かない」を意味する。エラーにはならない。
    return `${String(node)}  // 描画されない`;
  }
  if (typeof node === "string" || typeof node === "number") {
    // 文字列と数値は Element ではなく、そのままテキストノードになる素材
    return JSON.stringify(node);
  }
  if (Array.isArray(node)) {
    return `[\n${node.map((n) => pad2 + describe(n, depth + 1)).join(",\n")}\n${pad}]`;
  }
  if (isValidElement(node)) {
    const el = node as { type: unknown; key: unknown; props: Record<string, unknown> };
    const { children, ...rest } = el.props;
    const propLines = Object.entries(rest).map(([k, v]) => `${pad2}  ${k}: ${JSON.stringify(v)}`);
    if (children !== undefined) {
      propLines.push(`${pad2}  children: ${describe(children as ReactNode, depth + 2)}`);
    }
    return [
      `{`,
      `${pad2}$$typeof: Symbol(react.transitional.element),`,
      `${pad2}type: ${typeValue(el.type)},${typeComment(el.type)}`,
      `${pad2}key: ${JSON.stringify(el.key ?? null)},`,
      `${pad2}props: {`,
      propLines.join(",\n"),
      `${pad2}}`,
      `${pad}}`,
    ].join("\n");
  }
  return String(node);
}

function typeValue(type: unknown): string {
  if (typeof type === "string") return `"${type}"`;
  if (typeof type === "function") return (type as { name?: string }).name || "anonymous";
  return String(type);
}

function typeComment(type: unknown): string {
  // type が文字列 = ホスト要素（そのまま実際の DOM タグになる）
  if (typeof type === "string") return `  // ホスト要素 → <${type}> が作られる`;
  // type が関数 = コンポーネント（React が後で呼び出して、さらに Element を得る）
  if (typeof type === "function") return "  // 関数コンポーネント（この時点ではまだ呼ばれていない）";
  if (typeof type === "symbol") return "  // 組み込みの特別な型（Fragment など）";
  return "";
}
