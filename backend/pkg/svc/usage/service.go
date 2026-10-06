package usage

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"

	"yozakura/backend/pkg/ipc"
)

// Recorder is what producers outside this package (the agents service)
// depend on to log usage. Record fills time, estimates the cost when the
// record has none, appends it and emits usage.updated.
type Recorder interface {
	Record(r Record) (Record, error)
}

// LimitsSink receives subscription rate limits (Codex app-server rate
// limits, Claude rate-limit events). Windows are merged by id.
type LimitsSink interface {
	SetLimits(l Limits) error
}

// Options configures a Service. Zero values are fine for tests.
type Options struct {
	Dir    string      // ledger directory
	Prices *PriceTable // nil: no estimates
	// Notify shows a shell notification (threshold alerts). nil: none.
	Notify func(summary, body string)
	// ClaudeFetch reads the Claude subscription windows. nil: disabled.
	ClaudeFetch func(context.Context) (Limits, error)
	Now         func() time.Time
}

// Service is the usage IPC service.
type Service struct {
	ledger *Ledger
	prices *PriceTable
	limits *LimitsStore
	notify func(summary, body string)
	now    func() time.Time
	poller *claudePoller

	mu   sync.RWMutex
	subs map[*ipc.Subscriber]struct{}
}

var (
	_ Recorder   = (*Service)(nil)
	_ LimitsSink = (*Service)(nil)
)

func NewService(o Options) *Service {
	if o.Now == nil {
		o.Now = time.Now
	}
	s := &Service{
		ledger: NewLedger(o.Dir),
		prices: o.Prices,
		limits: NewLimitsStore(),
		notify: o.Notify,
		now:    o.Now,
		subs:   map[*ipc.Subscriber]struct{}{},
	}
	s.loadAlertStates()
	if o.ClaudeFetch != nil {
		s.poller = newClaudePoller(o.ClaudeFetch, func(l Limits) { _ = s.SetLimits(l) })
	}
	return s
}

// Ledger exposes the ledger (CLI fallback, tests).
func (s *Service) Ledger() *Ledger { return s.ledger }

// Close stops the Claude poller.
func (s *Service) Close() {
	if s.poller != nil {
		s.poller.Stop()
	}
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "usage",
		Methods: map[string]ipc.HandlerFunc{
			"record":              s.handleRecord,
			"summary":             s.handleSummary,
			"session":             s.handleSession,
			"limits.set":          s.handleLimitsSet,
			"limits.get":          s.handleLimitsGet,
			"claudeLimits.enable": s.handleClaudeEnable,
		},
		Subscribe: s.subscribe,
	})
}

// Record implements Recorder.
func (s *Service) Record(r Record) (Record, error) {
	now := s.now()
	if err := r.normalize(now); err != nil {
		return Record{}, err
	}
	if r.CostUSD == nil {
		if p, ok := s.prices.Lookup(r.Provider, r.Model); ok {
			r.CostUSD = ptr(p.Estimate(r.InputTokens, r.OutputTokens, r.CachedTokens))
			r.Estimated = true
		}
	} else {
		r.Estimated = false // a reported cost is never an estimate
	}
	if err := s.ledger.Append(r); err != nil {
		return Record{}, err
	}
	ev := map[string]any{"record": r}
	if r.SessionID != "" {
		if t, err := s.ledger.Session(r.SessionID, now); err == nil {
			ev["session"] = t
		}
	}
	s.broadcast("usage.updated", ev)
	return r, nil
}

// SetLimits implements LimitsSink.
func (s *Service) SetLimits(l Limits) error {
	merged, alerts, err := s.limits.Set(l, s.now())
	if err != nil {
		return err
	}
	if len(alerts) > 0 {
		s.saveAlertStates()
		if s.notify != nil {
			for _, a := range alerts {
				s.notify(a.Message(s.now()))
			}
		}
	}
	s.broadcast("usage.limits", map[string]any{"provider": merged.Provider, "limits": s.limits.Get("")})
	return nil
}

// Limits returns the stored limits (all providers when provider is "").
func (s *Service) Limits(provider string) []Limits { return s.limits.Get(provider) }

// SetClaudeLimitsEnabled applies the shell setting for the OAuth fetcher.
func (s *Service) SetClaudeLimitsEnabled(on bool) {
	if s.poller != nil {
		s.poller.SetEnabled(on)
	}
}

func (s *Service) handleRecord(params json.RawMessage) (any, error) {
	var r Record
	if err := json.Unmarshal(params, &r); err != nil {
		return nil, err
	}
	return s.Record(r)
}

func (s *Service) handleSummary(params json.RawMessage) (any, error) {
	var q SummaryQuery
	if len(params) > 0 {
		if err := json.Unmarshal(params, &q); err != nil {
			return nil, err
		}
	}
	return s.ledger.Summary(q, s.now())
}

func (s *Service) handleSession(params json.RawMessage) (any, error) {
	var p struct {
		SessionID string `json:"sessionId"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	t, err := s.ledger.Session(p.SessionID, s.now())
	if err != nil {
		return nil, err
	}
	return map[string]any{"sessionId": p.SessionID, "totals": t}, nil
}

func (s *Service) handleLimitsSet(params json.RawMessage) (any, error) {
	var l Limits
	if err := json.Unmarshal(params, &l); err != nil {
		return nil, err
	}
	if err := s.SetLimits(l); err != nil {
		return nil, err
	}
	return s.limits.Get(l.Provider), nil
}

func (s *Service) handleLimitsGet(params json.RawMessage) (any, error) {
	var p struct {
		Provider string `json:"provider"`
	}
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	return map[string]any{"limits": s.limits.Get(p.Provider)}, nil
}

func (s *Service) handleClaudeEnable(params json.RawMessage) (any, error) {
	var p struct {
		Enabled *bool `json:"enabled"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, err
	}
	if p.Enabled == nil {
		return nil, errors.New("usage: enabled required")
	}
	s.SetClaudeLimitsEnabled(*p.Enabled)
	return map[string]any{"enabled": *p.Enabled, "available": s.poller != nil}, nil
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.mu.Lock()
	s.subs[sub] = struct{}{}
	s.mu.Unlock()
	sub.Send("usage.limits", map[string]any{"limits": s.limits.Get("")})
	if s.poller != nil {
		s.poller.AddSubscriber()
	}

	<-sub.StopCh()

	s.mu.Lock()
	delete(s.subs, sub)
	s.mu.Unlock()
	if s.poller != nil {
		s.poller.RemoveSubscriber()
	}
}

func (s *Service) broadcast(event string, data any) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for sub := range s.subs {
		sub.Send(event, data)
	}
}

func (s *Service) alertFile() string {
	if s.ledger.Dir() == "" {
		return ""
	}
	return filepath.Join(s.ledger.Dir(), "limit-alerts.json")
}

func (s *Service) loadAlertStates() {
	path := s.alertFile()
	if path == "" {
		return
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	var m map[string]AlertState
	if json.Unmarshal(data, &m) == nil {
		s.limits.RestoreAlertStates(m)
	}
}

func (s *Service) saveAlertStates() {
	path := s.alertFile()
	if path == "" {
		return
	}
	data, err := json.Marshal(s.limits.AlertStates())
	if err != nil {
		return
	}
	if os.MkdirAll(filepath.Dir(path), 0o700) != nil {
		return
	}
	tmp := path + ".tmp"
	if os.WriteFile(tmp, data, 0o600) == nil {
		_ = os.Rename(tmp, path)
	}
}
