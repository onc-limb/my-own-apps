package service

import (
	"sync"

	"github.com/onc-limb/investment/backend/model"
)

// PortfolioService manages portfolio data in memory.
type PortfolioService struct {
	mu     sync.RWMutex
	stocks []model.Stock
}

// NewPortfolioService creates a new PortfolioService with sample data.
func NewPortfolioService() *PortfolioService {
	return &PortfolioService{
		stocks: []model.Stock{},
	}
}

// GetPortfolio returns the current portfolio with computed totals.
// If accountType is non-empty, only stocks matching that account type are included.
func (s *PortfolioService) GetPortfolio(accountType string) model.PortfolioResponse {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var stocks []model.Stock
	if accountType == "" {
		stocks = make([]model.Stock, len(s.stocks))
		copy(stocks, s.stocks)
	} else {
		stocks = make([]model.Stock, 0)
		for _, st := range s.stocks {
			if string(st.AccountType) == accountType {
				stocks = append(stocks, st)
			}
		}
	}

	var totalAcquire, totalMarket float64
	for _, st := range stocks {
		totalAcquire += st.AcquireCost
		totalMarket += st.MarketValue
	}

	totalPL := totalMarket - totalAcquire
	var totalRate float64
	if totalAcquire > 0 {
		totalRate = (totalPL / totalAcquire) * 100
	}

	return model.PortfolioResponse{
		Stocks: stocks,
		Total: model.Summary{
			TotalAcquireCost: totalAcquire,
			TotalMarketValue: totalMarket,
			TotalProfitLoss:  totalPL,
			TotalProfitRate:  totalRate,
		},
	}
}

// ImportStocks replaces the portfolio with the given stocks.
func (s *PortfolioService) ImportStocks(stocks []model.Stock) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.stocks = stocks
}
