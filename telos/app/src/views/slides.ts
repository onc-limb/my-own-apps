import { load, save } from "../storage";
import { escapeHtml, formatDate, toLines, uid } from "../util";

type Status = "on-track" | "at-risk" | "off-track";

interface Report {
  id: string;
  title: string;
  project: string;
  period: string;
  author: string;
  status: Status;
  summary: string;
  achievements: string[];
  issues: string[];
  nextActions: string[];
  createdAt: string;
}

const KEY = "telos:reports";

const STATUS_LABEL: Record<Status, { text: string; cls: string }> = {
  "on-track": { text: "順調", cls: "status-ok" },
  "at-risk": { text: "注意", cls: "status-warn" },
  "off-track": { text: "危険", cls: "status-bad" },
};

function loadAll(): Report[] {
  return load<Report[]>(KEY, []);
}

function saveAll(reports: Report[]): void {
  save(KEY, reports);
}

function blankReport(): Report {
  return {
    id: uid(),
    title: "",
    project: "",
    period: "",
    author: "",
    status: "on-track",
    summary: "",
    achievements: [],
    issues: [],
    nextActions: [],
    createdAt: new Date().toISOString(),
  };
}

function bullets(lines: string[], emptyText: string): string {
  if (lines.length === 0) return `<p class="muted">${emptyText}</p>`;
  return `<ul>${lines.map((l) => `<li>${escapeHtml(l)}</li>`).join("")}</ul>`;
}

// ピラミッド原則（Minto 1987）に従い、結論（サマリー）→ 根拠（成果・課題）→
// アクションの順序をスライド構成として固定する
function buildSlides(r: Report): string[] {
  const st = STATUS_LABEL[r.status];
  return [
    `<div class="slide slide-title">
       <h1>${escapeHtml(r.title || "進捗報告")}</h1>
       <p class="slide-sub">${escapeHtml(r.project)}</p>
       <p class="slide-meta">${escapeHtml(r.period)}${r.author ? " ・ " + escapeHtml(r.author) : ""}</p>
     </div>`,
    `<div class="slide">
       <h2>サマリー</h2>
       <p class="status-badge ${st.cls}">${st.text}</p>
       <p class="slide-summary">${escapeHtml(r.summary) || '<span class="muted">（結論を一文で）</span>'}</p>
     </div>`,
    `<div class="slide">
       <h2>今期の成果</h2>
       ${bullets(r.achievements, "（成果なし）")}
     </div>`,
    `<div class="slide">
       <h2>課題・リスク</h2>
       ${bullets(r.issues, "（課題なし）")}
     </div>`,
    `<div class="slide">
       <h2>次のアクション</h2>
       ${bullets(r.nextActions, "（未定）")}
     </div>`,
  ];
}

export function renderSlidesList(root: HTMLElement): void {
  const reports = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Slides</h1>
          <p class="lead">「起きたこと」を結論ファーストの報告スライドに組み替える。</p>
        </div>
        <button id="new-report" class="primary">新しい報告を作成</button>
      </div>
      ${
        reports.length === 0
          ? `<p class="empty">まだ報告がありません。</p>`
          : `<ul class="card-list">${reports
              .map((r) => {
                const st = STATUS_LABEL[r.status];
                return `
                <li class="card">
                  <a href="#/slides/${r.id}" class="card-main">
                    <strong>${escapeHtml(r.title || "（無題）")}</strong>
                    <span class="muted">${escapeHtml(r.project)} ・ ${escapeHtml(r.period)} ・ ${formatDate(r.createdAt)}</span>
                  </a>
                  <span class="status-badge small ${st.cls}">${st.text}</span>
                  <button class="ghost" data-duplicate="${r.id}">複製</button>
                  <button class="ghost danger" data-delete="${r.id}">削除</button>
                </li>`;
              })
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector("#new-report")!.addEventListener("click", () => {
    const r = blankReport();
    saveAll([r, ...loadAll()]);
    location.hash = `#/slides/${r.id}`;
  });

  root.querySelectorAll<HTMLButtonElement>("[data-duplicate]").forEach((btn) =>
    btn.addEventListener("click", () => {
      const all = loadAll();
      const src = all.find((r) => r.id === btn.dataset.duplicate);
      if (!src) return;
      const copy: Report = {
        ...src,
        id: uid(),
        title: `${src.title}（コピー）`,
        createdAt: new Date().toISOString(),
      };
      saveAll([copy, ...all]);
      location.hash = `#/slides/${copy.id}`;
    }),
  );

  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("この報告を削除しますか？")) return;
      saveAll(loadAll().filter((r) => r.id !== btn.dataset.delete));
      renderSlidesList(root);
    }),
  );
}

export function renderSlidesEdit(root: HTMLElement, id: string): void {
  const reports = loadAll();
  const report = reports.find((r) => r.id === id);
  if (!report) {
    root.innerHTML = `<div class="page"><p class="empty">報告が見つかりません。<a href="#/slides">一覧に戻る</a></p></div>`;
    return;
  }

  root.innerHTML = `
    <div class="page wide">
      <p class="no-print"><a href="#/slides">← 一覧に戻る</a></p>
      <div class="split">
        <form id="report-form" class="report-form no-print">
          <h2>報告の内容</h2>
          <label>タイトル<input name="title" value="${escapeHtml(report.title)}" placeholder="例: 6月度 進捗報告" /></label>
          <label>プロジェクト名<input name="project" value="${escapeHtml(report.project)}" placeholder="例: 顧客ポータル刷新" /></label>
          <label>対象期間<input name="period" value="${escapeHtml(report.period)}" placeholder="例: 2026/6/1 – 6/30" /></label>
          <label>報告者<input name="author" value="${escapeHtml(report.author)}" /></label>
          <label>状況
            <select name="status">
              ${(Object.keys(STATUS_LABEL) as Status[])
                .map(
                  (s) =>
                    `<option value="${s}" ${report.status === s ? "selected" : ""}>${STATUS_LABEL[s].text}</option>`,
                )
                .join("")}
            </select>
          </label>
          <label>サマリー（結論を一文で。聞き手が最初に知るべきこと）
            <textarea name="summary" rows="3">${escapeHtml(report.summary)}</textarea>
          </label>
          <label>今期の成果（1行 = 1項目）
            <textarea name="achievements" rows="4">${escapeHtml(report.achievements.join("\n"))}</textarea>
          </label>
          <label>課題・リスク（1行 = 1項目）
            <textarea name="issues" rows="4">${escapeHtml(report.issues.join("\n"))}</textarea>
          </label>
          <label>次のアクション（1行 = 1項目）
            <textarea name="nextActions" rows="4">${escapeHtml(report.nextActions.join("\n"))}</textarea>
          </label>
        </form>
        <div class="preview-pane">
          <div class="preview-toolbar no-print">
            <button id="prev" class="ghost">←</button>
            <span id="slide-pos"></span>
            <button id="next" class="ghost">→</button>
            <span class="spacer"></span>
            <button id="print" class="primary">印刷 / PDF 出力</button>
          </div>
          <div id="deck" class="deck"></div>
        </div>
      </div>
    </div>`;

  const deck = root.querySelector<HTMLElement>("#deck")!;
  const pos = root.querySelector<HTMLElement>("#slide-pos")!;
  let current = 0;

  const renderDeck = () => {
    const slides = buildSlides(report);
    if (current >= slides.length) current = slides.length - 1;
    deck.innerHTML = slides
      .map((s, i) => s.replace('class="slide', `data-index="${i}" class="slide ${i === current ? "active" : ""}`))
      .join("");
    pos.textContent = `${current + 1} / ${slides.length}`;
  };

  const form = root.querySelector<HTMLFormElement>("#report-form")!;
  form.addEventListener("input", () => {
    const data = new FormData(form);
    report.title = String(data.get("title") ?? "");
    report.project = String(data.get("project") ?? "");
    report.period = String(data.get("period") ?? "");
    report.author = String(data.get("author") ?? "");
    report.status = String(data.get("status")) as Status;
    report.summary = String(data.get("summary") ?? "");
    report.achievements = toLines(String(data.get("achievements") ?? ""));
    report.issues = toLines(String(data.get("issues") ?? ""));
    report.nextActions = toLines(String(data.get("nextActions") ?? ""));
    saveAll(reports);
    renderDeck();
  });

  root.querySelector("#prev")!.addEventListener("click", () => {
    current = Math.max(0, current - 1);
    renderDeck();
  });
  root.querySelector("#next")!.addEventListener("click", () => {
    current = Math.min(buildSlides(report).length - 1, current + 1);
    renderDeck();
  });
  root.querySelector("#print")!.addEventListener("click", () => window.print());

  renderDeck();
}
