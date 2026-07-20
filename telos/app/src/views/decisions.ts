import { load, save } from "../storage";
import { escapeHtml, toLines, uid } from "../util";
import { complete, extractJson, llmEnabled } from "../llm";

interface Action {
  text: string;
  owner: string;
}

interface DecisionLog {
  id: string;
  title: string;
  date: string;
  transcript: string;
  decisions: string[];
  openQuestions: string[];
  actions: Action[];
  createdAt: string;
}

const KEY = "telos:decisions";

// 決定／未決／アクションを示す表現（ヒューリスティック抽出のマーカー）
const DECISION_MARKERS = ["決定", "決まり", "で行く", "で進め", "承認", "確定", "合意", "採用", "ことにする", "ことになった"];
const ACTION_MARKERS = ["までに", "対応する", "やる", "進める", "作成する", "用意する", "確認する", "共有する", "担当"];
const QUESTION_MARKERS = ["未定", "持ち帰", "要確認", "検討", "保留", "どうする", "未決", "確認したい", "次回"];

function loadAll(): DecisionLog[] {
  return load<DecisionLog[]>(KEY, []);
}
function saveAll(items: DecisionLog[]): void {
  save(KEY, items);
}

function blank(): DecisionLog {
  return {
    id: uid(),
    title: "",
    date: new Date().toISOString().slice(0, 10),
    transcript: "",
    decisions: [],
    openQuestions: [],
    actions: [],
    createdAt: new Date().toISOString(),
  };
}

// 発言者プレフィックスを落として本文だけにする
function strip(line: string): string {
  return line.replace(/^[^\s:：]{1,12}[:：]\s*/, "").trim();
}

function heuristicExtract(text: string): Pick<DecisionLog, "decisions" | "openQuestions" | "actions"> {
  const lines = text
    .split(/\n|。/)
    .map((s) => s.trim())
    .filter((s) => s.length >= 4);
  const decisions: string[] = [];
  const openQuestions: string[] = [];
  const actions: Action[] = [];
  for (const raw of lines) {
    const body = strip(raw);
    if (DECISION_MARKERS.some((m) => body.includes(m))) decisions.push(body);
    else if (QUESTION_MARKERS.some((m) => body.includes(m)) || raw.includes("?") || raw.includes("？")) openQuestions.push(body);
    else if (ACTION_MARKERS.some((m) => body.includes(m))) actions.push({ text: body, owner: "" });
  }
  return { decisions, openQuestions, actions };
}

export function renderDecisionsList(root: HTMLElement): void {
  const items = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Decisions</h1>
          <p class="lead">議事から決定・未決・宿題を抜き出す。「言った言わない」を防ぎ、信頼を積む。</p>
        </div>
        <form id="new-dec" class="inline-form">
          <input name="title" type="text" placeholder="例: 6/10 キックオフ" required />
          <button type="submit" class="primary">新しい議事録</button>
        </form>
      </div>
      ${
        items.length === 0
          ? `<p class="empty">まだありません。打ち合わせログを貼って決定事項を残しましょう。</p>`
          : `<ul class="card-list">${items
              .map(
                (d) => `
              <li class="card">
                <a href="#/decisions/${d.id}" class="card-main">
                  <strong>${escapeHtml(d.title || "（無題）")}</strong>
                  <span class="muted">${escapeHtml(d.date)} ・ 決定 ${d.decisions.length} / 未決 ${d.openQuestions.length} / アクション ${d.actions.length}</span>
                </a>
                <button class="ghost danger" data-delete="${d.id}">削除</button>
              </li>`,
              )
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector<HTMLFormElement>("#new-dec")!.addEventListener("submit", (ev) => {
    ev.preventDefault();
    const input = (ev.target as HTMLFormElement).elements.namedItem("title") as HTMLInputElement;
    const d = blank();
    d.title = input.value.trim();
    saveAll([d, ...loadAll()]);
    location.hash = `#/decisions/${d.id}`;
  });
  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("削除しますか？")) return;
      saveAll(loadAll().filter((d) => d.id !== btn.dataset.delete));
      renderDecisionsList(root);
    }),
  );
}

export function renderDecisionsEdit(root: HTMLElement, id: string): void {
  const all = loadAll();
  const d = all.find((x) => x.id === id);
  if (!d) {
    root.innerHTML = `<div class="page"><p class="empty">見つかりません。<a href="#/decisions">一覧に戻る</a></p></div>`;
    return;
  }

  root.innerHTML = `
    <div class="page wide">
      <p class="no-print"><a href="#/decisions">← 一覧に戻る</a></p>
      <div class="split">
        <form id="dec-form" class="report-form no-print">
          <h2>議事録</h2>
          <label>タイトル<input name="title" value="${escapeHtml(d.title)}" /></label>
          <label>日付<input name="date" type="date" value="${escapeHtml(d.date)}" /></label>
          <label>打ち合わせログ
            <textarea name="transcript" rows="8" placeholder="議事メモ・チャット・文字起こしを貼ってください">${escapeHtml(d.transcript)}</textarea>
          </label>
          <div class="row">
            <button type="button" id="extract" class="primary">抽出する</button>
            <button type="button" id="ai-extract" class="ai-btn" ${llmEnabled() ? "" : "disabled"}>✨ AIで抽出</button>
            <span class="ai-status" id="ai-status"></span>
          </div>

          <label class="mt">決定事項（1行 = 1項目）
            <textarea name="decisions" rows="4">${escapeHtml(d.decisions.join("\n"))}</textarea>
          </label>
          <label>未決・確認事項（1行 = 1項目）
            <textarea name="openQuestions" rows="4">${escapeHtml(d.openQuestions.join("\n"))}</textarea>
          </label>
          <label>アクション（「担当: 内容」または「内容」・1行 = 1項目）
            <textarea name="actions" rows="4">${escapeHtml(d.actions.map((a) => (a.owner ? `${a.owner}: ${a.text}` : a.text)).join("\n"))}</textarea>
          </label>
        </form>

        <div class="preview-pane">
          <div class="preview-toolbar no-print">
            <span class="muted">関係者に共有する議事録</span>
            <span class="spacer"></span>
            <button id="print" class="primary">印刷 / PDF</button>
          </div>
          <div id="paper" class="paper"></div>
        </div>
      </div>
    </div>`;

  const paper = root.querySelector<HTMLElement>("#paper")!;
  const renderPaper = () => {
    const ul = (xs: string[]) => `<ul>${xs.map((x) => `<li>${escapeHtml(x)}</li>`).join("")}</ul>`;
    paper.innerHTML = `
      <article class="onepager">
        <header class="op-head">
          <h1>${escapeHtml(d.title) || '<span class="op-placeholder">議事録</span>'}</h1>
          <p class="op-audience">${escapeHtml(d.date)}</p>
        </header>
        ${d.decisions.length ? `<section class="op-sec"><h2>決定事項</h2>${ul(d.decisions)}</section>` : ""}
        ${
          d.actions.length
            ? `<section class="op-sec"><h2>アクション</h2><ul>${d.actions
                .map((a) => `<li>${a.owner ? `<strong>${escapeHtml(a.owner)}</strong>: ` : ""}${escapeHtml(a.text)}</li>`)
                .join("")}</ul></section>`
            : ""
        }
        ${d.openQuestions.length ? `<section class="op-sec op-ask"><h2>未決・確認事項</h2>${ul(d.openQuestions)}</section>` : ""}
      </article>`;
  };

  const form = root.querySelector<HTMLFormElement>("#dec-form")!;
  const parseActions = (raw: string): Action[] =>
    toLines(raw).map((l) => {
      const m = l.match(/^([^\s:：]{1,16})[:：]\s*(.+)$/);
      return m ? { owner: m[1], text: m[2] } : { owner: "", text: l };
    });
  const sync = () => {
    const fd = new FormData(form);
    d.title = String(fd.get("title") ?? "");
    d.date = String(fd.get("date") ?? "");
    d.transcript = String(fd.get("transcript") ?? "");
    d.decisions = toLines(String(fd.get("decisions") ?? ""));
    d.openQuestions = toLines(String(fd.get("openQuestions") ?? ""));
    d.actions = parseActions(String(fd.get("actions") ?? ""));
    saveAll(all);
  };
  form.addEventListener("input", () => {
    sync();
    renderPaper();
  });

  root.querySelector("#extract")!.addEventListener("click", () => {
    sync();
    if (!d.transcript.trim()) return;
    const ex = heuristicExtract(d.transcript);
    d.decisions = ex.decisions;
    d.openQuestions = ex.openQuestions;
    d.actions = ex.actions;
    saveAll(all);
    renderDecisionsEdit(root, id);
  });

  root.querySelector("#print")!.addEventListener("click", () => window.print());

  root.querySelector("#ai-extract")?.addEventListener("click", async () => {
    sync();
    const status = root.querySelector<HTMLElement>("#ai-status")!;
    const btn = root.querySelector<HTMLButtonElement>("#ai-extract")!;
    if (!d.transcript.trim()) {
      status.textContent = "ログを貼り付けてください";
      return;
    }
    btn.disabled = true;
    status.textContent = "抽出中…";
    try {
      const system = "あなたは議事録を整理するプロのアシスタントです。発言から、確定した決定・未決の論点・誰が何をやるかを正確に切り分けます。ログにないことを創作しません。";
      const prompt = `次の打ち合わせログから、決定事項・未決事項・アクションを抽出してください。出力は次のキーの JSON のみ:
{"decisions":string[],"openQuestions":string[],"actions":[{"owner":string,"text":string}]}
- decisions=その場で確定したこと。
- openQuestions=未決・持ち帰り・要確認の論点。
- actions=誰が(owner)何を(text)するか。担当が不明なら owner は空文字。

ログ:
${d.transcript}`;
      const text = await complete(prompt, system);
      const parsed = extractJson<{ decisions?: string[]; openQuestions?: string[]; actions?: Action[] }>(text);
      if (!parsed) throw new Error("AI の出力を解釈できませんでした");
      d.decisions = Array.isArray(parsed.decisions) ? parsed.decisions : d.decisions;
      d.openQuestions = Array.isArray(parsed.openQuestions) ? parsed.openQuestions : d.openQuestions;
      d.actions = Array.isArray(parsed.actions) ? parsed.actions.map((a) => ({ owner: String(a.owner ?? ""), text: String(a.text ?? "") })) : d.actions;
      saveAll(all);
      renderDecisionsEdit(root, id);
    } catch (err) {
      status.textContent = `エラー: ${err instanceof Error ? err.message : String(err)}`;
      btn.disabled = false;
    }
  });

  renderPaper();
}
