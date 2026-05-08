import { For, Show } from "solid-js";
import type { ScreeningStock } from "../types/stock";
import "../styles/screening-results.css";
import "../styles/portfolio-table.css";

interface Props {
  stocks: ScreeningStock[];
  count: number;
}

function fmtNum(value: number): string {
  return value.toLocaleString("ja-JP");
}

export default function ScreeningResults(props: Props) {
  return (
    <div>
      <p class="screening-results-count">
        {props.count}件の銘柄が見つかりました
      </p>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>銘柄コード</th>
              <th>銘柄名</th>
              <th>業種</th>
              <th class="text-right">株価</th>
              <th class="text-right">PER</th>
              <th class="text-right">PBR</th>
              <th class="text-right">配当利回り</th>
              <th class="text-right">時価総額</th>
            </tr>
          </thead>
          <tbody>
            <Show
              when={props.stocks.length > 0}
              fallback={
                <tr>
                  <td colspan="8" class="table-empty">
                    該当する銘柄がありません
                  </td>
                </tr>
              }
            >
              <For each={props.stocks}>
                {(stock) => (
                  <tr>
                    <td>{stock.code}</td>
                    <td>{stock.name}</td>
                    <td>{stock.industry}</td>
                    <td class="text-right">{fmtNum(stock.price)}円</td>
                    <td class="text-right">{stock.per.toFixed(1)}</td>
                    <td class="text-right">{stock.pbr.toFixed(1)}</td>
                    <td class="text-right">{stock.dividend_yield.toFixed(1)}%</td>
                    <td class="text-right">{fmtNum(stock.market_cap)}百万円</td>
                  </tr>
                )}
              </For>
            </Show>
          </tbody>
        </table>
      </div>
    </div>
  );
}
