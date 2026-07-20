import { load, save } from "../storage";
import { escapeHtml, formatDate, uid } from "../util";

interface ChecklistItem {
  id: string;
  category: string;
  text: string;
  done: boolean;
}

interface Checklist {
  id: string;
  name: string;
  createdAt: string;
  items: ChecklistItem[];
}

const KEY = "telos:checklists";

// 新規ソフトウェアリリースの標準テンプレート。
// 根拠: 専門家の失敗の多くは「知らない」ではなく「知っているのにやり損ねる」
// （Gawande 2009, Haynes 2009 — docs/concept.md 参照）
const TEMPLATE: ReadonlyArray<{ category: string; items: string[] }> = [
  {
    category: "企画・要件",
    items: [
      "リリース範囲（含む機能・含まない機能）を確定した",
      "ステークホルダーにリリース内容の最終確認を取った",
      "リリース可否の判定基準を合意した",
    ],
  },
  {
    category: "開発・品質",
    items: [
      "機能テストが完了した",
      "回帰テストが完了した",
      "パフォーマンス・負荷の確認をした",
      "コードレビューがすべて完了した",
      "既知のバグをトリアージし、リリースブロッカーがないことを確認した",
    ],
  },
  {
    category: "セキュリティ",
    items: [
      "脆弱性スキャンを実施した",
      "依存ライブラリの監査（既知脆弱性・ライセンス）をした",
      "アクセス権限・認可の設定を確認した",
      "個人情報・機密データの取り扱いを確認した",
    ],
  },
  {
    category: "運用準備",
    items: [
      "監視・アラートを設定した",
      "ロールバック手順を準備し、実際に検証した",
      "バックアップが取得できていることを確認した",
      "障害時のエスカレーションフローを関係者と確認した",
      "リリース手順書を作成し、レビューした",
    ],
  },
  {
    category: "ドキュメント",
    items: [
      "リリースノートを作成した",
      "ユーザー向けドキュメントを更新した",
      "社内向け FAQ・ナレッジを整備した",
    ],
  },
  {
    category: "告知・サポート",
    items: [
      "関係部署にリリース日時と影響範囲を告知した",
      "カスタマーサポートに変更点と想定問い合わせを共有した",
      "ユーザー向け告知（メール・お知らせ等）を準備した",
    ],
  },
  {
    category: "リリース後",
    items: [
      "本番環境でスモークテストをした",
      "エラー率・主要メトリクスを監視した",
      "ユーザーフィードバックの収集経路を確認した",
      "ふりかえりを実施し、このチェックリストを更新した",
    ],
  },
];

function loadAll(): Checklist[] {
  return load<Checklist[]>(KEY, []);
}

function saveAll(lists: Checklist[]): void {
  save(KEY, lists);
}

function createFromTemplate(name: string): Checklist {
  return {
    id: uid(),
    name,
    createdAt: new Date().toISOString(),
    items: TEMPLATE.flatMap((cat) =>
      cat.items.map((text) => ({
        id: uid(),
        category: cat.category,
        text,
        done: false,
      })),
    ),
  };
}

function progress(items: ChecklistItem[]): { done: number; total: number; pct: number } {
  const done = items.filter((i) => i.done).length;
  const total = items.length;
  return { done, total, pct: total === 0 ? 0 : Math.round((done / total) * 100) };
}

export function renderChecklistList(root: HTMLElement): void {
  const lists = loadAll();
  root.innerHTML = `
    <div class="page">
      <div class="page-head">
        <div>
          <h1>Checklist</h1>
          <p class="lead">リリース前後の「やるべきこと」を記憶の外に出す。</p>
        </div>
        <form id="new-checklist" class="inline-form">
          <input name="name" type="text" placeholder="例: my-app v2.0 リリース" required />
          <button type="submit" class="primary">テンプレートから作成</button>
        </form>
      </div>
      ${
        lists.length === 0
          ? `<p class="empty">まだチェックリストがありません。リリース名を入れて作成してください。</p>`
          : `<ul class="card-list">${lists
              .map((l) => {
                const p = progress(l.items);
                return `
                <li class="card">
                  <a href="#/checklist/${l.id}" class="card-main">
                    <strong>${escapeHtml(l.name)}</strong>
                    <span class="muted">${formatDate(l.createdAt)} 作成 ・ ${p.done}/${p.total} 完了</span>
                    <span class="bar"><span class="bar-fill" style="width:${p.pct}%"></span></span>
                  </a>
                  <button class="ghost danger" data-delete="${l.id}">削除</button>
                </li>`;
              })
              .join("")}</ul>`
      }
    </div>`;

  root.querySelector<HTMLFormElement>("#new-checklist")!.addEventListener("submit", (e) => {
    e.preventDefault();
    const input = (e.target as HTMLFormElement).elements.namedItem("name") as HTMLInputElement;
    const list = createFromTemplate(input.value.trim());
    saveAll([list, ...loadAll()]);
    location.hash = `#/checklist/${list.id}`;
  });

  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!confirm("このチェックリストを削除しますか？")) return;
      saveAll(loadAll().filter((l) => l.id !== btn.dataset.delete));
      renderChecklistList(root);
    }),
  );
}

export function renderChecklistDetail(root: HTMLElement, id: string): void {
  const lists = loadAll();
  const list = lists.find((l) => l.id === id);
  if (!list) {
    root.innerHTML = `<div class="page"><p class="empty">チェックリストが見つかりません。<a href="#/checklist">一覧に戻る</a></p></div>`;
    return;
  }
  const p = progress(list.items);
  const categories = [...new Set(list.items.map((i) => i.category))];

  root.innerHTML = `
    <div class="page">
      <p><a href="#/checklist">← 一覧に戻る</a></p>
      <div class="page-head">
        <div>
          <h1>${escapeHtml(list.name)}</h1>
          <p class="lead">${p.done} / ${p.total} 完了（${p.pct}%）${p.pct === 100 ? " 🎉 リリース判定 OK" : ""}</p>
        </div>
      </div>
      <span class="bar big"><span class="bar-fill" style="width:${p.pct}%"></span></span>
      ${categories
        .map((cat) => {
          const items = list.items.filter((i) => i.category === cat);
          const cp = progress(items);
          return `
          <section class="check-group">
            <h2>${escapeHtml(cat)} <span class="muted">${cp.done}/${cp.total}</span></h2>
            <ul class="check-items">
              ${items
                .map(
                  (i) => `
                <li class="${i.done ? "done" : ""}">
                  <label>
                    <input type="checkbox" data-toggle="${i.id}" ${i.done ? "checked" : ""} />
                    <span>${escapeHtml(i.text)}</span>
                  </label>
                  <button class="ghost danger" data-remove="${i.id}" title="削除">×</button>
                </li>`,
                )
                .join("")}
            </ul>
            <form class="inline-form add-item" data-category="${escapeHtml(cat)}">
              <input type="text" name="text" placeholder="項目を追加..." required />
              <button type="submit" class="ghost">+ 追加</button>
            </form>
          </section>`;
        })
        .join("")}
    </div>`;

  const persistAndRerender = () => {
    saveAll(lists);
    renderChecklistDetail(root, id);
  };

  root.querySelectorAll<HTMLInputElement>("[data-toggle]").forEach((cb) =>
    cb.addEventListener("change", () => {
      const item = list.items.find((i) => i.id === cb.dataset.toggle);
      if (item) item.done = cb.checked;
      persistAndRerender();
    }),
  );

  root.querySelectorAll<HTMLButtonElement>("[data-remove]").forEach((btn) =>
    btn.addEventListener("click", () => {
      list.items = list.items.filter((i) => i.id !== btn.dataset.remove);
      persistAndRerender();
    }),
  );

  root.querySelectorAll<HTMLFormElement>(".add-item").forEach((form) =>
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      const input = form.elements.namedItem("text") as HTMLInputElement;
      list.items.push({
        id: uid(),
        category: form.dataset.category!,
        text: input.value.trim(),
        done: false,
      });
      persistAndRerender();
    }),
  );
}
