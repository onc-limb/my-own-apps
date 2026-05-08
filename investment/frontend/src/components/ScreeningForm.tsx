import { createSignal, For } from "solid-js";
import type { ScreeningFilter } from "../types/stock";
import "../styles/screening-form.css";

interface Props {
  onSearch: (filter: ScreeningFilter) => void;
  loading: boolean;
}

const INDUSTRIES = [
  "輸送用機器",
  "電気機器",
  "銀行業",
  "情報・通信業",
  "医薬品",
  "卸売業",
  "その他製品",
];

export default function ScreeningForm(props: Props) {
  const [perMin, setPerMin] = createSignal("");
  const [perMax, setPerMax] = createSignal("");
  const [pbrMin, setPbrMin] = createSignal("");
  const [pbrMax, setPbrMax] = createSignal("");
  const [divYieldMin, setDivYieldMin] = createSignal("");
  const [marketCapMin, setMarketCapMin] = createSignal("");
  const [marketCapMax, setMarketCapMax] = createSignal("");
  const [industry, setIndustry] = createSignal("");

  const handleSubmit = (e: Event) => {
    e.preventDefault();
    const filter: ScreeningFilter = {};
    if (perMin()) filter.per_min = Number(perMin());
    if (perMax()) filter.per_max = Number(perMax());
    if (pbrMin()) filter.pbr_min = Number(pbrMin());
    if (pbrMax()) filter.pbr_max = Number(pbrMax());
    if (divYieldMin()) filter.dividend_yield_min = Number(divYieldMin());
    if (marketCapMin()) filter.market_cap_min = Number(marketCapMin());
    if (marketCapMax()) filter.market_cap_max = Number(marketCapMax());
    if (industry()) filter.industry = industry();
    props.onSearch(filter);
  };

  return (
    <form onSubmit={handleSubmit} class="screening-form">
      <h2 class="screening-form-title">スクリーニング条件</h2>
      <div class="screening-form-grid">
        <div class="screening-field">
          <label class="screening-label" for="per-min">PER（下限）</label>
          <input
            id="per-min"
            class="screening-input"
            type="number"
            step="0.1"
            placeholder="例: 5"
            value={perMin()}
            onInput={(e) => setPerMin(e.currentTarget.value)}
          />
        </div>
        <div class="screening-field">
          <label class="screening-label" for="per-max">PER（上限）</label>
          <input
            id="per-max"
            class="screening-input"
            type="number"
            step="0.1"
            placeholder="例: 20"
            value={perMax()}
            onInput={(e) => setPerMax(e.currentTarget.value)}
          />
        </div>
        <div class="screening-field">
          <label class="screening-label" for="pbr-min">PBR（下限）</label>
          <input
            id="pbr-min"
            class="screening-input"
            type="number"
            step="0.1"
            placeholder="例: 0.5"
            value={pbrMin()}
            onInput={(e) => setPbrMin(e.currentTarget.value)}
          />
        </div>
        <div class="screening-field">
          <label class="screening-label" for="pbr-max">PBR（上限）</label>
          <input
            id="pbr-max"
            class="screening-input"
            type="number"
            step="0.1"
            placeholder="例: 3.0"
            value={pbrMax()}
            onInput={(e) => setPbrMax(e.currentTarget.value)}
          />
        </div>
        <div class="screening-field">
          <label class="screening-label" for="div-yield-min">配当利回り（下限 %）</label>
          <input
            id="div-yield-min"
            class="screening-input"
            type="number"
            step="0.1"
            placeholder="例: 2.0"
            value={divYieldMin()}
            onInput={(e) => setDivYieldMin(e.currentTarget.value)}
          />
        </div>
        <div class="screening-field">
          <label class="screening-label" for="market-cap-min">時価総額 下限（百万円）</label>
          <input
            id="market-cap-min"
            class="screening-input"
            type="number"
            placeholder="例: 5000000"
            value={marketCapMin()}
            onInput={(e) => setMarketCapMin(e.currentTarget.value)}
          />
        </div>
        <div class="screening-field">
          <label class="screening-label" for="market-cap-max">時価総額 上限（百万円）</label>
          <input
            id="market-cap-max"
            class="screening-input"
            type="number"
            placeholder="例: 50000000"
            value={marketCapMax()}
            onInput={(e) => setMarketCapMax(e.currentTarget.value)}
          />
        </div>
        <div class="screening-field">
          <label class="screening-label" for="industry">業種</label>
          <select
            id="industry"
            class="screening-input"
            value={industry()}
            onChange={(e) => setIndustry(e.currentTarget.value)}
          >
            <option value="">すべて</option>
            <For each={INDUSTRIES}>
              {(ind) => <option value={ind}>{ind}</option>}
            </For>
          </select>
        </div>
      </div>
      <button type="submit" disabled={props.loading} class="screening-submit">
        {props.loading ? "検索中..." : "検索"}
      </button>
    </form>
  );
}
