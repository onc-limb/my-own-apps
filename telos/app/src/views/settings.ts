import { getSettings, saveSettings } from "../settings";
import { checkHealth } from "../llm";
import { escapeHtml } from "../util";

const DATA_KEYS = ["telos:checklists", "telos:reports", "telos:goals", "telos:briefs", "telos:settings"];
const EXPORT_VERSION = 1;

function exportData(): void {
  const data: Record<string, unknown> = { __telos__: EXPORT_VERSION, exportedAt: new Date().toISOString() };
  for (const key of DATA_KEYS) {
    const raw = localStorage.getItem(key);
    if (raw) data[key] = JSON.parse(raw);
  }
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `telos-backup-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

async function importData(file: File, mode: "merge" | "replace"): Promise<void> {
  const text = await file.text();
  const data = JSON.parse(text) as Record<string, unknown>;
  if (!data.__telos__) throw new Error("telos のバックアップファイルではありません");

  for (const key of DATA_KEYS) {
    if (key === "telos:settings") continue; // 設定は端末固有なので取り込まない
    const incoming = data[key];
    if (incoming === undefined) continue;

    if (mode === "replace" || !Array.isArray(incoming)) {
      localStorage.setItem(key, JSON.stringify(incoming));
      continue;
    }
    // merge: id が重複しないものだけ既存に足す
    const existing = JSON.parse(localStorage.getItem(key) ?? "[]") as { id?: string }[];
    const ids = new Set(existing.map((e) => e.id));
    const merged = [...existing, ...(incoming as { id?: string }[]).filter((e) => !ids.has(e.id))];
    localStorage.setItem(key, JSON.stringify(merged));
  }
}

export function renderSettings(root: HTMLElement): void {
  const s = getSettings();
  root.innerHTML = `
    <div class="page">
      <h1>Settings</h1>

      <section class="step">
        <h2>LLM 連携（任意）</h2>
        <p class="muted">
          ローカルのブリッジサーバ経由で AI 支援を有効化します。サブスクリプション（<code>claude -p</code>）も
          API キー（LiteLLM 互換）も使えます。起動方法は <code>server/README.md</code> を参照。
        </p>
        <label class="toggle">
          <input type="checkbox" id="llm-enabled" ${s.llmEnabled ? "checked" : ""} />
          <span>LLM 連携を有効にする</span>
        </label>
        <label>Bridge URL
          <input type="text" id="bridge-url" value="${escapeHtml(s.bridgeUrl)}" placeholder="http://localhost:8787" />
        </label>
        <div class="row">
          <button id="test" class="ghost">接続テスト</button>
          <span id="test-status" class="ai-status"></span>
        </div>
      </section>

      <section class="step">
        <h2>データ管理</h2>
        <p class="muted">
          データはこの端末のブラウザ（localStorage）にのみ保存されます。バックアップや端末間移行に使ってください。
        </p>
        <div class="row">
          <button id="export" class="primary">エクスポート（JSON）</button>
        </div>
        <div class="row import-row">
          <input type="file" id="import-file" accept="application/json" />
          <button id="import-merge" class="ghost">追加で取り込む</button>
          <button id="import-replace" class="ghost danger">置き換えて取り込む</button>
        </div>
        <span id="data-status" class="ai-status"></span>
      </section>
    </div>`;

  const setStatus = (id: string, msg: string, ok = true) => {
    const el = root.querySelector<HTMLElement>(`#${id}`)!;
    el.textContent = msg;
    el.classList.toggle("err", !ok);
  };

  root.querySelector<HTMLInputElement>("#llm-enabled")!.addEventListener("change", (e) => {
    saveSettings({ llmEnabled: (e.target as HTMLInputElement).checked });
  });
  root.querySelector<HTMLInputElement>("#bridge-url")!.addEventListener("change", (e) => {
    saveSettings({ bridgeUrl: (e.target as HTMLInputElement).value.trim() });
  });

  root.querySelector("#test")!.addEventListener("click", async () => {
    const url = root.querySelector<HTMLInputElement>("#bridge-url")!.value.trim();
    saveSettings({ bridgeUrl: url });
    setStatus("test-status", "接続中…");
    try {
      const h = await checkHealth(url);
      setStatus("test-status", `OK — provider: ${h.provider} / model: ${h.model}`);
    } catch (e) {
      setStatus("test-status", `失敗: ${e instanceof Error ? e.message : String(e)}（ブリッジは起動していますか？）`, false);
    }
  });

  root.querySelector("#export")!.addEventListener("click", exportData);

  const runImport = async (mode: "merge" | "replace") => {
    const input = root.querySelector<HTMLInputElement>("#import-file")!;
    const file = input.files?.[0];
    if (!file) return setStatus("data-status", "ファイルを選んでください", false);
    if (mode === "replace" && !confirm("既存データを置き換えます。よろしいですか？")) return;
    try {
      await importData(file, mode);
      setStatus("data-status", "取り込みました。リロードします…");
      setTimeout(() => location.reload(), 800);
    } catch (e) {
      setStatus("data-status", `失敗: ${e instanceof Error ? e.message : String(e)}`, false);
    }
  };
  root.querySelector("#import-merge")!.addEventListener("click", () => runImport("merge"));
  root.querySelector("#import-replace")!.addEventListener("click", () => runImport("replace"));
}
