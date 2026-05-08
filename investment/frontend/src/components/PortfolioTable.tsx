import { For, Show } from "solid-js";
import type { Stock } from "../types/stock";
import "../styles/portfolio-table.css";

interface Props {
  stocks: Stock[];
}

function fmt(value: number): string {
  return value.toLocaleString("ja-JP");
}

function fmtCurrency(value: number): string {
  return value.toLocaleString("ja-JP", { style: "currency", currency: "JPY" });
}

export default function PortfolioTable(props: Props) {
  return (
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>銘柄コード</th>
            <th>銘柄名</th>
            <th>口座</th>
            <th class="text-right">保有数量</th>
            <th class="text-right">取得単価</th>
            <th class="text-right">取得金額</th>
            <th class="text-right">現在値</th>
            <th class="text-right">評価額</th>
            <th class="text-right">損益額</th>
            <th class="text-right">損益率</th>
          </tr>
        </thead>
        <tbody>
          <Show
            when={props.stocks.length > 0}
            fallback={
              <tr>
                <td colspan="10" class="table-empty">
                  データがありません
                </td>
              </tr>
            }
          >
            <For each={props.stocks}>
              {(stock) => {
                const plClass = () => (stock.profit_loss >= 0 ? "profit" : "loss");
                return (
                  <tr>
                    <td>{stock.code}</td>
                    <td>{stock.name}</td>
                    <td>{stock.account_type}</td>
                    <td class="text-right">{fmt(stock.quantity)}</td>
                    <td class="text-right">{fmtCurrency(stock.acquire_price)}</td>
                    <td class="text-right">{fmtCurrency(stock.acquire_cost)}</td>
                    <td class="text-right">{fmtCurrency(stock.current_price)}</td>
                    <td class="text-right">{fmtCurrency(stock.market_value)}</td>
                    <td class={`text-right ${plClass()}`}>
                      {stock.profit_loss >= 0 ? "+" : ""}{fmtCurrency(stock.profit_loss)}
                    </td>
                    <td class={`text-right ${plClass()}`}>
                      {stock.profit_rate >= 0 ? "+" : ""}{stock.profit_rate.toFixed(2)}%
                    </td>
                  </tr>
                );
              }}
            </For>
          </Show>
        </tbody>
      </table>
    </div>
  );
}
