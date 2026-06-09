export function renderHome(root: HTMLElement): void {
  root.innerHTML = `
    <div class="page">
      <div class="hero">
        <h1>telos</h1>
        <p class="lead">情報を「記録」で終わらせず、目的に向かう道具に変える。</p>
      </div>
      <div class="tool-grid">
        <a class="tool" href="#/checklist">
          <h2>Checklist</h2>
          <p>新規ソフトウェアリリースの「やるべきこと」を記憶の外に出す。テンプレートから作成し、リリース判定の状態を一目で。</p>
        </a>
        <a class="tool" href="#/slides">
          <h2>Slides</h2>
          <p>進捗を結論ファーストの報告スライドに。フォームに入力するだけで、サマリー → 成果 → 課題 → 次アクションの構成が完成。</p>
        </a>
        <a class="tool" href="#/goals">
          <h2>Goals</h2>
          <p>会話ログを貼り付けて要望・不満を抽出し、「なぜ」を繰り返して本当に叶えたい目的を見つけ出す。</p>
        </a>
      </div>
    </div>`;
}
