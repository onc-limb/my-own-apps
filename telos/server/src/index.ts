/**
 * telos LLM bridge
 * -----------------
 * ブラウザ（telos app）と LLM の間に立つローカル中継サーバ。
 * API キーを画面に持たせず、サーバ側で2つの利用形態を切り替えられる:
 *
 *   1. claude-cli モード（既定）: ローカルの `claude -p` を呼ぶ。
 *      Claude のサブスクリプション（Pro / Max / Team）をそのまま使え、
 *      トークン課金の API キーが要らない。
 *   2. litellm モード: OpenAI 互換エンドポイント（LiteLLM proxy / Anthropic /
 *      OpenAI など）に API キー付きで転送する。
 *
 * 設定はすべて環境変数。詳細は server/.env.example を参照。
 */
import { createServer } from "node:http";
import { spawn } from "node:child_process";

const PORT = Number(process.env.TELOS_BRIDGE_PORT ?? 8787);
const PROVIDER = (process.env.TELOS_PROVIDER ?? "claude-cli").toLowerCase();

// claude-cli
const CLAUDE_BIN = process.env.TELOS_CLAUDE_BIN ?? "claude";
const CLAUDE_MODEL = process.env.TELOS_CLAUDE_MODEL ?? "";

// litellm / openai-compatible
const LLM_BASE_URL = (process.env.TELOS_LLM_BASE_URL ?? "http://localhost:4000").replace(/\/$/, "");
const LLM_API_KEY = process.env.TELOS_LLM_API_KEY ?? "";
const LLM_MODEL = process.env.TELOS_LLM_MODEL ?? "claude-sonnet-4-6";

const TIMEOUT_MS = Number(process.env.TELOS_TIMEOUT_MS ?? 120_000);

interface CompleteRequest {
  prompt: string;
  system?: string;
}

function modelLabel(): string {
  if (PROVIDER === "claude-cli") return CLAUDE_MODEL || "claude (subscription)";
  return LLM_MODEL;
}

/** `claude -p` をサブプロセスで実行し、サブスクリプションで補完する */
function completeViaClaudeCli(req: CompleteRequest): Promise<string> {
  return new Promise((resolve, reject) => {
    const args = ["-p", "--output-format", "text"];
    if (req.system) args.push("--append-system-prompt", req.system);
    if (CLAUDE_MODEL) args.push("--model", CLAUDE_MODEL);

    const child = spawn(CLAUDE_BIN, args, { stdio: ["pipe", "pipe", "pipe"] });
    let out = "";
    let err = "";
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error(`claude CLI timed out after ${TIMEOUT_MS}ms`));
    }, TIMEOUT_MS);

    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("error", (e) => {
      clearTimeout(timer);
      reject(new Error(`failed to spawn '${CLAUDE_BIN}': ${e.message}`));
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (code === 0) resolve(out.trim());
      else reject(new Error(err.trim() || `claude CLI exited with code ${code}`));
    });

    child.stdin.write(req.prompt);
    child.stdin.end();
  });
}

/** OpenAI 互換エンドポイント（LiteLLM proxy など）に転送する */
async function completeViaLiteLLM(req: CompleteRequest): Promise<string> {
  const messages = [
    ...(req.system ? [{ role: "system", content: req.system }] : []),
    { role: "user", content: req.prompt },
  ];
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${LLM_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(LLM_API_KEY ? { Authorization: `Bearer ${LLM_API_KEY}` } : {}),
      },
      body: JSON.stringify({ model: LLM_MODEL, messages }),
      signal: controller.signal,
    });
    if (!res.ok) {
      throw new Error(`LLM endpoint returned ${res.status}: ${(await res.text()).slice(0, 300)}`);
    }
    const data = (await res.json()) as { choices?: { message?: { content?: string } }[] };
    return data.choices?.[0]?.message?.content?.trim() ?? "";
  } finally {
    clearTimeout(timer);
  }
}

function complete(req: CompleteRequest): Promise<string> {
  return PROVIDER === "claude-cli" ? completeViaClaudeCli(req) : completeViaLiteLLM(req);
}

function send(res: import("node:http").ServerResponse, status: number, body: unknown): void {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });
  res.end(payload);
}

const server = createServer((reqHttp, res) => {
  if (reqHttp.method === "OPTIONS") return send(res, 204, {});

  if (reqHttp.method === "GET" && reqHttp.url === "/api/health") {
    return send(res, 200, { ok: true, provider: PROVIDER, model: modelLabel() });
  }

  if (reqHttp.method === "POST" && reqHttp.url === "/api/complete") {
    let raw = "";
    reqHttp.on("data", (c) => (raw += c));
    reqHttp.on("end", async () => {
      try {
        const body = JSON.parse(raw || "{}") as CompleteRequest;
        if (!body.prompt?.trim()) return send(res, 400, { error: "prompt is required" });
        const text = await complete(body);
        send(res, 200, { text });
      } catch (e) {
        send(res, 500, { error: e instanceof Error ? e.message : String(e) });
      }
    });
    return;
  }

  send(res, 404, { error: "not found" });
});

server.listen(PORT, () => {
  console.log(`telos bridge listening on http://localhost:${PORT}`);
  console.log(`  provider: ${PROVIDER}  model: ${modelLabel()}`);
  if (PROVIDER === "claude-cli") {
    console.log(`  using '${CLAUDE_BIN} -p' (subscription — no API key needed)`);
  } else {
    console.log(`  forwarding to ${LLM_BASE_URL}/chat/completions`);
  }
});
