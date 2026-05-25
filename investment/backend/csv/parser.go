package csv

import (
	"encoding/csv"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/onc-limb/investment/backend/model"
)

// ParsePortfolioCSV parses an SBI Securities portfolio CSV and returns stocks.
// ASSUMPTION: SBI証券のCSVフォーマットは以下の列順と想定:
// 銘柄コード, 銘柄名, 口座区分, 保有数量, 取得単価, 取得金額, 現在値, 評価額, 損益額, 損益率(%)
func ParsePortfolioCSV(r io.Reader) ([]model.Stock, error) {
	reader := csv.NewReader(r)
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	// Skip header row
	header, err := reader.Read()
	if err != nil {
		return nil, fmt.Errorf("failed to read CSV header: %w", err)
	}
	if len(header) < 10 {
		return nil, fmt.Errorf("invalid CSV format: expected at least 10 columns, got %d", len(header))
	}

	var stocks []model.Stock
	lineNum := 1
	for {
		lineNum++
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to read CSV line %d: %w", lineNum, err)
		}
		if len(record) < 10 {
			return nil, fmt.Errorf("invalid CSV line %d: expected at least 10 columns, got %d", lineNum, len(record))
		}

		stock, err := parseRecord(record, lineNum)
		if err != nil {
			return nil, err
		}
		stocks = append(stocks, stock)
	}

	return stocks, nil
}

func parseRecord(record []string, lineNum int) (model.Stock, error) {
	quantity, err := strconv.Atoi(strings.TrimSpace(record[3]))
	if err != nil {
		return model.Stock{}, fmt.Errorf("line %d: invalid quantity %q: %w", lineNum, record[3], err)
	}

	acquirePrice, err := strconv.ParseFloat(strings.TrimSpace(record[4]), 64)
	if err != nil {
		return model.Stock{}, fmt.Errorf("line %d: invalid acquire_price %q: %w", lineNum, record[4], err)
	}

	acquireCost, err := strconv.ParseFloat(strings.TrimSpace(record[5]), 64)
	if err != nil {
		return model.Stock{}, fmt.Errorf("line %d: invalid acquire_cost %q: %w", lineNum, record[5], err)
	}

	currentPrice, err := strconv.ParseFloat(strings.TrimSpace(record[6]), 64)
	if err != nil {
		return model.Stock{}, fmt.Errorf("line %d: invalid current_price %q: %w", lineNum, record[6], err)
	}

	marketValue, err := strconv.ParseFloat(strings.TrimSpace(record[7]), 64)
	if err != nil {
		return model.Stock{}, fmt.Errorf("line %d: invalid market_value %q: %w", lineNum, record[7], err)
	}

	profitLoss, err := strconv.ParseFloat(strings.TrimSpace(record[8]), 64)
	if err != nil {
		return model.Stock{}, fmt.Errorf("line %d: invalid profit_loss %q: %w", lineNum, record[8], err)
	}

	profitRate, err := strconv.ParseFloat(strings.TrimSpace(record[9]), 64)
	if err != nil {
		return model.Stock{}, fmt.Errorf("line %d: invalid profit_rate %q: %w", lineNum, record[9], err)
	}

	accountType := parseAccountType(strings.TrimSpace(record[2]))

	return model.Stock{
		Code:         strings.TrimSpace(record[0]),
		Name:         strings.TrimSpace(record[1]),
		Quantity:     quantity,
		AcquirePrice: acquirePrice,
		AcquireCost:  acquireCost,
		CurrentPrice: currentPrice,
		MarketValue:  marketValue,
		ProfitLoss:   profitLoss,
		ProfitRate:   profitRate,
		AccountType:  accountType,
	}, nil
}

func parseAccountType(s string) model.AccountType {
	switch {
	case strings.Contains(s, "NISA"):
		return model.AccountNISA
	case strings.Contains(s, "iDeCo"):
		return model.AccountIDeCo
	default:
		return model.AccountSpecific
	}
}
