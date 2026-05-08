package service

import (
	"sync"

	"github.com/onc-limb/investment/backend/model"
)

// ScreeningService provides stock screening functionality.
type ScreeningService struct {
	mu     sync.RWMutex
	stocks []model.ScreeningStock
}

// NewScreeningService creates a new ScreeningService with sample data.
func NewScreeningService() *ScreeningService {
	return &ScreeningService{
		stocks: sampleScreeningData(),
	}
}

// Screen returns stocks matching the given filter criteria.
func (s *ScreeningService) Screen(f model.ScreeningFilter) model.ScreeningResponse {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []model.ScreeningStock
	for _, st := range s.stocks {
		if matchesFilter(st, f) {
			result = append(result, st)
		}
	}

	return model.ScreeningResponse{
		Stocks: result,
		Count:  len(result),
	}
}

func matchesFilter(st model.ScreeningStock, f model.ScreeningFilter) bool {
	if f.PERMin != nil && st.PER < *f.PERMin {
		return false
	}
	if f.PERMax != nil && st.PER > *f.PERMax {
		return false
	}
	if f.PBRMin != nil && st.PBR < *f.PBRMin {
		return false
	}
	if f.PBRMax != nil && st.PBR > *f.PBRMax {
		return false
	}
	if f.DividendYieldMin != nil && st.DividendYield < *f.DividendYieldMin {
		return false
	}
	if f.DividendYieldMax != nil && st.DividendYield > *f.DividendYieldMax {
		return false
	}
	if f.MarketCapMin != nil && st.MarketCap < *f.MarketCapMin {
		return false
	}
	if f.MarketCapMax != nil && st.MarketCap > *f.MarketCapMax {
		return false
	}
	if f.Industry != nil && string(st.Industry) != *f.Industry {
		return false
	}
	return true
}

func sampleScreeningData() []model.ScreeningStock {
	return []model.ScreeningStock{
		{Code: "7203", Name: "トヨタ自動車", Price: 2800, PER: 10.5, PBR: 1.1, DividendYield: 2.5, MarketCap: 45000000, Industry: "輸送用機器"},
		{Code: "6758", Name: "ソニーグループ", Price: 13500, PER: 15.2, PBR: 2.3, DividendYield: 0.8, MarketCap: 17000000, Industry: "電気機器"},
		{Code: "8306", Name: "三菱UFJフィナンシャル・グループ", Price: 1200, PER: 9.8, PBR: 0.7, DividendYield: 3.5, MarketCap: 15000000, Industry: "銀行業"},
		{Code: "9432", Name: "日本電信電話", Price: 170, PER: 11.3, PBR: 1.4, DividendYield: 3.0, MarketCap: 15500000, Industry: "情報・通信業"},
		{Code: "6861", Name: "キーエンス", Price: 65000, PER: 40.2, PBR: 8.5, DividendYield: 0.3, MarketCap: 16000000, Industry: "電気機器"},
		{Code: "4502", Name: "武田薬品工業", Price: 4200, PER: 25.1, PBR: 1.0, DividendYield: 4.5, MarketCap: 7000000, Industry: "医薬品"},
		{Code: "8058", Name: "三菱商事", Price: 2500, PER: 8.5, PBR: 0.9, DividendYield: 3.8, MarketCap: 10000000, Industry: "卸売業"},
		{Code: "9984", Name: "ソフトバンクグループ", Price: 8500, PER: 12.0, PBR: 1.8, DividendYield: 0.5, MarketCap: 13000000, Industry: "情報・通信業"},
		{Code: "6501", Name: "日立製作所", Price: 9800, PER: 18.5, PBR: 2.1, DividendYield: 1.2, MarketCap: 9500000, Industry: "電気機器"},
		{Code: "7974", Name: "任天堂", Price: 7500, PER: 20.3, PBR: 4.5, DividendYield: 2.8, MarketCap: 10000000, Industry: "その他製品"},
	}
}
