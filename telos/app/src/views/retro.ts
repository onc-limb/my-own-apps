import { load, save } from "../storage";
import { escapeHtml, formatDate, toLines, uid } from "../util";
import { complete, extractJson, llmEnabled } from "../llm";

interface Retro {
  id: string;
  title: string;
  project: string;
  delivered: string[]; // 今回の成果・納品物
  keep: string[]; // うまくいった・続けたいこと
  problem: string[]; // 課題・残っていること
  opportunities: string[]; // 次にできそうなこと（継続提案の種）
  nextProposal: string; // 継続提案の文面（client-facing）
  createdAt: string;
}

const KEY = "telos:retros";

function loadAll(): Retro[] {
  return load<Retro[]>(KEY, []);
}
function saveAll(items: Retro[]): void {
  save(KEY, items);
}

function blank(): Retro {
  return {
    id: uid(),
    title: "",
    project: "",
    delivered: [],
    keep: [],
    problem: [],
    opportunities: [],
    nextProposal: "",
    createdAt: new Date().toISOString(),
  };
}

// AI なしでも継続提案のたたき台を組む（成果 → 残課題 → 次の一手）
function heuristicProposal(r: Retro): string {
  if (!r.delivered.length && !r.problem.length && !r.opportunities.length) return "";
  const parts: string[] = [];
  if (r.delivered.length) {
    parts.push(`今回の${r.project || "プロジェクト"}では、${r.delivered.join("、")}を実現しました。`);
  }
  if (r.problem.length) {
    parts.push(`一方で、${r.problem.join("、")}が次の課題として残っています。`);
  }
  const tries = r.opportunities.length ? r.opportunities : r.problem.map((p) => `${p}への対応`);
  if (tries.length) {
    parts.push(`次のフェーズでは、${tries.join("、")}に取り組むことをご提案します。`);
  }
  return parts.join("");
}

export function renderRetroList(root: HTMLElement): void {
  const items = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Retrospective</h1>
          <p class="lead">納品で終わらせず、振り返りを次フェーズの提案に変える。</p>
        </div>
        <button id="new-retro" class="primary">新しい振り返り</button>
      </div>
      ${
        items.length === 0
          ? `<p class="empty">まだありません。リピート・紹介はフリーランスの生命線。振り返りを継続提案につなげましょう。</p>`
          : `<ul class="card-list">${items
              .map(
                (r) => `
              <li class="card">
                <a href="#/retro/${r.id}" class="card-main">
                  <strong>${escapeHtml(r.title || "（無題）")}</strong>
                  <span class="muted">${escapeHtml(r.project) || "プロジェクト未設定"} ・ ${formatDate(r.createdAt)}</span>
                </a>
                <button class="ghost danger" data-delete="${r.id}">削除</button>
              </li>`,
              )
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector("#new-retro")!.addEventListener("click", () => {
    const r = blank();
    saveAll([r, ...loadAll()]);
    location.hash = `#/retro/${r.id}`;
  });

  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("削除しますか？")) return;
      saveAll(loadAll().filter((r) => r.id !== btn.dataset.delete));
      renderRetroList(root);
    }),
  );
}

const FIELDS: { key: "delivered" | "keep" | "problem"; label: string; hint: string }[] = [
  { key: "delivered", label: "今回の成果・納品物", hint: "何を届けたか" },
  { key: "keep", label: "うまくいった・続けたいこと", hint: "Keep" },
  { key: "problem", label: "課題・残っていること", hint: "Problem（次の提案の種になる）" },
];

export function renderRetroEdit(root: HTMLElement, id: string): void {
  const items = loadAll();
  const r = items.find((x) => x.id === id);
  if (!r) {
    root.innerHTML = `<div class="page"><p class="empty">見つかりません。<a href="#/retro">一覧に戻る</a></p></div>`;
    return;
  }

  root.innerHTML = `
    <div class="page wide">
      <p class="no-print"><a href="#/retro">← 一覧に戻る</a></p>
      <div class="split">
        <form id="retro-form" class="report-form no-print">
          <h2>振り返り</h2>
          <label>タイトル<input name="title" value="${escapeHtml(r.title)}" placeholder="例: 受発注システム Phase1 ふりかえり" /></label>
          <label>プロジェクト名<input name="project" value="${escapeHtml(r.project)}" placeholder="例: 受発注システム内製化" /></label>
          ${FIELDS.map(
            (f) => `
            <label>${f.label}<span class="field-hint">${f.hint}（1行 = 1項目）</span>
              <textarea name="${f.key}" rows="3">${escapeHtml(r[f.key].join("\n"))}</textarea>
            </label>`,
          ).join("")}

          <div class="ai-box">
            <p class="muted" style="margin-top:0">振り返りから、次フェーズの継続提案を作ります。</p>
            <label>次にできそうなこと（任意・空なら課題から推測）
              <textarea name="opportunities" rows="3" placeholder="例: 在庫連携の自動化 / 分析ダッシュボード">${escapeHtml(r.opportunities.join("\n"))}</textarea>
            </label>
            <button type="button" id="ai-next" class="ai-btn" ${llmEnabled() ? "" : "disabled"}>✨ AIで継続提案を生成</button>
            <button type="button" id="heuristic-next" class="ghost">テンプレで生成</button>
            <span class="ai-status" id="ai-status"></span>
          </div>
          <label>継続提案の文面（生成後に手直しできます）
            <textarea name="nextProposal" rows="6">${escapeHtml(r.nextProposal)}</textarea>
          </label>
        </form>

        <div class="preview-pane">
          <div class="preview-toolbar no-print">
            <span class="muted">クライアントに渡せる一枚（振り返り + 次のご提案）</span>
            <span class="spacer"></span>
            <button id="print" class="primary">印刷 / PDF</button>
          </div>
          <div id="paper" class="paper"></div>
        </div>
      </div>
    </div>`;

  const paper = root.querySelector<HTMLElement>("#paper")!;
  const renderPaper = () => {
    const list = (xs: string[]) => (xs.length ? `<ul>${xs.map((x) => `<li>${escapeHtml(x)}</li>`).join("")}</ul>` : "");
    paper.innerHTML = `
      <article class="onepager">
        <header class="op-head">
          <h1>${escapeHtml(r.title) || '<span class="op-placeholder">タイトル</span>'}</h1>
          ${r.project ? `<p class="op-audience">${escapeHtml(r.project)}</p>` : ""}
        </header>
        ${r.delivered.length ? `<section class="op-sec"><h2>今回の成果</h2>${list(r.delivered)}</section>` : ""}
        ${r.keep.length ? `<section class="op-sec"><h2>続けたいこと</h2>${list(r.keep)}</section>` : ""}
        ${r.problem.length ? `<section class="op-sec"><h2>残った課題</h2>${list(r.problem)}</section>` : ""}
        ${
          r.nextProposal.trim()
            ? `<section class="op-sec op-ask"><h2>次フェーズのご提案</h2><p>${escapeHtml(r.nextProposal).replaceAll("\n", "<br>")}</p></section>`
            : ""
        }
      </article>`;
  };

  const form = root.querySelector<HTMLFormElement>("#retro-form")!;
  const sync = () => {
    const d = new FormData(form);
    r.title = String(d.get("title") ?? "");
    r.project = String(d.get("project") ?? "");
    r.delivered = toLines(String(d.get("delivered") ?? ""));
    r.keep = toLines(String(d.get("keep") ?? ""));
    r.problem = toLines(String(d.get("problem") ?? ""));
    r.opportunities = toLines(String(d.get("opportunities") ?? ""));
    r.nextProposal = String(d.get("nextProposal") ?? "");
    saveAll(items);
  };
  form.addEventListener("input", () => {
    sync();
    renderPaper();
  });

  root.querySelector("#print")!.addEventListener("click", () => window.print());

  root.querySelector("#heuristic-next")!.addEventListener("click", () => {
    sync();
    r.nextProposal = heuristicProposal(r);
    saveAll(items);
    renderRetroEdit(root, id);
  });

  root.querySelector("#ai-next")?.addEventListener("click", async () => {
    sync();
    const status = root.querySelector<HTMLElement>("#ai-status")!;
    const btn = root.querySelector<HTMLButtonElement>("#ai-next")!;
    if (!r.delivered.length && !r.problem.length) {
      status.textContent = "成果か課題を入力してください";
      return;
    }
    btn.disabled = true;
    status.textContent = "生成中…";
    try {
      const system =
        "あなたはフリーランスエンジニアの継続提案を支援する営業パートナーです。成果を踏まえ、押し付けがましくなく、相手の事業メリットを起点に次フェーズを提案します。事実にない成果や数値を創作しません。";
      const prompt = `次の振り返りから、クライアントに渡す「次フェーズのご提案」を作ってください。出力は次のキーの JSON のみ:
{"opportunities":string[],"nextProposal":string}
- opportunities=次に取り組むと価値が出ることの短い箇条書き（最大4件）。
- nextProposal=継続提案の文面（200〜300字、3〜4文）。「今回の成果 → 残課題 → 次フェーズで実現すること → 一緒に進める価値」の流れ。

プロジェクト: ${r.project || "（未設定）"}
今回の成果: ${r.delivered.join(" / ") || "（なし）"}
続けたいこと: ${r.keep.join(" / ") || "（なし）"}
残った課題: ${r.problem.join(" / ") || "（なし）"}
次にできそうなこと（ヒント）: ${r.opportunities.join(" / ") || "（なし）"}`;
      const text = await complete(prompt, system);
      const parsed = extractJson<{ opportunities?: string[]; nextProposal?: string }>(text);
      if (!parsed) throw new Error("AI の出力を解釈できませんでした");
      if (Array.isArray(parsed.opportunities)) r.opportunities = parsed.opportunities;
      if (parsed.nextProposal) r.nextProposal = parsed.nextProposal;
      saveAll(items);
      renderRetroEdit(root, id);
    } catch (e) {
      status.textContent = `エラー: ${e instanceof Error ? e.message : String(e)}`;
      btn.disabled = false;
    }
  });

  renderPaper();
}
