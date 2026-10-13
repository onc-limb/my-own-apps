import { getSettings } from "./settings";

export function llmEnabled(): boolean {
  const s = getSettings();
  return s.llmEnabled && Boolean(s.bridgeUrl);
}

export interface Health {
  ok: boolean;
  provider: string;
  model: string;
}

export async function checkHealth(url: string): Promise<Health> {
  const res = await fetch(`${url.replace(/\/$/, "")}/api/health`);
  if (!res.ok) throw new Error(`bridge returned ${res.status}`);
  return (await res.json()) as Health;
}

/** ブリッジ経由で LLM を呼ぶ。LLM 無効時は呼び出し側で使わないこと。 */
export async function complete(prompt: string, system?: string): Promise<string> {
  const { bridgeUrl } = getSettings();
  const res = await fetch(`${bridgeUrl.replace(/\/$/, "")}/api/complete`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ prompt, system }),
  });
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(body.error ?? `bridge returned ${res.status}`);
  }
  const data = (await res.json()) as { text: string };
  return data.text;
}

/** LLM 出力から最初の JSON オブジェクト/配列を寛容に取り出す */
export function extractJson<T>(text: string): T | null {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : text;
  const start = candidate.search(/[[{]/);
  if (start === -1) return null;
  const open = candidate[start];
  const close = open === "{" ? "}" : "]";
  const end = candidate.lastIndexOf(close);
  if (end <= start) return null;
  try {
    return JSON.parse(candidate.slice(start, end + 1)) as T;
  } catch {
    return null;
  }
}
