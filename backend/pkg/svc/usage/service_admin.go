package usage

import (
	"encoding/json"
	"errors"
	"os"
	"sort"
)

// Clear deletes every month file of the ledger (the alert markers stay).
func (l *Ledger) Clear() (int, error) {
	months := l.Months()
	l.mu.Lock()
	defer l.mu.Unlock()
	n := 0
	var first error
	for _, m := range months {
		if err := os.Remove(l.file(m)); err != nil && !errors.Is(err, os.ErrNotExist) {
			if first == nil {
				first = err
			}
			continue
		}
		n++
	}
	l.cache = map[string][]Record{}
	return n, first
}

// SetThresholds replaces the notification thresholds (percent, 1-100).
// An empty list turns limit notifications off.
func (s *LimitsStore) SetThresholds(ts []float64) []float64 {
	out := []float64{}
	seen := map[float64]bool{}
	for _, t := range ts {
		if t >= 1 && t <= 100 && !seen[t] {
			seen[t] = true
			out = append(out, t)
		}
	}
	sort.Float64s(out)
	s.mu.Lock()
	s.thresholds = out
	s.mu.Unlock()
	return append([]float64(nil), out...)
}

// Thresholds returns the active notification thresholds.
func (s *LimitsStore) Thresholds() []float64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]float64(nil), s.thresholds...)
}

// handleAlertsSet: {"thresholds":[80,90]} ([] = no notifications).
func (s *Service) handleAlertsSet(params json.RawMessage) (any, error) {
	var p struct {
		Thresholds *[]float64 `json:"thresholds"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Thresholds == nil {
		return nil, errors.New("usage: thresholds required")
	}
	return map[string]any{"thresholds": s.limits.SetThresholds(*p.Thresholds)}, nil
}

// handleClear: {"confirm":true} deletes the ledger and emits usage.cleared.
func (s *Service) handleClear(params json.RawMessage) (any, error) {
	var p struct {
		Confirm bool `json:"confirm"`
	}
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	if !p.Confirm {
		return nil, errors.New("usage: clear needs confirm:true")
	}
	n, err := s.ledger.Clear()
	if err != nil {
		return nil, err
	}
	s.broadcast("usage.cleared", map[string]any{"files": n})
	return map[string]any{"files": n}, nil
}

// handleInfo reports where the ledger and the price override file live.
func (s *Service) handleInfo(json.RawMessage) (any, error) {
	return map[string]any{
		"ledgerDir":      s.ledger.Dir(),
		"pricesOverride": s.pricesOverride,
		"thresholds":     s.limits.Thresholds(),
		"claudeLimits":   s.poller != nil,
	}, nil
}
