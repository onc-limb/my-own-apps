import { load, save } from "../storage";
import { escapeHtml, formatDate, toLines, uid } from "../util";
import { complete, extractJson, llmEnabled } from "../llm";

interface Positioning {
  id: string;
  title: string;
  strengths: string; // 材料（できること・得意・実績メモ）
  target: string; // 誰の
  job: string; // どんな進歩を
  approach: string; // どう実現するか（差別化）
  proof: string[]; // 根拠・実績
  oneLiner: string; // 価値の一文（手動 or AI）
  createdAt: string;
}

const KEY = "telos:positionings";

function loadAll(): Positioning[] {
  return load<Positioning[]>(KEY, []);
}
function saveAll(items: Positioning[]): void {
  save(KEY, items);
}

function blank(): Positioning {
  return {
    id: uid(),
    title: "",
    strengths: "",
    target: "",
    job: "",
    approach: "",
    proof: [],
    oneLiner: "",
    createdAt: new Date().toISOString(),
  };
}

// 一文が未入力なら 3 要素から自動で組み立てる（JTBD: 誰の・どんな進歩・どう）
function composedOneLiner(p: Positioning): string {
  if (p.oneLiner.trim()) return p.oneLiner.trim();
  if (!p.target && !p.job && !p.approach) return "";
  const target = p.target || "（誰）";
  const job = p.job || "（どんな進歩）";
  const approach = p.approach || "（どう）";
  return `${target}が${job}できるよう、${approach}で支援します。`;
}

export function renderPositioningList(root: HTMLElement): void {
  const items = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Positioning</h1>
          <p class="lead">「何屋さんですか?」に一文で答えられる状態をつくる。</p>
        </div>
        <button id="new-pos" class="primary">新しいポジショニング</button>
      </div>
      ${
        items.length === 0
          ? `<p class="empty">まだありません。自分の強みを棚卸しして、価値を一文に絞りましょう。</p>`
          : `<ul class="card-list">${items
              .map(
                (p) => `
              <li class="card">
                <a href="#/positioning/${p.id}" class="card-main">
                  <strong>${escapeHtml(p.title || "（無題）")}</strong>
                  <span class="muted">${escapeHtml(composedOneLiner(p)) || "未設定"} ・ ${formatDate(p.createdAt)}</span>
                </a>
                <button class="ghost danger" data-delete="${p.id}">削除</button>
              </li>`,
              )
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector("#new-pos")!.addEventListener("click", () => {
    const p = blank();
    saveAll([p, ...loadAll()]);
    location.hash = `#/positioning/${p.id}`;
  });

  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("削除しますか？")) return;
      saveAll(loadAll().filter((p) => p.id !== btn.dataset.delete));
      renderPositioningList(root);
    }),
  );
}

export function renderPositioningEdit(root: HTMLElement, id: string): void {
  const items = loadAll();
  const p = items.find((x) => x.id === id);
  if (!p) {
    root.innerHTML = `<div class="page"><p class="empty">見つかりません。<a href="#/positioning">一覧に戻る</a></p></div>`;
    return;
  }

  root.innerHTML = `
    <div class="page wide">
      <p class="no-print"><a href="#/positioning">← 一覧に戻る</a></p>
      <div class="split">
        <form id="pos-form" class="report-form no-print">
          <h2>価値の棚卸し</h2>
          <label>タイトル<input name="title" value="${escapeHtml(p.title)}" placeholder="例: バックエンド × 業務改善" /></label>

          <div class="ai-box">
            <label>強み・できること・実績（箇条書きメモでOK）
              <textarea name="strengths" rows="5" placeholder="例: 受発注システムの内製化を3社で支援 / Go・TypeScript / 非エンジニアとの要件整理が得意 …">${escapeHtml(p.strengths)}</textarea>
            </label>
            <button type="button" id="ai-draft" class="ai-btn" ${llmEnabled() ? "" : "disabled"}>✨ AIで価値を言語化</button>
            ${llmEnabled() ? `<span class="ai-status" id="ai-status"></span>` : `<span class="field-hint">Settings で LLM 連携を ON にすると使えます</span>`}
          </div>

          <label>誰の役に立つか（ターゲット）<input name="target" value="${escapeHtml(p.target)}" placeholder="例: 業務が属人化している中小企業" /></label>
          <label>どんな進歩を届けるか（提供価値）<input name="job" value="${escapeHtml(p.job)}" placeholder="例: 現場の手作業をなくして本業に集中" /></label>
          <label>どう実現するか（差別化）<input name="approach" value="${escapeHtml(p.approach)}" placeholder="例: 業務に入り込んで要件から一緒に作る" /></label>
          <label>実績・根拠（1行 = 1項目）
            <textarea name="proof" rows="4">${escapeHtml(p.proof.join("\n"))}</textarea>
          </label>
          <label>価値の一文（空なら上の3要素から自動生成）
            <textarea name="oneLiner" rows="2" placeholder="例: 属人化に悩む中小企業が本業に集中できるよう、業務に入り込んで仕組みを内製化します。">${escapeHtml(p.oneLiner)}</textarea>
          </label>
        </form>

        <div class="preview-pane">
          <div class="preview-toolbar no-print">
            <span class="muted">プロフィール・営業文・提案の冒頭に使えます</span>
            <span class="spacer"></span>
            <button id="print" class="primary">印刷 / PDF</button>
          </div>
          <div id="paper" class="paper"></div>
        </div>
      </div>
    </div>`;

  const paper = root.querySelector<HTMLElement>("#paper")!;
  const renderPaper = () => {
    const one = composedOneLiner(p);
    paper.innerHTML = `
      <article class="valuecard">
        <p class="vc-kicker">VALUE STATEMENT</p>
        <p class="vc-oneliner">${escapeHtml(one) || '<span class="op-placeholder">価値の一文がここに表示されます</span>'}</p>
        <dl class="vc-grid">
          <div><dt>誰の役に立つか</dt><dd>${escapeHtml(p.target) || "—"}</dd></div>
          <div><dt>どんな進歩を届けるか</dt><dd>${escapeHtml(p.job) || "—"}</dd></div>
          <div><dt>どう違うか</dt><dd>${escapeHtml(p.approach) || "—"}</dd></div>
        </dl>
        ${
          p.proof.length
            ? `<section class="vc-proof"><h2>実績・根拠</h2><ul>${p.proof.map((v) => `<li>${escapeHtml(v)}</li>`).join("")}</ul></section>`
            : ""
        }
      </article>`;
  };

  const form = root.querySelector<HTMLFormElement>("#pos-form")!;
  form.addEventListener("input", () => {
    const d = new FormData(form);
    p.title = String(d.get("title") ?? "");
    p.strengths = String(d.get("strengths") ?? "");
    p.target = String(d.get("target") ?? "");
    p.job = String(d.get("job") ?? "");
    p.approach = String(d.get("approach") ?? "");
    p.proof = toLines(String(d.get("proof") ?? ""));
    p.oneLiner = String(d.get("oneLiner") ?? "");
    saveAll(items);
    renderPaper();
  });

  root.querySelector("#print")!.addEventListener("click", () => window.print());

  root.querySelector("#ai-draft")?.addEventListener("click", async () => {
    const status = root.querySelector<HTMLElement>("#ai-status")!;
    const btn = root.querySelector<HTMLButtonElement>("#ai-draft")!;
    const strengths = p.strengths.trim();
    if (!strengths) {
      status.textContent = "強み・実績メモを入力してください";
      return;
    }
    btn.disabled = true;
    status.textContent = "言語化中…";
    try {
      const system =
        "あなたはフリーランス人材のブランディングを支援するキャリアエージェントです。Jobs to Be Done の考え方で、顧客が得る進歩を主語に価値を言語化します。誇張せず、本人のメモにある事実だけを根拠にします。";
      const prompt = `次の強み・実績メモから、フリーランスエンジニアのポジショニングを言語化してください。出力は次のキーの JSON のみ:
{"target":string,"job":string,"approach":string,"oneLiner":string,"proof":string[]}
- target=誰の役に立つか、job=どんな進歩を届けるか、approach=どう違うか。各20〜35字程度。
- oneLiner=営業の冒頭に使える価値の一文（60字以内）。
- proof=メモから抜き出した実績の短い箇条書き（最大4件）。メモにない実績を創作しない。

メモ:
${strengths}`;
      const text = await complete(prompt, system);
      const parsed = extractJson<Partial<Positioning>>(text);
      if (!parsed) throw new Error("AI の出力を解釈できませんでした");
      Object.assign(p, {
        target: parsed.target ?? p.target,
        job: parsed.job ?? p.job,
        approach: parsed.approach ?? p.approach,
        oneLiner: parsed.oneLiner ?? p.oneLiner,
        proof: Array.isArray(parsed.proof) ? parsed.proof : p.proof,
      });
      saveAll(items);
      renderPositioningEdit(root, id);
    } catch (e) {
      status.textContent = `エラー: ${e instanceof Error ? e.message : String(e)}`;
      btn.disabled = false;
    }
  });

  renderPaper();
}
