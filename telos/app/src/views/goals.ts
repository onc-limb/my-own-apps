import { load, save } from "../storage";
import { escapeHtml, formatDate, uid } from "../util";
import { complete, extractJson, llmEnabled } from "../llm";

interface GoalSession {
  id: string;
  title: string;
  transcript: string;
  candidates: string[];
  keywords: [string, number][];
  selected: string;
  whys: string[];
  situation: string;
  motivation: string;
  outcome: string;
  createdAt: string;
}

const KEY = "telos:goals";
const MAX_WHYS = 5;

// 要望・不満・目的を示す表現。会話ログという実データから出発することで、
// 憶測ベースの 5 Whys の弱点を緩和する（docs/concept.md 参照）
const MARKERS = [
  "たい", // 〜したい・使いたい・避けたい などの願望全般（多少の誤検出より取りこぼしを防ぐ）
  "ほしい",
  "欲しい",
  "べき",
  "必要",
  "困っ",
  "課題",
  "問題",
  "目的",
  "ゴール",
  "期待",
  "不安",
  "できれば",
  "大事",
  "重要",
  "改善",
  "難しい",
  "面倒",
];

const STOPWORDS = new Set([
  "こと",
  "もの",
  "ところ",
  "それ",
  "これ",
  "あれ",
  "ため",
  "よう",
  "とき",
  "場合",
  "自分",
  "今回",
  "感じ",
]);

function loadAll(): GoalSession[] {
  return load<GoalSession[]>(KEY, []);
}

function saveAll(sessions: GoalSession[]): void {
  save(KEY, sessions);
}

export function extractCandidates(text: string): string[] {
  return text
    .split(/\n|。/)
    .map((s) => s.trim())
    .filter((s) => s.length >= 6 && MARKERS.some((m) => s.includes(m)));
}

export function extractKeywords(text: string): [string, number][] {
  // 「田中: 」のような発言者プレフィックスは頻出語として無意味なので除く
  const body = text.replace(/^[^\s:：]{1,12}[:：]\s*/gm, "");
  const words = body.match(/[ァ-ヶー]{3,}|[一-龠々]{2,}|[a-zA-Z][a-zA-Z0-9_-]{2,}/g) ?? [];
  const freq = new Map<string, number>();
  for (const w of words) {
    if (STOPWORDS.has(w)) continue;
    freq.set(w, (freq.get(w) ?? 0) + 1);
  }
  return [...freq.entries()]
    .filter(([, n]) => n >= 2)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);
}

export function renderGoalsList(root: HTMLElement): void {
  const sessions = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Goals</h1>
          <p class="lead">会話の履歴から、本当に叶えたい目的を見つけ出す。</p>
        </div>
        <form id="new-session" class="inline-form">
          <input name="title" type="text" placeholder="例: 6/9 営業部との定例" required />
          <button type="submit" class="primary">新しい分析を開始</button>
        </form>
      </div>
      ${
        sessions.length === 0
          ? `<p class="empty">まだ分析セッションがありません。議事録やチャットログを分析してみましょう。</p>`
          : `<ul class="card-list">${sessions
              .map(
                (s) => `
                <li class="card">
                  <a href="#/goals/${s.id}" class="card-main">
                    <strong>${escapeHtml(s.title)}</strong>
                    <span class="muted">${formatDate(s.createdAt)} ・ ${
                      s.motivation
                        ? `目的: ${escapeHtml(s.motivation)}`
                        : s.selected
                          ? "掘り下げ中"
                          : "分析中"
                    }</span>
                  </a>
                  <button class="ghost danger" data-delete="${s.id}">削除</button>
                </li>`,
              )
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector<HTMLFormElement>("#new-session")!.addEventListener("submit", (e) => {
    e.preventDefault();
    const input = (e.target as HTMLFormElement).elements.namedItem("title") as HTMLInputElement;
    const session: GoalSession = {
      id: uid(),
      title: input.value.trim(),
      transcript: "",
      candidates: [],
      keywords: [],
      selected: "",
      whys: [],
      situation: "",
      motivation: "",
      outcome: "",
      createdAt: new Date().toISOString(),
    };
    saveAll([session, ...loadAll()]);
    location.hash = `#/goals/${session.id}`;
  });

  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("このセッションを削除しますか？")) return;
      saveAll(loadAll().filter((s) => s.id !== btn.dataset.delete));
      renderGoalsList(root);
    }),
  );
}

export function renderGoalsDetail(root: HTMLElement, id: string): void {
  const sessions = loadAll();
  const session = sessions.find((s) => s.id === id);
  if (!session) {
    root.innerHTML = `<div class="page"><p class="empty">セッションが見つかりません。<a href="#/goals">一覧に戻る</a></p></div>`;
    return;
  }

  const persistAndRerender = () => {
    saveAll(sessions);
    renderGoalsDetail(root, id);
  };

  // 次に答えるべき「なぜ」。直前の答えを引用して問いを作る
  const whysDone = session.whys.length >= MAX_WHYS;
  const lastAnswer = session.whys.at(-1) ?? session.selected;

  root.innerHTML = `
    <div class="page">
      <p><a href="#/goals">← 一覧に戻る</a></p>
      <h1>${escapeHtml(session.title)}</h1>

      <section class="step">
        <h2><span class="step-no">1</span> 会話ログを貼り付ける</h2>
        <form id="analyze-form">
          <textarea name="transcript" rows="8" placeholder="議事録・チャットログ・メールのやり取りなどを貼り付けてください">${escapeHtml(session.transcript)}</textarea>
          <div class="row">
            <button type="submit" class="primary">分析する</button>
            <button type="button" id="ai-extract" class="ai-btn" ${llmEnabled() ? "" : "disabled"}>✨ AIで抽出</button>
            <span class="ai-status" id="extract-status"></span>
          </div>
        </form>
        ${
          session.keywords.length > 0
            ? `<p class="muted">頻出キーワード: ${session.keywords
                .map(([w, n]) => `<span class="tag">${escapeHtml(w)} ×${n}</span>`)
                .join(" ")}</p>`
            : ""
        }
      </section>

      ${
        session.transcript && session.candidates.length === 0
          ? `<section class="step"><p class="empty">要望・不満を示す発言が見つかりませんでした。「〜したい」「〜が課題」のような表現を含むログを試してください。</p></section>`
          : ""
      }

      ${
        session.candidates.length > 0
          ? `
      <section class="step">
        <h2><span class="step-no">2</span> 掘り下げる発言を選ぶ</h2>
        <p class="muted">要望・不満・目的を示す発言を抽出しました。一番引っかかるものを選んでください。</p>
        <ul class="candidates">
          ${session.candidates
            .map(
              (c, i) => `
            <li>
              <button class="candidate ${session.selected === c ? "selected" : ""}" data-select="${i}">
                「${escapeHtml(c)}」
              </button>
            </li>`,
            )
            .join("")}
        </ul>
      </section>`
          : ""
      }

      ${
        session.selected
          ? `
      <section class="step">
        <h2><span class="step-no">3</span> なぜ？を繰り返す（${session.whys.length}/${MAX_WHYS}）</h2>
        <p class="muted">出発点: 「${escapeHtml(session.selected)}」</p>
        <ol class="whys">
          ${session.whys
            .map(
              (w, i) => `
            <li>
              <span>${escapeHtml(w)}</span>
              <button class="ghost danger" data-undo-why="${i}" title="ここから掘り直す">×</button>
            </li>`,
            )
            .join("")}
        </ol>
        ${
          whysDone
            ? `<p class="muted">十分に掘り下げました。ステップ4で目的文にまとめましょう。</p>`
            : `
        <form id="why-form">
          <label>なぜ「${escapeHtml(lastAnswer)}」が重要なのですか？
            <input name="answer" type="text" placeholder="なぜなら..." required />
          </label>
          <div class="row">
            <button type="submit" class="primary">答える</button>
            <button type="button" id="ai-why" class="ai-btn" ${llmEnabled() ? "" : "disabled"}>✨ なぜを提案</button>
            ${session.whys.length >= 2 ? `<button type="button" id="enough" class="ghost">もう根本に届いた（ここで止める）</button>` : ""}
            <span class="ai-status" id="why-status"></span>
          </div>
        </form>`
        }
      </section>`
          : ""
      }

      ${
        session.selected && (session.whys.length >= 2 || whysDone)
          ? `
      <section class="step">
        <h2><span class="step-no">4</span> 本当の目的をまとめる（JTBD 形式）</h2>
        <form id="jtbd-form" class="jtbd">
          <label>状況：<input name="situation" value="${escapeHtml(session.situation)}" placeholder="例: 月末に経営層へ報告する" /></label>
          <label>動機：<input name="motivation" value="${escapeHtml(session.motivation)}" placeholder="例: 状況の悪化を早めに共有して判断を仰ぎ" /></label>
          <label>期待する進歩：<input name="outcome" value="${escapeHtml(session.outcome)}" placeholder="例: 手遅れになる前にリソースの再配分ができる" /></label>
          <button type="submit" class="primary">保存</button>
        </form>
        ${
          session.motivation
            ? `<blockquote class="goal-statement">
                <strong>${escapeHtml(session.situation || "（状況）")}</strong>のとき、
                <strong>${escapeHtml(session.motivation)}</strong>たい。
                そうすれば<strong>${escapeHtml(session.outcome || "（期待する進歩）")}</strong>。
              </blockquote>`
            : ""
        }
      </section>`
          : ""
      }
    </div>`;

  root.querySelector<HTMLFormElement>("#analyze-form")!.addEventListener("submit", (e) => {
    e.preventDefault();
    const text = ((e.target as HTMLFormElement).elements.namedItem("transcript") as HTMLTextAreaElement).value;
    session.transcript = text;
    session.candidates = extractCandidates(text);
    session.keywords = extractKeywords(text);
    persistAndRerender();
  });

  root.querySelector("#ai-extract")?.addEventListener("click", async () => {
    const status = root.querySelector<HTMLElement>("#extract-status")!;
    const text = root.querySelector<HTMLTextAreaElement>("[name=transcript]")!.value.trim();
    if (!text) {
      status.textContent = "ログを貼り付けてください";
      return;
    }
    status.textContent = "抽出中…";
    try {
      const out = await complete(
        `次の会話から、参加者の要望・不満・困りごと・目的を表す発言を最大8件、短く言い換えて抽出してください。発言者の地位や雑談は除く。出力は文字列の JSON 配列のみ。\n\n${text}`,
        "あなたは会議の議事から本質的な要望を抜き出すファシリテーターです。",
      );
      const arr = extractJson<string[]>(out);
      if (!arr || arr.length === 0) throw new Error("抽出できませんでした");
      session.transcript = text;
      session.candidates = arr.map(String);
      session.keywords = extractKeywords(text);
      persistAndRerender();
    } catch (e) {
      status.textContent = `エラー: ${e instanceof Error ? e.message : String(e)}`;
    }
  });

  root.querySelector("#ai-why")?.addEventListener("click", async () => {
    const status = root.querySelector<HTMLElement>("#why-status")!;
    const input = root.querySelector<HTMLInputElement>("#why-form [name=answer]")!;
    status.textContent = "考え中…";
    try {
      const chain = [session.selected, ...session.whys].map((w, i) => `${i === 0 ? "出発点" : `why${i}`}: ${w}`).join("\n");
      const out = await complete(
        `次は「本当の目的」を探すための why の連鎖です。次の1段深い「なぜそれが重要か」を、相手の立場で1文だけ提案してください。説明や前置きは不要、本文のみ。\n\n${chain}`,
        "あなたは Jobs to Be Done の考え方で要望の奥にある動機を掘る聞き手です。",
      );
      input.value = out.replace(/^なぜなら/, "").trim();
      status.textContent = "提案を入れました。直して「答える」を押してください";
    } catch (e) {
      status.textContent = `エラー: ${e instanceof Error ? e.message : String(e)}`;
    }
  });

  root.querySelectorAll<HTMLButtonElement>("[data-select]").forEach((btn) =>
    btn.addEventListener("click", () => {
      const next = session.candidates[Number(btn.dataset.select)];
      if (session.selected !== next) {
        session.selected = next;
        session.whys = [];
      }
      persistAndRerender();
    }),
  );

  root.querySelector<HTMLFormElement>("#why-form")?.addEventListener("submit", (e) => {
    e.preventDefault();
    const input = (e.target as HTMLFormElement).elements.namedItem("answer") as HTMLInputElement;
    session.whys.push(input.value.trim());
    persistAndRerender();
  });

  root.querySelector("#enough")?.addEventListener("click", () => {
    document.querySelector("#jtbd-form")?.scrollIntoView({ behavior: "smooth" });
  });

  root.querySelectorAll<HTMLButtonElement>("[data-undo-why]").forEach((btn) =>
    btn.addEventListener("click", () => {
      session.whys = session.whys.slice(0, Number(btn.dataset.undoWhy));
      persistAndRerender();
    }),
  );

  root.querySelector<HTMLFormElement>("#jtbd-form")?.addEventListener("submit", (e) => {
    e.preventDefault();
    const data = new FormData(e.target as HTMLFormElement);
    session.situation = String(data.get("situation") ?? "").trim();
    session.motivation = String(data.get("motivation") ?? "").trim();
    session.outcome = String(data.get("outcome") ?? "").trim();
    persistAndRerender();
  });
}
