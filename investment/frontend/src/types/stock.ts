export type AccountType = "NISA" | "iDeCo" | "特定";

export interface Stock {
  code: string;
  name: string;
  quantity: number;
  acquire_price: number;
  acquire_cost: number;
  current_price: number;
  market_value: number;
  profit_loss: number;
  profit_rate: number;
  account_type: AccountType;
}

export interface Summary {
  total_acquire_cost: number;
  total_market_value: number;
  total_profit_loss: number;
  total_profit_rate: number;
}

export interface PortfolioResponse {
  stocks: Stock[];
  total: Summary;
}

export interface ScreeningStock {
  code: string;
  name: string;
  price: number;
  per: number;
  pbr: number;
  dividend_yield: number;
  market_cap: number;
  industry: string;
}

export interface ScreeningFilter {
  per_min?: number;
  per_max?: number;
  pbr_min?: number;
  pbr_max?: number;
  dividend_yield_min?: number;
  dividend_yield_max?: number;
  market_cap_min?: number;
  market_cap_max?: number;
  industry?: string;
}

export interface ScreeningResponse {
  stocks: ScreeningStock[];
  count: number;
}
