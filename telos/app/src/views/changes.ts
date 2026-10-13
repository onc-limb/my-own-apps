import { load, save } from "../storage";
import { escapeHtml, formatDate, uid } from "../util";

type ChangeStatus = "proposed" | "agreed" | "rejected";

interface Change {
  id: string;
  request: string; // 追加で出てきた依頼
  reason: string; // 背景・誰の依頼か
  impactDays: number; // 追加工数（人日）
  billable: boolean; // 追加請求するか
  status: ChangeStatus;
}

interface ChangeRegister {
  id: string;
  title: string;
  project: string;
  dayRate: number;
  changes: Change[];
  createdAt: string;
}

const KEY = "telos:changes";

const STATUS: Record<ChangeStatus, { label: string; cls: string }> = {
  proposed: { label: "提案中", cls: "status-warn" },
  agreed: { label: "合意", cls: "status-ok" },
  rejected: { label: "却下", cls: "status-bad" },
};

function loadAll(): ChangeRegister[] {
  return load<ChangeRegister[]>(KEY, []);
}
function saveAll(items: ChangeRegister[]): void {
  save(KEY, items);
}

function blank(): ChangeRegister {
  return { id: uid(), title: "", project: "", dayRate: 0, changes: [], createdAt: new Date().toISOString() };
}

const yen = (n: number) => "¥" + Math.round(n).toLocaleString("ja-JP");

// 合意済み & 請求対象の追加分だけを集計（これが「取りこぼしていた収益」）
function billableTotals(r: ChangeRegister): { days: number; cost: number } {
  const days = r.changes.filter((c) => c.billable && c.status === "agreed").reduce((s, c) => s + (c.impactDays || 0), 0);
  return { days, cost: days * r.dayRate };
}

export function renderChangesList(root: HTMLElement): void {
  const items = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Changes</h1>
          <p class="lead">「ついでにこれも」を、影響つきの見える変更に。追加分を取りこぼさない。</p>
        </div>
        <button id="new-chg" class="primary">新しい変更管理表</button>
      </div>
      ${
        items.length === 0
          ? `<p class="empty">まだありません。当初スコープ外の依頼が出たら、ここに記録して合意を取りましょう。</p>`
          : `<ul class="card-list">${items
              .map((r) => {
                const t = billableTotals(r);
                return `
              <li class="card">
                <a href="#/changes/${r.id}" class="card-main">
                  <strong>${escapeHtml(r.title || "（無題）")}</strong>
                  <span class="muted">${escapeHtml(r.project) || "プロジェクト未設定"} ・ 変更 ${r.changes.length} 件 ・ 請求対象 +${t.days} 人日 ・ ${formatDate(r.createdAt)}</span>
                </a>
                <button class="ghost danger" data-delete="${r.id}">削除</button>
              </li>`;
              })
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector("#new-chg")!.addEventListener("click", () => {
    const r = blank();
    saveAll([r, ...loadAll()]);
    location.hash = `#/changes/${r.id}`;
  });
  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("削除しますか？")) return;
      saveAll(loadAll().filter((r) => r.id !== btn.dataset.delete));
      renderChangesList(root);
    }),
  );
}

export function renderChangesEdit(root: HTMLElement, id: string): void {
  const all = loadAll();
  const r = all.find((x) => x.id === id);
  if (!r) {
    root.innerHTML = `<div class="page"><p class="empty">見つかりません。<a href="#/changes">一覧に戻る</a></p></div>`;
    return;
  }

  root.innerHTML = `
    <div class="page wide">
      <p class="no-print"><a href="#/changes">← 一覧に戻る</a></p>
      <div class="split">
        <form id="chg-form" class="report-form no-print">
          <h2>変更管理</h2>
          <label>タイトル<input name="title" value="${escapeHtml(r.title)}" placeholder="例: 受発注システム 変更管理表" /></label>
          <label>プロジェクト<input name="project" value="${escapeHtml(r.project)}" /></label>
          <label>人日単価（円・0 で金額を非表示）<input name="dayRate" type="number" min="0" step="1000" value="${r.dayRate || ""}" placeholder="例: 60000" /></label>

          <h3 class="form-subhead">変更依頼</h3>
          <div id="changes">
            ${r.changes
              .map(
                (c) => `
              <div class="chg-card" data-row="${c.id}">
                <input data-field="request" data-id="${c.id}" value="${escapeHtml(c.request)}" placeholder="追加依頼の内容" />
                <input data-field="reason" data-id="${c.id}" value="${escapeHtml(c.reason)}" placeholder="背景・依頼者" />
                <div class="chg-meta">
                  <label class="inline-num">+<input data-field="impactDays" data-id="${c.id}" type="number" min="0" step="0.5" value="${c.impactDays || ""}" class="num" /> 人日</label>
                  <label class="inline-check"><input data-field="billable" data-id="${c.id}" type="checkbox" ${c.billable ? "checked" : ""} /> 請求対象</label>
                  <select data-field="status" data-id="${c.id}">
                    ${(Object.keys(STATUS) as ChangeStatus[]).map((s) => `<option value="${s}" ${c.status === s ? "selected" : ""}>${STATUS[s].label}</option>`).join("")}
                  </select>
                  <button type="button" class="ghost danger" data-remove="${c.id}">×</button>
                </div>
              </div>`,
              )
              .join("")}
          </div>
          <button type="button" id="add-change" class="ghost">+ 変更依頼を追加</button>
        </form>

        <div class="preview-pane">
          <div class="preview-toolbar no-print">
            <span class="muted">クライアントと合意するための変更一覧</span>
            <span class="spacer"></span>
            <button id="print" class="primary">印刷 / PDF</button>
          </div>
          <div id="paper" class="paper"></div>
        </div>
      </div>
    </div>`;

  const paper = root.querySelector<HTMLElement>("#paper")!;
  const renderPaper = () => {
    const t = billableTotals(r);
    paper.innerHTML = `
      <article class="onepager">
        <header class="op-head">
          <h1>${escapeHtml(r.title) || '<span class="op-placeholder">変更管理表</span>'}</h1>
          ${r.project ? `<p class="op-audience">${escapeHtml(r.project)}</p>` : ""}
        </header>
        ${
          r.changes.length
            ? `<table class="est-table">
                <thead><tr><th>追加依頼</th><th>工数</th><th>請求</th><th>状態</th></tr></thead>
                <tbody>${r.changes
                  .map(
                    (c) =>
                      `<tr><td>${escapeHtml(c.request) || "—"}${c.reason ? `<br><span class="op-audience">${escapeHtml(c.reason)}</span>` : ""}</td><td class="num">+${c.impactDays || 0}</td><td class="num">${c.billable ? "対象" : "—"}</td><td><span class="status-badge small ${STATUS[c.status].cls}">${STATUS[c.status].label}</span></td></tr>`,
                  )
                  .join("")}</tbody>
              </table>
              <section class="op-sec op-ask" style="margin-top:1.2rem"><h2>合意済み・請求対象の追加分</h2><p><strong>+${t.days} 人日${r.dayRate ? ` / ${yen(t.cost)}` : ""}</strong></p></section>`
            : `<p class="op-placeholder">変更依頼を追加してください</p>`
        }
      </article>`;
  };

  const form = root.querySelector<HTMLFormElement>("#chg-form")!;
  const syncFields = () => {
    const d = new FormData(form);
    r.title = String(d.get("title") ?? "");
    r.project = String(d.get("project") ?? "");
    r.dayRate = Number(d.get("dayRate")) || 0;
  };
  const syncRows = () => {
    root.querySelectorAll<HTMLElement>(".chg-card").forEach((row) => {
      const c = r.changes.find((x) => x.id === row.dataset.row);
      if (!c) return;
      row.querySelectorAll<HTMLInputElement | HTMLSelectElement>("[data-field]").forEach((el) => {
        const f = el.dataset.field!;
        if (f === "request") c.request = (el as HTMLInputElement).value;
        else if (f === "reason") c.reason = (el as HTMLInputElement).value;
        else if (f === "impactDays") c.impactDays = Number((el as HTMLInputElement).value) || 0;
        else if (f === "billable") c.billable = (el as HTMLInputElement).checked;
        else if (f === "status") c.status = (el as HTMLSelectElement).value as ChangeStatus;
      });
    });
  };
  form.addEventListener("input", () => {
    syncFields();
    syncRows();
    saveAll(all);
    renderPaper();
  });

  root.querySelector("#add-change")!.addEventListener("click", () => {
    syncFields();
    syncRows();
    r.changes.push({ id: uid(), request: "", reason: "", impactDays: 0, billable: true, status: "proposed" });
    saveAll(all);
    renderChangesEdit(root, id);
  });
  root.querySelectorAll<HTMLButtonElement>("[data-remove]").forEach((btn) =>
    btn.addEventListener("click", () => {
      syncFields();
      r.changes = r.changes.filter((c) => c.id !== btn.dataset.remove);
      saveAll(all);
      renderChangesEdit(root, id);
    }),
  );
  root.querySelector("#print")!.addEventListener("click", () => window.print());

  renderPaper();
}
