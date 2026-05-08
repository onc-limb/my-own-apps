package handler

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/onc-limb/investment/backend/model"
)

// PortfolioServicer defines the interface for portfolio operations.
type PortfolioServicer interface {
	GetPortfolio(accountType string) model.PortfolioResponse
	ImportStocks(stocks []model.Stock)
}

// PortfolioHandler handles portfolio API requests.
type PortfolioHandler struct {
	svc PortfolioServicer
}

// NewPortfolioHandler creates a new PortfolioHandler.
func NewPortfolioHandler(svc PortfolioServicer) *PortfolioHandler {
	return &PortfolioHandler{svc: svc}
}

// GetPortfolio handles GET /api/portfolio.
func (h *PortfolioHandler) GetPortfolio(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	accountType := r.URL.Query().Get("account_type")
	resp := h.svc.GetPortfolio(accountType)

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("failed to encode portfolio response: %v", err)
	}
}
