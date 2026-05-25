import { createSignal } from "solid-js";
import { Show } from "solid-js";
import { fetchScreening } from "../api/client";
import ScreeningForm from "../components/ScreeningForm";
import ScreeningResults from "../components/ScreeningResults";
import type { ScreeningFilter, ScreeningResponse } from "../types/stock";
import "../styles/screening.css";

export default function Screening() {
  const [loading, setLoading] = createSignal(false);
  const [results, setResults] = createSignal<ScreeningResponse | null>(null);
  const [error, setError] = createSignal("");

  const handleSearch = async (filter: ScreeningFilter) => {
    setLoading(true);
    setError("");
    try {
      const data = await fetchScreening(filter);
      setResults(data);
    } catch {
      setError("スクリーニングに失敗しました。バックエンドが起動しているか確認してください。");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <h1 class="screening-title">スクリーニング</h1>
      <ScreeningForm onSearch={handleSearch} loading={loading()} />

      <Show when={error()}>
        <p class="screening-error">{error()}</p>
      </Show>

      <Show when={results()}>
        {(data) => <ScreeningResults stocks={data().stocks} count={data().count} />}
      </Show>
    </div>
  );
}
