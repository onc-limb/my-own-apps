package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/onc-limb/investment/backend/handler"
	"github.com/onc-limb/investment/backend/service"
)

func main() {
	portfolioSvc := service.NewPortfolioService()
	screeningSvc := service.NewScreeningService()

	portfolioHandler := handler.NewPortfolioHandler(portfolioSvc)
	screeningHandler := handler.NewScreeningHandler(screeningSvc)
	importHandler := handler.NewImportHandler(portfolioSvc)

	mux := http.NewServeMux()
	mux.HandleFunc("/api/portfolio", portfolioHandler.GetPortfolio)
	mux.HandleFunc("/api/screening", screeningHandler.GetScreening)
	mux.HandleFunc("/api/import/portfolio", importHandler.ImportPortfolio)

	corsHandler := withCORS(mux)

	port := ":8080"
	fmt.Printf("Server starting on %s\n", port)
	log.Fatal(http.ListenAndServe(port, corsHandler))
}

// withCORS wraps a handler with CORS headers allowing localhost:3000.
func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "http://localhost:3000")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}
