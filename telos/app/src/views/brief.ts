import { load, save } from "../storage";
import { escapeHtml, formatDate, toLines, uid } from "../util";
import { complete, extractJson, llmEnabled } from "../llm";

interface Brief {
  id: string;
  title: string;
  audience: string;
  background: string;
  proposal: string;
  value: string[];
  cost: string;
  ask: string;
  notes: string;
  createdAt: string;
}

const KEY = "telos:briefs";

function loadAll(): Brief[] {
  return load<Brief[]>(KEY, []);
}
function saveAll(briefs: Brief[]): void {
  save(KEY, briefs);
}

function blank(): Brief {
  return {
    id: uid(),
    title: "",
    audience: "",
    background: "",
    proposal: "",
    value: [],
    cost: "",
    ask: "",
    notes: "",
    createdAt: new Date().toISOString(),
  };
}

const SECTIONS: { key: keyof Brief; label: string; hint: string }[] = [
  { key: "background", label: "背景・課題", hint: "なぜ今これを議論するのか" },
  { key: "proposal", label: "提案", hint: "何をするのか（一文で）" },
  { key: "cost", label: "コスト・前提", hint: "必要なリソース・期間・前提条件" },
  { key: "ask", label: "意思決定のお願い", hint: "相手に判断してほしいこと" },
];

export function renderBriefList(root: HTMLElement): void {
  const briefs = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Brief</h1>
          <p class="lead">ビジネス側に説明するための、ごちゃごちゃさせない一枚資料。</p>
        </div>
        <button id="new-brief" class="primary">新しい資料を作成</button>
      </div>
      ${
        briefs.length === 0
          ? `<p class="empty">まだ資料がありません。</p>`
          : `<ul class="card-list">${briefs
              .map(
                (b) => `
              <li class="card">
                <a href="#/brief/${b.id}" class="card-main">
                  <strong>${escapeHtml(b.title || "（無題）")}</strong>
                  <span class="muted">${escapeHtml(b.audience) || "対象未設定"} ・ ${formatDate(b.createdAt)}</span>
                </a>
                <button class="ghost danger" data-delete="${b.id}">削除</button>
              </li>`,
              )
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector("#new-brief")!.addEventListener("click", () => {
    const b = blank();
    saveAll([b, ...loadAll()]);
    location.hash = `#/brief/${b.id}`;
  });

  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("この資料を削除しますか？")) return;
      saveAll(loadAll().filter((b) => b.id !== btn.dataset.delete));
      renderBriefList(root);
    }),
  );
}

export function renderBriefEdit(root: HTMLElement, id: string): void {
  const briefs = loadAll();
  const brief = briefs.find((b) => b.id === id);
  if (!brief) {
    root.innerHTML = `<div class="page"><p class="empty">資料が見つかりません。<a href="#/brief">一覧に戻る</a></p></div>`;
    return;
  }

  root.innerHTML = `
    <div class="page wide">
      <p class="no-print"><a href="#/brief">← 一覧に戻る</a></p>
      <div class="split">
        <form id="brief-form" class="report-form no-print">
          <h2>内容</h2>
          <label>タイトル<input name="title" value="${escapeHtml(brief.title)}" placeholder="例: 顧客ポータル刷新の提案" /></label>
          <label>説明する相手<input name="audience" value="${escapeHtml(brief.audience)}" placeholder="例: 事業部長・経営会議" /></label>
          ${SECTIONS.filter((s) => s.key !== "value")
            .map(
              (s) => `
            <label>${s.label}<span class="field-hint">${s.hint}</span>
              <textarea name="${s.key}" rows="3">${escapeHtml(String(brief[s.key]))}</textarea>
            </label>`,
            )
            .join("")}
          <label>期待効果（1行 = 1項目）
            <textarea name="value" rows="4">${escapeHtml(brief.value.join("\n"))}</textarea>
          </label>

          <div class="ai-box">
            <label>下書きの材料（箇条書きメモでOK）
              <textarea name="notes" rows="4" placeholder="思いつくまま書いてください。AI が各セクションに整理します。">${escapeHtml(brief.notes)}</textarea>
            </label>
            <button type="button" id="ai-draft" class="ai-btn" ${llmEnabled() ? "" : "disabled"}>
              ✨ AIで下書きを生成
            </button>
            ${
              llmEnabled()
                ? `<span class="ai-status" id="ai-status"></span>`
                : `<span class="field-hint">Settings で LLM 連携を ON にすると使えます</span>`
            }
          </div>
        </form>

        <div class="preview-pane">
          <div class="preview-toolbar no-print">
            <span class="muted">プレビュー（A4・印刷で PDF 化）</span>
            <span class="spacer"></span>
            <button id="print" class="primary">印刷 / PDF</button>
          </div>
          <div id="paper" class="paper"></div>
        </div>
      </div>
    </div>`;

  const paper = root.querySelector<HTMLElement>("#paper")!;
  const renderPaper = () => {
    paper.innerHTML = `
      <article class="onepager">
        <header class="op-head">
          <h1>${escapeHtml(brief.title) || '<span class="op-placeholder">タイトル</span>'}</h1>
          ${brief.audience ? `<p class="op-audience">${escapeHtml(brief.audience)} 向け</p>` : ""}
        </header>
        ${opSection("背景・課題", brief.background)}
        ${opSection("提案", brief.proposal, true)}
        ${
          brief.value.length
            ? `<section class="op-sec"><h2>期待効果</h2><ul>${brief.value
                .map((v) => `<li>${escapeHtml(v)}</li>`)
                .join("")}</ul></section>`
            : ""
        }
        ${opSection("コスト・前提", brief.cost)}
        ${brief.ask ? `<section class="op-sec op-ask"><h2>意思決定のお願い</h2><p>${escapeHtml(brief.ask)}</p></section>` : ""}
      </article>`;
  };

  const form = root.querySelector<HTMLFormElement>("#brief-form")!;
  form.addEventListener("input", () => {
    const d = new FormData(form);
    brief.title = String(d.get("title") ?? "");
    brief.audience = String(d.get("audience") ?? "");
    brief.background = String(d.get("background") ?? "");
    brief.proposal = String(d.get("proposal") ?? "");
    brief.cost = String(d.get("cost") ?? "");
    brief.ask = String(d.get("ask") ?? "");
    brief.value = toLines(String(d.get("value") ?? ""));
    brief.notes = String(d.get("notes") ?? "");
    saveAll(briefs);
    renderPaper();
  });

  root.querySelector("#print")!.addEventListener("click", () => window.print());

  root.querySelector("#ai-draft")?.addEventListener("click", async () => {
    const status = root.querySelector<HTMLElement>("#ai-status")!;
    const btn = root.querySelector<HTMLButtonElement>("#ai-draft")!;
    const notes = brief.notes.trim();
    if (!notes) {
      status.textContent = "材料メモを入力してください";
      return;
    }
    btn.disabled = true;
    status.textContent = "生成中…";
    try {
      const system =
        "あなたは経営層向けの簡潔なビジネス資料を書く編集者です。冗長さを避け、意思決定者が30秒で理解できる日本語で書いてください。";
      const prompt = `次のメモから、ビジネス説明用の一枚資料を作ってください。出力は次のキーの JSON のみ:
{"title":string,"audience":string,"background":string,"proposal":string,"value":string[],"cost":string,"ask":string}
- background/proposal/cost/ask は2〜3文以内。
- value は効果を3〜5個の短い箇条書き。
- 推測で埋めず、メモにない数値は作らない。

メモ:
${notes}`;
      const text = await complete(prompt, system);
      const parsed = extractJson<Partial<Brief>>(text);
      if (!parsed) throw new Error("AI の出力を解釈できませんでした");
      Object.assign(brief, {
        title: parsed.title ?? brief.title,
        audience: parsed.audience ?? brief.audience,
        background: parsed.background ?? brief.background,
        proposal: parsed.proposal ?? brief.proposal,
        cost: parsed.cost ?? brief.cost,
        ask: parsed.ask ?? brief.ask,
        value: Array.isArray(parsed.value) ? parsed.value : brief.value,
      });
      saveAll(briefs);
      renderBriefEdit(root, id);
    } catch (e) {
      status.textContent = `エラー: ${e instanceof Error ? e.message : String(e)}`;
      btn.disabled = false;
    }
  });

  renderPaper();
}

function opSection(title: string, body: string, emphasis = false): string {
  if (!body.trim()) return "";
  return `<section class="op-sec${emphasis ? " op-emphasis" : ""}"><h2>${title}</h2><p>${escapeHtml(body).replaceAll("\n", "<br>")}</p></section>`;
}
