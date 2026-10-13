interface Tool {
  href: string;
  name: string;
  desc: string;
}

const PHASES: { kicker: string; title: string; tools: Tool[] }[] = [
  {
    kicker: "01 / win",
    title: "入口を勝つ",
    tools: [
      { href: "#/positioning", name: "Positioning", desc: "強みを棚卸しし、提供価値を一文に言語化する。" },
      { href: "#/proposal", name: "Proposal", desc: "ふわっとした相談を受注につながる提案書に。" },
      { href: "#/estimate", name: "Estimate", desc: "曖昧な依頼を前提・含むこと・含まないことに分けて見積る。" },
    ],
  },
  {
    kicker: "02 / run",
    title: "案件を進める",
    tools: [
      { href: "#/goals", name: "Goals", desc: "会話から本当に叶えたい目的を見つけ出す。" },
      { href: "#/decisions", name: "Decisions", desc: "議事から決定・未決・宿題を抜き出し、認識を揃える。" },
      { href: "#/changes", name: "Changes", desc: "スコープ外の追加依頼を、影響つきの見える変更に。" },
      { href: "#/checklist", name: "Checklist", desc: "リリースの「やるべきこと」を記憶の外に出す。" },
    ],
  },
  {
    kicker: "03 / report",
    title: "報告・説明する",
    tools: [
      { href: "#/slides", name: "Slides", desc: "進捗を結論ファーストの報告スライドに。" },
      { href: "#/brief", name: "Brief", desc: "ビジネス側に説明するための一枚資料に。" },
    ],
  },
  {
    kicker: "04 / continue",
    title: "次につなげる",
    tools: [{ href: "#/retro", name: "Retrospective", desc: "振り返りを次フェーズの継続提案に変える。" }],
  },
];

export function renderHome(root: HTMLElement): void {
  root.innerHTML = `
    <div class="page">
      <div class="hero">
        <p class="hero-kicker">τέλος — purpose-driven workspace</p>
        <h1>telos</h1>
        <p class="lead">情報を「記録」で終わらせず、目的に向かう道具に変える。案件の入口から継続まで。</p>
      </div>
      ${PHASES.map(
        (ph) => `
        <section class="phase">
          <div class="phase-head">
            <span class="phase-kicker">${ph.kicker}</span>
            <h2>${ph.title}</h2>
          </div>
          <div class="tool-grid">
            ${ph.tools
              .map(
                (t) => `
              <a class="tool" href="${t.href}">
                <h2>${t.name}</h2>
                <p>${t.desc}</p>
              </a>`,
              )
              .join("")}
          </div>
        </section>`,
      ).join("")}
      <p class="home-foot muted">AI 支援（任意）と端末間のデータ移行は <a href="#/settings">Settings</a> から。</p>
    </div>`;
}
