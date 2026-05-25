import type {
  PortfolioResponse,
  ScreeningFilter,
  ScreeningResponse,
} from "../types/stock";

const BASE_URL = "/api";

export async function fetchPortfolio(
  accountType?: string,
): Promise<PortfolioResponse> {
  const params = new URLSearchParams();
  if (accountType && accountType !== "all") {
    params.set("account_type", accountType);
  }
  const query = params.toString() ? `?${params.toString()}` : "";
  const res = await fetch(`${BASE_URL}/portfolio${query}`);
  if (!res.ok) throw new Error(`Failed to fetch portfolio: ${res.status}`);
  return res.json();
}

export async function importPortfolioCsv(file: File): Promise<void> {
  const formData = new FormData();
  formData.append("file", file);
  const res = await fetch(`${BASE_URL}/import/portfolio`, {
    method: "POST",
    body: formData,
  });
  if (!res.ok) throw new Error(`Failed to import CSV: ${res.status}`);
}

export async function fetchScreening(
  filter: ScreeningFilter,
): Promise<ScreeningResponse> {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(filter)) {
    if (value !== undefined && value !== "") {
      params.set(key, String(value));
    }
  }
  const query = params.toString() ? `?${params.toString()}` : "";
  const res = await fetch(`${BASE_URL}/screening${query}`);
  if (!res.ok) throw new Error(`Failed to fetch screening: ${res.status}`);
  return res.json();
}
