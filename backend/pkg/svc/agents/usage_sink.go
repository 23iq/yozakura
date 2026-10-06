package agents

import (
	"yozakura/backend/pkg/svc/usage"
)

// UsageSink is where finished turns and subscription rate limits go (the
// usage service). It is optional: without one nothing is recorded.
type UsageSink interface {
	usage.Recorder
	usage.LimitsSink
}

// TurnUsage is the usage of one turn (deltas, not the agent's running
// totals). Adapters compute it with a usage.Cumulative per process.
type TurnUsage struct {
	Model        string   `json:"model,omitempty"`
	InputTokens  int64    `json:"inputTokens"` // includes cached prompt tokens
	OutputTokens int64    `json:"outputTokens"`
	CachedTokens int64    `json:"cachedTokens,omitempty"`
	CostUSD      *float64 `json:"costUsd,omitempty"` // reported by the agent (Claude)
}

// SetUsageSink wires the usage ledger and limits store.
func (m *Manager) SetUsageSink(s UsageSink) {
	m.mu.Lock()
	m.usage = s
	m.mu.Unlock()
}

// usageSpace maps a session mode to the ledger space.
func usageSpace(mode string) string {
	switch mode {
	case ModeAssistant:
		return usage.SpaceAssistant
	case ModeAgent, "":
		return usage.SpaceCode
	}
	return ""
}

// recordTurnLocked records the turn usage of a done event (m.mu held). The
// sink is called on its own goroutine: it writes to disk and broadcasts.
func (m *Manager) recordTurnLocked(s *session, u *Usage) {
	if m.usage == nil || u == nil || u.Turn == nil {
		return
	}
	t := u.Turn
	if t.InputTokens == 0 && t.OutputTokens == 0 && (t.CostUSD == nil || *t.CostUSD == 0) {
		return
	}
	model := t.Model
	if model == "" {
		model = s.meta.Model
	}
	r := usage.Record{Provider: s.meta.Agent, Model: model, SessionID: s.meta.ID, Space: usageSpace(s.meta.Mode),
		Engine: usage.EngineAgent, InputTokens: t.InputTokens, OutputTokens: t.OutputTokens, CachedTokens: t.CachedTokens}
	if t.CostUSD != nil && *t.CostUSD > 0 {
		c := *t.CostUSD
		r.CostUSD = &c
	}
	sink := m.usage
	go func() { _, _ = sink.Record(r) }()
}

// limitsReporter is implemented by sinks that accept subscription limits.
type limitsReporter interface {
	RateLimits(l usage.Limits)
}

// reportLimits hands rate limits parsed by an adapter to its sink.
func reportLimits(sink Sink, l usage.Limits) {
	if len(l.Windows) == 0 {
		return
	}
	if r, ok := sink.(limitsReporter); ok {
		r.RateLimits(l)
	}
}

// RateLimits forwards subscription limits to the usage sink.
func (k *sessionSink) RateLimits(l usage.Limits) {
	m := k.s.m
	m.mu.Lock()
	sink := m.usage
	m.mu.Unlock()
	if sink == nil {
		return
	}
	if l.Source == "" {
		l.Source = "agent"
	}
	go func() { _ = sink.SetLimits(l) }()
}
