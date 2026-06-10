export function renderHome(root: HTMLElement): void {
  root.innerHTML = `
    <div class="page">
      <div class="hero">
        <p class="hero-kicker">τέλος — purpose-driven workspace</p>
        <h1>telos</h1>
        <p class="lead">情報を「記録」で終わらせず、目的に向かう道具に変える。</p>
      </div>
      <div class="tool-grid">
        <a class="tool" href="#/checklist">
          <span class="tool-tag">01 / ship</span>
          <h2>Checklist</h2>
          <p>新規ソフトウェアリリースの「やるべきこと」を記憶の外に出す。テンプレートから作成し、リリース判定の状態を一目で。</p>
        </a>
        <a class="tool" href="#/slides">
          <span class="tool-tag">02 / report</span>
          <h2>Slides</h2>
          <p>進捗を結論ファーストの報告スライドに。サマリー → 成果 → 課題 → 次アクションの構成が自動で整う。</p>
        </a>
        <a class="tool" href="#/goals">
          <span class="tool-tag">03 / discover</span>
          <h2>Goals</h2>
          <p>会話ログから要望・不満を抽出し、「なぜ」を繰り返して本当に叶えたい目的を見つけ出す。</p>
        </a>
        <a class="tool" href="#/brief">
          <span class="tool-tag">04 / explain</span>
          <h2>Brief</h2>
          <p>ビジネス側に説明するための一枚資料。ごちゃごちゃさせず、意思決定者が30秒で読める形に。</p>
        </a>
        <a class="tool" href="#/positioning">
          <span class="tool-tag">05 / position</span>
          <h2>Positioning</h2>
          <p>「何屋さんですか?」に一文で答える。強みを棚卸しし、誰の・どんな進歩を・どう実現するかを言語化。</p>
        </a>
        <a class="tool" href="#/retro">
          <span class="tool-tag">06 / continue</span>
          <h2>Retrospective</h2>
          <p>納品で終わらせない。振り返りを構造化し、そのまま次フェーズの継続提案に変える。</p>
        </a>
      </div>
      <p class="home-foot muted">
        AI 支援（任意）と端末間のデータ移行は <a href="#/settings">Settings</a> から。
      </p>
    </div>`;
}
