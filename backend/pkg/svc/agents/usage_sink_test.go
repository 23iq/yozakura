package agents

import (
	"encoding/json"
	"math"
	"sync"
	"testing"
	"time"

	"yozakura/backend/pkg/svc/usage"
)

// fakeUsage records what the manager hands to the usage service.
type fakeUsage struct {
	mu      sync.Mutex
	records []usage.Record
	limits  []usage.Limits
}

func (f *fakeUsage) Record(r usage.Record) (usage.Record, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.records = append(f.records, r)
	return r, nil
}

func (f *fakeUsage) SetLimits(l usage.Limits) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.limits = append(f.limits, l)
	return nil
}

func (f *fakeUsage) snapshot() ([]usage.Record, []usage.Limits) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]usage.Record(nil), f.records...), append([]usage.Limits(nil), f.limits...)
}

// limitsSink is a recSink that also accepts rate limits.
type limitsSink struct {
	recSink
	mu     sync.Mutex
	limits []usage.Limits
}

func (l *limitsSink) RateLimits(x usage.Limits) {
	l.mu.Lock()
	l.limits = append(l.limits, x)
	l.mu.Unlock()
}

func window(t *testing.T, l usage.Limits, id string) usage.Window {
	t.Helper()
	for _, w := range l.Windows {
		if w.ID == id {
			return w
		}
	}
	t.Fatalf("no window %q in %+v", id, l)
	return usage.Window{}
}

// End to end: a Claude turn (fake CLI) is recorded once, as Code space,
// with the cost Claude reported.
func TestManagerRecordsTurnUsage(t *testing.T) {
	m, _, f := newTestManager(t, "claude_write_bash.jsonl")
	sink := &fakeUsage{}
	m.SetUsageSink(sink)
	meta, _ := m.Create(CreateParams{Agent: "claude", Cwd: f.dir, Yolo: boolPtr(true)})
	_ = m.Send(meta.ID, "hi", nil)
	waitFor(t, "recorded", func() bool { r, _ := sink.snapshot(); return len(r) == 1 })
	r, _ := sink.snapshot()
	got := r[0]
	if got.Provider != "claude" || got.SessionID != meta.ID || got.Space != usage.SpaceCode ||
		got.Engine != usage.EngineAgent || got.CostUSD == nil || math.Abs(*got.CostUSD-0.0433593) > 1e-9 {
		t.Fatalf("record = %+v", got)
	}
}

func TestRecordTurnSpaceAndSkips(t *testing.T) {
	m := NewManager(t.TempDir())
	sink := &fakeUsage{}
	m.SetUsageSink(sink)
	s := newSession(m, SessionMeta{ID: "a", Agent: "codex", Mode: ModeAssistant, Model: "gpt-5.5"})
	m.mu.Lock()
	m.recordTurnLocked(s, &Usage{InputTokens: 5}) // no turn share: skipped
	m.recordTurnLocked(s, &Usage{Turn: &TurnUsage{}})
	m.recordTurnLocked(s, &Usage{Turn: &TurnUsage{InputTokens: 100, OutputTokens: 7, CachedTokens: 60}})
	m.mu.Unlock()
	waitFor(t, "recorded", func() bool { r, _ := sink.snapshot(); return len(r) == 1 })
	time.Sleep(20 * time.Millisecond)
	r, _ := sink.snapshot()
	if len(r) != 1 || r[0].Space != usage.SpaceAssistant || r[0].Model != "gpt-5.5" || r[0].CachedTokens != 60 || r[0].CostUSD != nil {
		t.Fatalf("records = %+v", r)
	}
	if usageSpace(ModeOneshot) != "" || usageSpace(ModeAgent) != usage.SpaceCode {
		t.Error("space mapping")
	}
}

// Codex reports thread totals: a resumed thread's restored totals (sent
// before the first turn) are the baseline, each turn records its delta.
func TestCodexTurnUsageFromTotals(t *testing.T) {
	s := &recSink{}
	c := &codexConn{sink: s, deltas: map[string]bool{}, cum: usage.NewCumulative(), model: "gpt-5.5"}
	tok := func(in, out, cached int) json.RawMessage {
		b, _ := json.Marshal(map[string]any{"tokenUsage": map[string]any{
			"total": map[string]any{"inputTokens": in, "outputTokens": out, "cachedInputTokens": cached},
			"last":  map[string]any{"totalTokens": 1}}})
		return b
	}
	c.onNotify("thread/tokenUsage/updated", tok(15562, 5, 12288)) // restored history
	c.onNotify("turn/started", json.RawMessage(`{"turn":{"id":"t2"}}`))
	c.onNotify("thread/tokenUsage/updated", tok(31141, 10, 24576))
	c.onNotify("turn/completed", json.RawMessage(`{"turn":{"id":"t2","status":"completed"}}`))
	turn := lastDone(t, s).Usage.Turn
	if turn == nil || turn.InputTokens != 15579 || turn.OutputTokens != 5 || turn.CachedTokens != 12288 || turn.Model != "gpt-5.5" || turn.CostUSD != nil {
		t.Fatalf("turn = %+v", turn)
	}
	// A turn without new usage records nothing.
	c.onNotify("turn/started", json.RawMessage(`{"turn":{"id":"t3"}}`))
	c.onNotify("turn/completed", json.RawMessage(`{"turn":{"id":"t3","status":"failed"}}`))
	if turn := lastDone(t, s).Usage.Turn; turn.InputTokens != 0 || turn.OutputTokens != 0 {
		t.Fatalf("empty turn = %+v", turn)
	}
}

// Claude: per-turn usage from the cumulative modelUsage and total_cost_usd
// (values from a live two-turn `claude -p` session).
func TestClaudeTurnUsageFromTotals(t *testing.T) {
	s := &recSink{}
	c := &claudeConn{sink: s, inMsg: map[string]bool{}, tools: map[string]string{}, cum: usage.NewCumulative()}
	c.onLine([]byte(`{"type":"result","total_cost_usd":0.235017,"usage":{"input_tokens":10,"output_tokens":707},
		"modelUsage":{"claude-haiku-4-5-20251001":{"inputTokens":10,"outputTokens":707,"cacheReadInputTokens":0,"cacheCreationInputTokens":115736,"contextWindow":200000}}}`))
	first := lastDone(t, s).Usage.Turn
	if first.InputTokens != 115746 || first.OutputTokens != 707 || first.Model != "claude-haiku-4-5-20251001" || math.Abs(*first.CostUSD-0.235017) > 1e-9 {
		t.Fatalf("first = %+v", first)
	}
	c.onLine([]byte(`{"type":"result","total_cost_usd":0.2487516,"usage":{"input_tokens":10,"output_tokens":131},
		"modelUsage":{"claude-haiku-4-5-20251001":{"inputTokens":20,"outputTokens":838,"cacheReadInputTokens":115736,"cacheCreationInputTokens":116484,"contextWindow":200000}}}`))
	second := lastDone(t, s).Usage.Turn
	if second.InputTokens != 116494 || second.OutputTokens != 131 || second.CachedTokens != 115736 || math.Abs(*second.CostUSD-0.0137346) > 1e-7 {
		t.Fatalf("second = %+v", second)
	}
}

func TestCodexRateLimitsNotification(t *testing.T) {
	s := &limitsSink{}
	c := &codexConn{sink: s, deltas: map[string]bool{}}
	c.onNotify("account/rateLimits/updated", json.RawMessage(`{"rateLimits":{"limitId":"codex",
		"primary":{"usedPercent":42,"windowDurationMins":300,"resetsAt":1791273000},
		"secondary":{"usedPercent":7,"windowDurationMins":10080,"resetsAt":1791580853}}}`))
	if len(s.limits) != 1 {
		t.Fatalf("limits = %+v", s.limits)
	}
	l := s.limits[0]
	if l.Provider != "codex" || l.Source != "agent" {
		t.Fatalf("limits = %+v", l)
	}
	if w := window(t, l, "5h"); w.UsedPercent != 42 || w.ResetsAt.Unix() != 1791273000 {
		t.Errorf("5h = %+v", w)
	}
	if w := window(t, l, "week"); w.UsedPercent != 7 {
		t.Errorf("week = %+v", w)
	}
}

func TestCodexLimitsMapping(t *testing.T) {
	// Plus plan today: only a weekly window, reported as primary.
	var snap codexRateSnapshot
	_ = json.Unmarshal([]byte(`{"limitId":"codex","primary":{"usedPercent":1,"windowDurationMins":10080,"resetsAt":1791580853},"secondary":null}`), &snap)
	l := codexLimits(snap)
	if len(l.Windows) != 1 || l.Windows[0].ID != "week" {
		t.Fatalf("plus = %+v", l)
	}
	// No durations: primary = 5h, secondary = week; other buckets get a suffix.
	snap = codexRateSnapshot{}
	_ = json.Unmarshal([]byte(`{"limitId":"gpt-5.5-pro","primary":{"usedPercent":3},"secondary":{"usedPercent":4,"windowDurationMins":1440}}`), &snap)
	l = codexLimits(snap)
	if window(t, l, "5h_gpt-5.5-pro").UsedPercent != 3 || window(t, l, "1d_gpt-5.5-pro").UsedPercent != 4 {
		t.Fatalf("buckets = %+v", l)
	}
	if !l.Windows[0].ResetsAt.IsZero() {
		t.Error("missing resetsAt must stay zero")
	}
	// No sink support: nothing happens (and nothing panics).
	reportLimits(&recSink{}, l)
}

// rate_limit_event as printed by Claude Code 2.1 (utilization is 0-1).
func TestClaudeRateLimitEvent(t *testing.T) {
	s := &limitsSink{}
	c := &claudeConn{sink: s, inMsg: map[string]bool{}, tools: map[string]string{}}
	c.onLine([]byte(`{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","resetsAt":1791273000,"rateLimitType":"five_hour",
		"unifiedWindows":{"five_hour":{"utilization":0.13,"resetsAt":1791273000},"seven_day":{"utilization":0.4,"resetsAt":1791662400}}}}`))
	if len(s.limits) != 1 || s.limits[0].Provider != "claude" || len(s.limits[0].Windows) != 2 {
		t.Fatalf("limits = %+v", s.limits)
	}
	if w := window(t, s.limits[0], "5h"); math.Abs(w.UsedPercent-13) > 1e-9 || w.ResetsAt.Unix() != 1791273000 {
		t.Errorf("5h = %+v", w)
	}
	if w := window(t, s.limits[0], "week"); math.Abs(w.UsedPercent-40) > 1e-9 {
		t.Errorf("week = %+v", w)
	}
	// Older form: a single window with its utilization; no utilization = nothing.
	l := claudeRateLimits(map[string]any{"rateLimitType": "seven_day_opus", "utilization": 0.9})
	if len(l.Windows) != 1 || l.Windows[0].ID != "week_opus" || math.Abs(l.Windows[0].UsedPercent-90) > 1e-9 {
		t.Fatalf("single = %+v", l)
	}
	if l := claudeRateLimits(map[string]any{"rateLimitType": "five_hour", "status": "allowed"}); len(l.Windows) != 0 {
		t.Fatalf("no utilization = %+v", l)
	}
}

// The manager's sink forwards limits to the usage service.
func TestSessionSinkForwardsLimits(t *testing.T) {
	m := NewManager(t.TempDir())
	u := &fakeUsage{}
	m.SetUsageSink(u)
	k := &sessionSink{s: newSession(m, SessionMeta{ID: "x", Agent: "codex"})}
	reportLimits(k, usage.Limits{Provider: "codex", Windows: []usage.Window{{ID: "5h", UsedPercent: 50}}})
	waitFor(t, "limits", func() bool { _, l := u.snapshot(); return len(l) == 1 })
	if _, l := u.snapshot(); l[0].Source != "agent" {
		t.Errorf("limits = %+v", l)
	}
}
