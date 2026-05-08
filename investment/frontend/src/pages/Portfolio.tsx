import { createSignal, createResource, Show, For } from "solid-js";
import { fetchPortfolio, importPortfolioCsv } from "../api/client";
import PortfolioSummary from "../components/PortfolioSummary";
import PortfolioTable from "../components/PortfolioTable";
import type { AccountType } from "../types/stock";
import "../styles/portfolio.css";

const ACCOUNT_FILTERS: { label: string; value: string }[] = [
  { label: "すべて", value: "all" },
  { label: "NISA", value: "NISA" },
  { label: "iDeCo", value: "iDeCo" },
  { label: "特定口座", value: "特定" },
];

export default function Portfolio() {
  const [accountFilter, setAccountFilter] = createSignal("all");
  const [importStatus, setImportStatus] = createSignal("");

  const [portfolio, { refetch }] = createResource(accountFilter, (acct) =>
    fetchPortfolio(acct),
  );

  let fileInput!: HTMLInputElement;

  const handleImport = async () => {
    const file = fileInput?.files?.[0];
    if (!file) return;
    try {
      setImportStatus("インポート中...");
      await importPortfolioCsv(file);
      setImportStatus("インポート完了");
      fileInput.value = "";
      refetch();
    } catch {
      setImportStatus("インポートに失敗しました");
    }
  };

  return (
    <div>
      <header class="portfolio-header">
        <h1 class="portfolio-title">ポートフォリオ</h1>
        <div class="portfolio-actions">
          <input
            ref={fileInput}
            type="file"
            accept=".csv"
            class="portfolio-file-input"
            onChange={handleImport}
          />
          <button
            onClick={() => fileInput.click()}
            class="portfolio-import-btn"
          >
            CSVインポート
          </button>
          <Show when={importStatus()}>
            <span class="portfolio-import-status">
              {importStatus()}
            </span>
          </Show>
        </div>
      </header>

      <nav class="portfolio-filter-nav" aria-label="口座フィルタ">
        <For each={ACCOUNT_FILTERS}>
          {(f) => (
            <button
              class={`portfolio-filter-btn ${accountFilter() === f.value ? "portfolio-filter-btn--active" : ""}`}
              onClick={() => setAccountFilter(f.value)}
              aria-pressed={accountFilter() === f.value}
            >
              {f.label}
            </button>
          )}
        </For>
      </nav>

      <Show when={portfolio.error}>
        <p class="portfolio-error">
          データの取得に失敗しました。バックエンドが起動しているか確認してください。
        </p>
      </Show>

      <Show when={portfolio()} fallback={<p>読み込み中...</p>}>
        {(data) => (
          <>
            <PortfolioSummary summary={data().total} />
            <PortfolioTable stocks={data().stocks} />
          </>
        )}
      </Show>
    </div>
  );
}
