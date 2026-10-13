import { load, save } from "../storage";
import { escapeHtml, formatDate, toLines, uid } from "../util";
import { complete, extractJson, llmEnabled } from "../llm";

interface Proposal {
  id: string;
  title: string;
  client: string;
  brief: string; // 案件の概要メモ（AI の材料）
  understanding: string; // 課題理解
  approach: string; // アプローチ
  plan: string[]; // 進め方・フェーズ
  estimate: string; // 概算
  whyMe: string; // なぜ自分か
  createdAt: string;
}

const KEY = "telos:proposals";

function loadAll(): Proposal[] {
  return load<Proposal[]>(KEY, []);
}
function saveAll(items: Proposal[]): void {
  save(KEY, items);
}

function blank(): Proposal {
  return {
    id: uid(),
    title: "",
    client: "",
    brief: "",
    understanding: "",
    approach: "",
    plan: [],
    estimate: "",
    whyMe: "",
    createdAt: new Date().toISOString(),
  };
}

export function renderProposalList(root: HTMLElement): void {
  const items = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Proposal</h1>
          <p class="lead">ふわっとした相談を、受注につながる提案書に。「なぜ自分か」で差をつける。</p>
        </div>
        <button id="new-prop" class="primary">新しい提案書</button>
      </div>
      ${
        items.length === 0
          ? `<p class="empty">まだ提案書がありません。Goals で掘った目的を冒頭に置くと刺さります。</p>`
          : `<ul class="card-list">${items
              .map(
                (p) => `
              <li class="card">
                <a href="#/proposal/${p.id}" class="card-main">
                  <strong>${escapeHtml(p.title || "（無題）")}</strong>
                  <span class="muted">${escapeHtml(p.client) || "クライアント未設定"} ・ ${formatDate(p.createdAt)}</span>
                </a>
                <button class="ghost danger" data-delete="${p.id}">削除</button>
              </li>`,
              )
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector("#new-prop")!.addEventListener("click", () => {
    const p = blank();
    saveAll([p, ...loadAll()]);
    location.hash = `#/proposal/${p.id}`;
  });
  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("削除しますか？")) return;
      saveAll(loadAll().filter((p) => p.id !== btn.dataset.delete));
      renderProposalList(root);
    }),
  );
}

export function renderProposalEdit(root: HTMLElement, id: string): void {
  const all = loadAll();
  const p = all.find((x) => x.id === id);
  if (!p) {
    root.innerHTML = `<div class="page"><p class="empty">見つかりません。<a href="#/proposal">一覧に戻る</a></p></div>`;
    return;
  }

  root.innerHTML = `
    <div class="page wide">
      <p class="no-print"><a href="#/proposal">← 一覧に戻る</a></p>
      <div class="split">
        <form id="prop-form" class="report-form no-print">
          <h2>提案書</h2>
          <label>タイトル<input name="title" value="${escapeHtml(p.title)}" placeholder="例: 受発注業務の内製化のご提案" /></label>
          <label>クライアント<input name="client" value="${escapeHtml(p.client)}" /></label>

          <div class="ai-box">
            <label>案件メモ（相談内容・背景）
              <textarea name="brief" rows="4" placeholder="ヒアリングした内容を貼ってください。AI が各セクションの下書きを作ります。">${escapeHtml(p.brief)}</textarea>
            </label>
            <button type="button" id="ai-draft" class="ai-btn" ${llmEnabled() ? "" : "disabled"}>✨ AIで提案書を下書き</button>
            ${llmEnabled() ? `<span class="ai-status" id="ai-status"></span>` : `<span class="field-hint">Settings で LLM 連携を ON にすると使えます</span>`}
          </div>

          <label>課題理解<span class="field-hint">相手の課題を自分の言葉で</span>
            <textarea name="understanding" rows="3">${escapeHtml(p.understanding)}</textarea>
          </label>
          <label>アプローチ<span class="field-hint">どう解決するか</span>
            <textarea name="approach" rows="3">${escapeHtml(p.approach)}</textarea>
          </label>
          <label>進め方・フェーズ（1行 = 1項目）
            <textarea name="plan" rows="4">${escapeHtml(p.plan.join("\n"))}</textarea>
          </label>
          <label>概算<span class="field-hint">期間・費用の目安（Estimate からの転記も可）</span>
            <textarea name="estimate" rows="2">${escapeHtml(p.estimate)}</textarea>
          </label>
          <label>なぜ自分か<span class="field-hint">Positioning の価値をここに</span>
            <textarea name="whyMe" rows="3">${escapeHtml(p.whyMe)}</textarea>
          </label>
        </form>

        <div class="preview-pane">
          <div class="preview-toolbar no-print">
            <span class="muted">クライアントに渡せる提案書</span>
            <span class="spacer"></span>
            <button id="print" class="primary">印刷 / PDF</button>
          </div>
          <div id="paper" class="paper"></div>
        </div>
      </div>
    </div>`;

  const paper = root.querySelector<HTMLElement>("#paper")!;
  const sec = (title: string, body: string) =>
    body.trim() ? `<section class="op-sec"><h2>${title}</h2><p>${escapeHtml(body).replaceAll("\n", "<br>")}</p></section>` : "";
  const renderPaper = () => {
    paper.innerHTML = `
      <article class="onepager">
        <header class="op-head">
          <h1>${escapeHtml(p.title) || '<span class="op-placeholder">提案タイトル</span>'}</h1>
          ${p.client ? `<p class="op-audience">${escapeHtml(p.client)} 御中</p>` : ""}
        </header>
        ${sec("課題理解", p.understanding)}
        ${sec("アプローチ", p.approach)}
        ${p.plan.length ? `<section class="op-sec"><h2>進め方</h2><ol class="op-steps">${p.plan.map((s) => `<li>${escapeHtml(s)}</li>`).join("")}</ol></section>` : ""}
        ${sec("概算", p.estimate)}
        ${p.whyMe.trim() ? `<section class="op-sec op-ask"><h2>なぜ私か</h2><p>${escapeHtml(p.whyMe).replaceAll("\n", "<br>")}</p></section>` : ""}
      </article>`;
  };

  const form = root.querySelector<HTMLFormElement>("#prop-form")!;
  form.addEventListener("input", () => {
    const d = new FormData(form);
    p.title = String(d.get("title") ?? "");
    p.client = String(d.get("client") ?? "");
    p.brief = String(d.get("brief") ?? "");
    p.understanding = String(d.get("understanding") ?? "");
    p.approach = String(d.get("approach") ?? "");
    p.plan = toLines(String(d.get("plan") ?? ""));
    p.estimate = String(d.get("estimate") ?? "");
    p.whyMe = String(d.get("whyMe") ?? "");
    saveAll(all);
    renderPaper();
  });
  root.querySelector("#print")!.addEventListener("click", () => window.print());

  root.querySelector("#ai-draft")?.addEventListener("click", async () => {
    const status = root.querySelector<HTMLElement>("#ai-status")!;
    const btn = root.querySelector<HTMLButtonElement>("#ai-draft")!;
    const brief = (root.querySelector<HTMLTextAreaElement>("[name=brief]")!.value || "").trim();
    p.brief = brief;
    if (!brief) {
      status.textContent = "案件メモを入力してください";
      return;
    }
    btn.disabled = true;
    status.textContent = "下書き中…";
    try {
      const system =
        "あなたは受注率の高いフリーランスエンジニアの提案書づくりを支援します。相手の課題を自分の言葉で捉え直し、押し付けず、相手の事業メリットを起点に書きます。事実にない実績を創作しません。";
      const prompt = `次の案件メモから提案書の下書きを作ってください。出力は次のキーの JSON のみ:
{"title":string,"understanding":string,"approach":string,"plan":string[],"estimate":string,"whyMe":string}
- understanding=相手の課題理解（2〜3文）。approach=解決アプローチ（2〜3文）。
- plan=進め方のフェーズ（3〜5ステップの短い箇条書き）。
- estimate=期間・費用の目安（メモに情報がなければ「要ヒアリング」と書く。数値を創作しない）。
- whyMe=なぜ自分が適任か（2文程度。メモにある強みベース。なければ一般的な姿勢で）。

案件メモ:
${brief}`;
      const text = await complete(prompt, system);
      const parsed = extractJson<Partial<Proposal>>(text);
      if (!parsed) throw new Error("AI の出力を解釈できませんでした");
      Object.assign(p, {
        title: parsed.title ?? p.title,
        understanding: parsed.understanding ?? p.understanding,
        approach: parsed.approach ?? p.approach,
        plan: Array.isArray(parsed.plan) ? parsed.plan : p.plan,
        estimate: parsed.estimate ?? p.estimate,
        whyMe: parsed.whyMe ?? p.whyMe,
      });
      saveAll(all);
      renderProposalEdit(root, id);
    } catch (err) {
      status.textContent = `エラー: ${err instanceof Error ? err.message : String(err)}`;
      btn.disabled = false;
    }
  });

  renderPaper();
}
