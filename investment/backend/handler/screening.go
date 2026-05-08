package handler

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"github.com/onc-limb/investment/backend/model"
)

// ScreeningServicer defines the interface for screening operations.
type ScreeningServicer interface {
	Screen(filter model.ScreeningFilter) model.ScreeningResponse
}

// ScreeningHandler handles screening API requests.
type ScreeningHandler struct {
	svc ScreeningServicer
}

// NewScreeningHandler creates a new ScreeningHandler.
func NewScreeningHandler(svc ScreeningServicer) *ScreeningHandler {
	return &ScreeningHandler{svc: svc}
}

// GetScreening handles GET /api/screening.
func (h *ScreeningHandler) GetScreening(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	filter, err := parseScreeningFilter(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	resp := h.svc.Screen(filter)

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("failed to encode screening response: %v", err)
	}
}

func parseScreeningFilter(r *http.Request) (model.ScreeningFilter, error) {
	q := r.URL.Query()
	var f model.ScreeningFilter
	var err error

	f.PERMin, err = parseOptionalFloat(q.Get("per_min"), "per_min")
	if err != nil {
		return f, err
	}
	f.PERMax, err = parseOptionalFloat(q.Get("per_max"), "per_max")
	if err != nil {
		return f, err
	}
	f.PBRMin, err = parseOptionalFloat(q.Get("pbr_min"), "pbr_min")
	if err != nil {
		return f, err
	}
	f.PBRMax, err = parseOptionalFloat(q.Get("pbr_max"), "pbr_max")
	if err != nil {
		return f, err
	}
	f.DividendYieldMin, err = parseOptionalFloat(q.Get("dividend_yield_min"), "dividend_yield_min")
	if err != nil {
		return f, err
	}
	f.DividendYieldMax, err = parseOptionalFloat(q.Get("dividend_yield_max"), "dividend_yield_max")
	if err != nil {
		return f, err
	}
	f.MarketCapMin, err = parseOptionalFloat(q.Get("market_cap_min"), "market_cap_min")
	if err != nil {
		return f, err
	}
	f.MarketCapMax, err = parseOptionalFloat(q.Get("market_cap_max"), "market_cap_max")
	if err != nil {
		return f, err
	}

	if industry := q.Get("industry"); industry != "" {
		f.Industry = &industry
	}

	return f, nil
}

func parseOptionalFloat(s string, paramName string) (*float64, error) {
	if s == "" {
		return nil, nil
	}
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return nil, fmt.Errorf("invalid value for %s: %q", paramName, s)
	}
	return &v, nil
}
