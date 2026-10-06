// Package usage keeps the AI token/cost ledger and the subscription rate
// limits shown by the AI bar.
//
// The ledger is append-only JSONL, one file per month
// (<data dir>/usage/YYYY-MM.jsonl). Producers are the QML HTTP chat engine
// (IPC usage.record) and the CLI agents (the Recorder interface). Limits are
// an in-memory store fed by the agents (Codex/Claude rate-limit events,
// LimitsSink) and by the Claude OAuth usage fetcher.
package usage

import (
	"errors"
	"strings"
	"time"
)

// Spaces and engines a record can come from.
const (
	SpaceAssistant = "assistant"
	SpaceCode      = "code"
	EngineHTTP     = "http"
	EngineAgent    = "agent"
)

// Record is one ledger line: the usage of one request/turn.
type Record struct {
	Time         time.Time `json:"time"`
	Provider     string    `json:"provider"`
	Model        string    `json:"model,omitempty"`
	SessionID    string    `json:"sessionId,omitempty"`
	Space        string    `json:"space,omitempty"`
	Engine       string    `json:"engine,omitempty"`
	InputTokens  int64     `json:"inputTokens"`
	OutputTokens int64     `json:"outputTokens"`
	CachedTokens int64     `json:"cachedTokens,omitempty"`
	// CostUSD is nil when neither the provider reported a cost nor the
	// price table knows the model.
	CostUSD   *float64 `json:"costUSD,omitempty"`
	Estimated bool     `json:"estimated,omitempty"`
}

// normalize validates r and fills defaults. now supplies the time when the
// record has none.
func (r *Record) normalize(now time.Time) error {
	r.Provider = strings.TrimSpace(strings.ToLower(r.Provider))
	r.Model = strings.TrimSpace(r.Model)
	if r.Provider == "" {
		return errors.New("usage: provider required")
	}
	if r.InputTokens < 0 || r.OutputTokens < 0 || r.CachedTokens < 0 {
		return errors.New("usage: token counts must not be negative")
	}
	if r.CostUSD != nil && *r.CostUSD < 0 {
		return errors.New("usage: cost must not be negative")
	}
	switch r.Space {
	case "", SpaceAssistant, SpaceCode:
	default:
		return errors.New("usage: space must be assistant or code")
	}
	switch r.Engine {
	case "", EngineHTTP, EngineAgent:
	default:
		return errors.New("usage: engine must be http or agent")
	}
	if r.Time.IsZero() {
		r.Time = now
	}
	return nil
}

// Totals sums a set of records.
type Totals struct {
	Requests     int     `json:"requests"`
	InputTokens  int64   `json:"inputTokens"`
	OutputTokens int64   `json:"outputTokens"`
	CachedTokens int64   `json:"cachedTokens"`
	CostUSD      float64 `json:"costUSD"`
	// Estimated is true when part of CostUSD comes from the price table.
	Estimated bool `json:"estimated"`
	// Unpriced counts records without any cost (unknown model).
	Unpriced int `json:"unpriced"`
}

func (t *Totals) add(r Record) {
	t.Requests++
	t.InputTokens += r.InputTokens
	t.OutputTokens += r.OutputTokens
	t.CachedTokens += r.CachedTokens
	if r.CostUSD == nil {
		t.Unpriced++
		return
	}
	t.CostUSD += *r.CostUSD
	if r.Estimated {
		t.Estimated = true
	}
}

func ptr(f float64) *float64 { return &f }
