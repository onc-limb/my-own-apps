package model

// AccountType represents the type of investment account.
type AccountType string

const (
	AccountNISA     AccountType = "NISA"
	AccountIDeCo    AccountType = "iDeCo"
	AccountSpecific AccountType = "特定"
)

// Stock represents a single stock holding in the portfolio.
type Stock struct {
	Code         string      `json:"code"`
	Name         string      `json:"name"`
	Quantity     int         `json:"quantity"`
	AcquirePrice float64     `json:"acquire_price"`
	AcquireCost  float64     `json:"acquire_cost"`
	CurrentPrice float64     `json:"current_price"`
	MarketValue  float64     `json:"market_value"`
	ProfitLoss   float64     `json:"profit_loss"`
	ProfitRate   float64     `json:"profit_rate"`
	AccountType  AccountType `json:"account_type"`
}

// PortfolioResponse is the API response for GET /api/portfolio.
type PortfolioResponse struct {
	Stocks []Stock `json:"stocks"`
	Total  Summary `json:"total"`
}

// Summary holds aggregated portfolio values.
type Summary struct {
	TotalAcquireCost float64 `json:"total_acquire_cost"`
	TotalMarketValue float64 `json:"total_market_value"`
	TotalProfitLoss  float64 `json:"total_profit_loss"`
	TotalProfitRate  float64 `json:"total_profit_rate"`
}
