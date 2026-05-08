package handler

import (
	"encoding/json"
	"log"
	"net/http"

	csvparser "github.com/onc-limb/investment/backend/csv"
)

// ImportHandler handles CSV import API requests.
type ImportHandler struct {
	portfolioSvc PortfolioServicer
}

// NewImportHandler creates a new ImportHandler.
func NewImportHandler(portfolioSvc PortfolioServicer) *ImportHandler {
	return &ImportHandler{portfolioSvc: portfolioSvc}
}

// ImportPortfolio handles POST /api/import/portfolio.
func (h *ImportHandler) ImportPortfolio(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	// Max 10MB
	if err := r.ParseMultipartForm(10 << 20); err != nil {
		writeError(w, http.StatusBadRequest, "failed to parse multipart form: "+err.Error())
		return
	}

	file, _, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "file is required: "+err.Error())
		return
	}
	defer file.Close()

	stocks, err := csvparser.ParsePortfolioCSV(file)
	if err != nil {
		writeError(w, http.StatusBadRequest, "failed to parse CSV: "+err.Error())
		return
	}

	h.portfolioSvc.ImportStocks(stocks)

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]interface{}{
		"message":        "imported successfully",
		"imported_count": len(stocks),
	}); err != nil {
		log.Printf("failed to encode import response: %v", err)
	}
}
