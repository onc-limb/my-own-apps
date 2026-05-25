package model

// Industry represents a stock's industry sector.
type Industry string

// ScreeningStock represents a stock returned by the screening API.
type ScreeningStock struct {
	Code          string   `json:"code"`
	Name          string   `json:"name"`
	Price         float64  `json:"price"`
	PER           float64  `json:"per"`
	PBR           float64  `json:"pbr"`
	DividendYield float64  `json:"dividend_yield"`
	MarketCap     float64  `json:"market_cap"`
	Industry      Industry `json:"industry"`
}

// ScreeningFilter holds query parameters for filtering stocks.
type ScreeningFilter struct {
	PERMin           *float64 `json:"per_min"`
	PERMax           *float64 `json:"per_max"`
	PBRMin           *float64 `json:"pbr_min"`
	PBRMax           *float64 `json:"pbr_max"`
	DividendYieldMin *float64 `json:"dividend_yield_min"`
	DividendYieldMax *float64 `json:"dividend_yield_max"`
	MarketCapMin     *float64 `json:"market_cap_min"`
	MarketCapMax     *float64 `json:"market_cap_max"`
	Industry         *string  `json:"industry"`
}

// ScreeningResponse is the API response for GET /api/screening.
type ScreeningResponse struct {
	Stocks []ScreeningStock `json:"stocks"`
	Count  int              `json:"count"`
}
