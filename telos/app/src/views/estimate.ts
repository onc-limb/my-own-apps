import { load, save } from "../storage";
import { escapeHtml, formatDate, toLines, uid } from "../util";
import { complete, extractJson, llmEnabled } from "../llm";

interface ScopeItem {
  id: string;
  task: string;
  minDays: number;
  maxDays: number;
}

interface Estimate {
  id: string;
  title: string;
  client: string;
  request: string; // 元の依頼メモ（AI の材料）
  assumptions: string[];
  items: ScopeItem[];
  exclusions: string[];
  dayRate: number; // 0 = 金額を出さない
  createdAt: string;
}

const KEY = "telos:estimates";

function loadAll(): Estimate[] {
  return load<Estimate[]>(KEY, []);
}
function saveAll(items: Estimate[]): void {
  save(KEY, items);
}

function blank(): Estimate {
  return {
    id: uid(),
    title: "",
    client: "",
    request: "",
    assumptions: [],
    items: [],
    exclusions: [],
    dayRate: 0,
    createdAt: new Date().toISOString(),
  };
}

function totals(e: Estimate): { minDays: number; maxDays: number; minCost: number; maxCost: number } {
  const minDays = e.items.reduce((s, i) => s + (i.minDays || 0), 0);
  const maxDays = e.items.reduce((s, i) => s + (i.maxDays || 0), 0);
  return { minDays, maxDays, minCost: minDays * e.dayRate, maxCost: maxDays * e.dayRate };
}

const yen = (n: number) => "¥" + Math.round(n).toLocaleString("ja-JP");
const days = (min: number, max: number) => (min === max ? `${min}` : `${min}〜${max}`);

export function renderEstimateList(root: HTMLElement): void {
  const items = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Estimate</h1>
          <p class="lead">曖昧な依頼を、前提・含むこと・含まないことに分けて見積る。赤字の入口を塞ぐ。</p>
        </div>
        <button id="new-est" class="primary">新しい見積</button>
      </div>
      ${
        items.length === 0
          ? `<p class="empty">まだ見積がありません。「含まないこと」を明示するのが、スコープ膨張を防ぐ鍵です。</p>`
          : `<ul class="card-list">${items
              .map((e) => {
                const t = totals(e);
                return `
              <li class="card">
                <a href="#/estimate/${e.id}" class="card-main">
                  <strong>${escapeHtml(e.title || "（無題）")}</strong>
                  <span class="muted">${escapeHtml(e.client) || "クライアント未設定"} ・ ${days(t.minDays, t.maxDays)} 人日 ・ ${formatDate(e.createdAt)}</span>
                </a>
                <button class="ghost danger" data-delete="${e.id}">削除</button>
              </li>`;
              })
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector("#new-est")!.addEventListener("click", () => {
    const e = blank();
    saveAll([e, ...loadAll()]);
    location.hash = `#/estimate/${e.id}`;
  });
  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("削除しますか？")) return;
      saveAll(loadAll().filter((e) => e.id !== btn.dataset.delete));
      renderEstimateList(root);
    }),
  );
}

export function renderEstimateEdit(root: HTMLElement, id: string): void {
  const all = loadAll();
  const e = all.find((x) => x.id === id);
  if (!e) {
    root.innerHTML = `<div class="page"><p class="empty">見つかりません。<a href="#/estimate">一覧に戻る</a></p></div>`;
    return;
  }

  root.innerHTML = `
    <div class="page wide">
      <p class="no-print"><a href="#/estimate">← 一覧に戻る</a></p>
      <div class="split">
        <form id="est-form" class="report-form no-print">
          <h2>見積</h2>
          <label>タイトル<input name="title" value="${escapeHtml(e.title)}" placeholder="例: 受発注システム Phase1 見積" /></label>
          <label>クライアント<input name="client" value="${escapeHtml(e.client)}" /></label>
          <label>人日単価（円・0 で金額を非表示）<input name="dayRate" type="number" min="0" step="1000" value="${e.dayRate || ""}" placeholder="例: 60000" /></label>

          <div class="ai-box">
            <label>依頼内容のメモ
              <textarea name="request" rows="4" placeholder="クライアントから聞いた要望をそのまま貼ってください。AI が作業項目・前提・含まないことに分解します。">${escapeHtml(e.request)}</textarea>
            </label>
            <button type="button" id="ai-breakdown" class="ai-btn" ${llmEnabled() ? "" : "disabled"}>✨ AIで作業分解</button>
            ${llmEnabled() ? `<span class="ai-status" id="ai-status"></span>` : `<span class="field-hint">Settings で LLM 連携を ON にすると使えます</span>`}
          </div>

          <h3 class="form-subhead">作業項目と工数（人日）</h3>
          <div id="items">
            ${e.items
              .map(
                (it) => `
              <div class="est-row" data-row="${it.id}">
                <input data-field="task" data-id="${it.id}" value="${escapeHtml(it.task)}" placeholder="作業項目" />
                <input data-field="minDays" data-id="${it.id}" type="number" min="0" step="0.5" value="${it.minDays || ""}" placeholder="min" class="num" />
                <input data-field="maxDays" data-id="${it.id}" type="number" min="0" step="0.5" value="${it.maxDays || ""}" placeholder="max" class="num" />
                <button type="button" class="ghost danger" data-remove="${it.id}">×</button>
              </div>`,
              )
              .join("")}
          </div>
          <button type="button" id="add-item" class="ghost">+ 作業項目を追加</button>

          <label class="mt">前提（1行 = 1項目）
            <textarea name="assumptions" rows="3">${escapeHtml(e.assumptions.join("\n"))}</textarea>
          </label>
          <label>含まないこと（明示してスコープ膨張を防ぐ・1行 = 1項目）
            <textarea name="exclusions" rows="3">${escapeHtml(e.exclusions.join("\n"))}</textarea>
          </label>
        </form>

        <div class="preview-pane">
          <div class="preview-toolbar no-print">
            <span class="muted">クライアントに渡せる見積書</span>
            <span class="spacer"></span>
            <button id="print" class="primary">印刷 / PDF</button>
          </div>
          <div id="paper" class="paper"></div>
        </div>
      </div>
    </div>`;

  const paper = root.querySelector<HTMLElement>("#paper")!;
  const renderPaper = () => {
    const t = totals(e);
    paper.innerHTML = `
      <article class="onepager">
        <header class="op-head">
          <h1>${escapeHtml(e.title) || '<span class="op-placeholder">見積タイトル</span>'}</h1>
          ${e.client ? `<p class="op-audience">${escapeHtml(e.client)} 御中</p>` : ""}
        </header>
        ${
          e.items.length
            ? `<table class="est-table">
                <thead><tr><th>作業項目</th><th>工数（人日）</th>${e.dayRate ? "<th>概算金額</th>" : ""}</tr></thead>
                <tbody>${e.items
                  .map(
                    (i) =>
                      `<tr><td>${escapeHtml(i.task) || "—"}</td><td class="num">${days(i.minDays || 0, i.maxDays || 0)}</td>${
                        e.dayRate ? `<td class="num">${yen((i.minDays || 0) * e.dayRate)}〜${yen((i.maxDays || 0) * e.dayRate)}</td>` : ""
                      }</tr>`,
                  )
                  .join("")}</tbody>
                <tfoot><tr><th>合計</th><th class="num">${days(t.minDays, t.maxDays)} 人日</th>${
                  e.dayRate ? `<th class="num">${yen(t.minCost)}〜${yen(t.maxCost)}</th>` : ""
                }</tr></tfoot>
              </table>`
            : `<p class="op-placeholder">作業項目を追加してください</p>`
        }
        ${e.assumptions.length ? `<section class="op-sec"><h2>前提</h2><ul>${e.assumptions.map((a) => `<li>${escapeHtml(a)}</li>`).join("")}</ul></section>` : ""}
        ${e.exclusions.length ? `<section class="op-sec op-ask"><h2>本見積に含まないもの</h2><ul>${e.exclusions.map((a) => `<li>${escapeHtml(a)}</li>`).join("")}</ul></section>` : ""}
      </article>`;
  };

  const form = root.querySelector<HTMLFormElement>("#est-form")!;
  const syncFields = () => {
    const d = new FormData(form);
    e.title = String(d.get("title") ?? "");
    e.client = String(d.get("client") ?? "");
    e.dayRate = Number(d.get("dayRate")) || 0;
    e.request = String(d.get("request") ?? "");
    e.assumptions = toLines(String(d.get("assumptions") ?? ""));
    e.exclusions = toLines(String(d.get("exclusions") ?? ""));
  };
  const syncItems = () => {
    root.querySelectorAll<HTMLElement>(".est-row").forEach((row) => {
      const item = e.items.find((i) => i.id === row.dataset.row);
      if (!item) return;
      row.querySelectorAll<HTMLInputElement>("input[data-field]").forEach((inp) => {
        const f = inp.dataset.field as keyof ScopeItem;
        if (f === "task") item.task = inp.value;
        else if (f === "minDays") item.minDays = Number(inp.value) || 0;
        else if (f === "maxDays") item.maxDays = Number(inp.value) || 0;
      });
    });
  };
  form.addEventListener("input", () => {
    syncFields();
    syncItems();
    saveAll(all);
    renderPaper();
  });

  root.querySelector("#add-item")!.addEventListener("click", () => {
    syncFields();
    syncItems();
    e.items.push({ id: uid(), task: "", minDays: 0, maxDays: 0 });
    saveAll(all);
    renderEstimateEdit(root, id);
  });
  root.querySelectorAll<HTMLButtonElement>("[data-remove]").forEach((btn) =>
    btn.addEventListener("click", () => {
      syncFields();
      e.items = e.items.filter((i) => i.id !== btn.dataset.remove);
      saveAll(all);
      renderEstimateEdit(root, id);
    }),
  );
  root.querySelector("#print")!.addEventListener("click", () => window.print());

  root.querySelector("#ai-breakdown")?.addEventListener("click", async () => {
    syncFields();
    const status = root.querySelector<HTMLElement>("#ai-status")!;
    const btn = root.querySelector<HTMLButtonElement>("#ai-breakdown")!;
    if (!e.request.trim()) {
      status.textContent = "依頼メモを入力してください";
      return;
    }
    btn.disabled = true;
    status.textContent = "分解中…";
    try {
      const system =
        "あなたは受託開発の見積を作るシニアエンジニアです。依頼を作業項目に分解し、不確実性を min/max の人日レンジで表します。曖昧な点は前提として書き出し、誤解されやすい範囲は『含まないこと』として明示します。楽観的すぎない現実的な工数を出します。";
      const prompt = `次の依頼メモから受託見積のたたき台を作ってください。出力は次のキーの JSON のみ:
{"items":[{"task":string,"minDays":number,"maxDays":number}],"assumptions":string[],"exclusions":string[]}
- items=作業項目とその工数レンジ（人日）。テスト・レビュー・打ち合わせ・環境構築も忘れず含める。
- assumptions=見積の前提（曖昧な点はここに）。
- exclusions=この見積に含まないこと（スコープ膨張を防ぐため明示）。
- メモにない機能を勝手に増やしすぎない。

依頼メモ:
${e.request}`;
      const text = await complete(prompt, system);
      const parsed = extractJson<{ items?: { task: string; minDays: number; maxDays: number }[]; assumptions?: string[]; exclusions?: string[] }>(text);
      if (!parsed) throw new Error("AI の出力を解釈できませんでした");
      if (Array.isArray(parsed.items)) {
        e.items = parsed.items.map((i) => ({ id: uid(), task: String(i.task), minDays: Number(i.minDays) || 0, maxDays: Number(i.maxDays) || 0 }));
      }
      if (Array.isArray(parsed.assumptions)) e.assumptions = parsed.assumptions;
      if (Array.isArray(parsed.exclusions)) e.exclusions = parsed.exclusions;
      saveAll(all);
      renderEstimateEdit(root, id);
    } catch (err) {
      status.textContent = `エラー: ${err instanceof Error ? err.message : String(err)}`;
      btn.disabled = false;
    }
  });

  renderPaper();
}
