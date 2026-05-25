import type { Summary } from "../types/stock";
import "../styles/portfolio-summary.css";

interface Props {
  summary: Summary;
}

function formatCurrency(value: number): string {
  return value.toLocaleString("ja-JP", { style: "currency", currency: "JPY" });
}

export default function PortfolioSummary(props: Props) {
  const plClass = () => (props.summary.total_profit_loss >= 0 ? "profit" : "loss");

  return (
    <section class="summary-grid">
      <SummaryCard label="総投資額" value={formatCurrency(props.summary.total_acquire_cost)} />
      <SummaryCard label="総評価額" value={formatCurrency(props.summary.total_market_value)} />
      <SummaryCard
        label="総損益"
        value={`${formatCurrency(props.summary.total_profit_loss)} (${props.summary.total_profit_rate >= 0 ? "+" : ""}${props.summary.total_profit_rate.toFixed(2)}%)`}
        colorClass={plClass()}
      />
    </section>
  );
}

function SummaryCard(props: { label: string; value: string; colorClass?: string }) {
  return (
    <article class="summary-card">
      <p class="summary-card-label">{props.label}</p>
      <p class={`summary-card-value ${props.colorClass ?? ""}`}>{props.value}</p>
    </article>
  );
}
