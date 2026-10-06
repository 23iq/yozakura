package usage

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/ipc"
)

type notes struct {
	mu   sync.Mutex
	list []string
}

func (n *notes) add(summary, _ string) {
	n.mu.Lock()
	n.list = append(n.list, summary)
	n.mu.Unlock()
}

func (n *notes) count() int {
	n.mu.Lock()
	defer n.mu.Unlock()
	return len(n.list)
}

func testService(t *testing.T, fetch func(context.Context) (Limits, error)) (*Service, *notes) {
	n := &notes{}
	now := at("2026-10-06 10:00")
	s := NewService(Options{
		Dir:         t.TempDir(),
		Prices:      &PriceTable{Providers: map[string]map[string]Price{"openai": {"gpt-4o": {Input: 2.5, Output: 10}}}, Free: []string{"ollama"}},
		Notify:      n.add,
		ClaudeFetch: fetch,
		Now:         func() time.Time { return now },
	})
	t.Cleanup(s.Close)
	return s, n
}

func TestServiceRecordEstimates(t *testing.T) {
	s, _ := testService(t, nil)
	r, err := s.Record(Record{Provider: "openai", Model: "gpt-4o", InputTokens: 1_000_000, OutputTokens: 100_000, Space: SpaceAssistant, Engine: EngineHTTP})
	require.NoError(t, err)
	require.NotNil(t, r.CostUSD)
	assert.InDelta(t, 3.5, *r.CostUSD, 1e-9)
	assert.True(t, r.Estimated)

	r, err = s.Record(Record{Provider: "claude", Model: "x", CostUSD: ptr(0.42), Estimated: true, Engine: EngineAgent})
	require.NoError(t, err)
	assert.False(t, r.Estimated) // reported cost
	assert.InDelta(t, 0.42, *r.CostUSD, 1e-9)

	r, err = s.Record(Record{Provider: "custom", Model: "unknown", InputTokens: 5})
	require.NoError(t, err)
	assert.Nil(t, r.CostUSD)

	r, err = s.Record(Record{Provider: "ollama", Model: "llama3", InputTokens: 5})
	require.NoError(t, err)
	assert.Equal(t, 0.0, *r.CostUSD)

	_, err = s.Record(Record{})
	assert.Error(t, err)

	sum, err := s.Ledger().Summary(SummaryQuery{}, at("2026-10-06 12:00"))
	require.NoError(t, err)
	assert.Equal(t, 4, sum.Totals.Requests)
	assert.Equal(t, 1, sum.Totals.Unpriced)
}

func TestServiceLimitsNotifyOnce(t *testing.T) {
	s, n := testService(t, nil)
	reset := at("2026-10-06 12:00")
	require.NoError(t, s.SetLimits(Limits{Provider: "codex", Windows: []Window{{ID: "5h", UsedPercent: 85, ResetsAt: reset}}}))
	require.NoError(t, s.SetLimits(Limits{Provider: "codex", Windows: []Window{{ID: "5h", UsedPercent: 87, ResetsAt: reset}}}))
	assert.Equal(t, 1, n.count())

	// The marker persists in the ledger dir: a new service does not repeat it.
	s2 := NewService(Options{Dir: s.Ledger().Dir(), Notify: n.add})
	require.NoError(t, s2.SetLimits(Limits{Provider: "codex", Windows: []Window{{ID: "5h", UsedPercent: 88, ResetsAt: reset}}}))
	assert.Equal(t, 1, n.count())
	require.NoError(t, s2.SetLimits(Limits{Provider: "codex", Windows: []Window{{ID: "5h", UsedPercent: 90, ResetsAt: reset}}}))
	assert.Equal(t, 2, n.count())
}

// ipcHarness runs the service on a real socket.
type ipcHarness struct {
	sock   string
	events chan ipc.ServiceEvent
}

func startIPC(t *testing.T, s *Service) *ipcHarness {
	sock := filepath.Join(t.TempDir(), "u.sock")
	srv := ipc.NewServer(sock)
	s.Register(srv)
	require.NoError(t, srv.Listen())
	t.Cleanup(srv.Close)
	go func() { _ = srv.Serve() }()
	return &ipcHarness{sock: sock, events: make(chan ipc.ServiceEvent, 16)}
}

func (h *ipcHarness) subscribe(t *testing.T) net.Conn {
	conn, err := net.Dial("unix", h.sock)
	require.NoError(t, err)
	t.Cleanup(func() { conn.Close() })
	_, err = conn.Write([]byte(`{"id":1,"method":"subscribe","params":{"services":["usage"]}}` + "\n"))
	require.NoError(t, err)
	go func() {
		sc := bufio.NewScanner(conn)
		for sc.Scan() {
			var resp ipc.Response
			var ev ipc.ServiceEvent
			if json.Unmarshal(sc.Bytes(), &resp) == nil && json.Unmarshal(resp.Result, &ev) == nil && ev.Service != "" {
				h.events <- ev
			}
		}
	}()
	return conn
}

func (h *ipcHarness) next(t *testing.T, name string) map[string]any {
	t.Helper()
	deadline := time.After(3 * time.Second)
	for {
		select {
		case ev := <-h.events:
			if ev.Service == name {
				data, _ := json.Marshal(ev.Data)
				var m map[string]any
				_ = json.Unmarshal(data, &m)
				return m
			}
		case <-deadline:
			t.Fatalf("no %s event", name)
		}
	}
}

func TestServiceIPC(t *testing.T) {
	s, _ := testService(t, nil)
	h := startIPC(t, s)
	h.subscribe(t)
	h.next(t, "usage.limits") // initial snapshot

	c := ipc.NewClient(h.sock)
	_, err := c.Call("usage.record", map[string]any{"provider": "openai", "model": "gpt-4o", "sessionId": "s1", "inputTokens": 1000, "outputTokens": 10})
	require.NoError(t, err)
	ev := h.next(t, "usage.updated")
	assert.Equal(t, "openai", ev["record"].(map[string]any)["provider"])
	assert.EqualValues(t, 1, ev["session"].(map[string]any)["requests"])

	raw, err := c.Call("usage.summary", map[string]any{"range": "today", "groupBy": "model"})
	require.NoError(t, err)
	var sum Summary
	require.NoError(t, json.Unmarshal(raw, &sum))
	require.Len(t, sum.Rows, 1)
	assert.Equal(t, "gpt-4o", sum.Rows[0].Key)

	raw, err = c.Call("usage.session", map[string]any{"sessionId": "s1"})
	require.NoError(t, err)
	assert.Contains(t, string(raw), `"inputTokens":1000`)

	_, err = c.Call("usage.limits.set", map[string]any{"provider": "codex", "source": "agent", "windows": []any{map[string]any{"id": "5h", "usedPercent": 12}}})
	require.NoError(t, err)
	ev = h.next(t, "usage.limits")
	assert.Equal(t, "codex", ev["provider"])
	raw, err = c.Call("usage.limits.get", map[string]any{"provider": "codex"})
	require.NoError(t, err)
	assert.Contains(t, string(raw), `"usedPercent":12`)

	_, err = c.Call("usage.claudeLimits.enable", map[string]any{})
	assert.Error(t, err)
	raw, err = c.Call("usage.claudeLimits.enable", map[string]any{"enabled": true})
	require.NoError(t, err)
	assert.Contains(t, string(raw), `"available":false`)
}

func TestClaudePollingNeedsEnableAndSubscriber(t *testing.T) {
	var mu sync.Mutex
	calls := 0
	fetch := func(context.Context) (Limits, error) {
		mu.Lock()
		calls++
		mu.Unlock()
		return Limits{Provider: ClaudeProvider, Source: "oauth", Windows: []Window{{ID: "5h", UsedPercent: 4}}}, nil
	}
	s, _ := testService(t, fetch)
	h := startIPC(t, s)
	s.SetClaudeLimitsEnabled(true)
	assert.False(t, s.poller.Running(), "no subscriber yet")

	conn := h.subscribe(t)
	h.next(t, "usage.limits")
	ev := h.next(t, "usage.limits") // the first fetch is published
	assert.Equal(t, ClaudeProvider, ev["provider"])
	assert.True(t, s.poller.Running())

	s.SetClaudeLimitsEnabled(false)
	assert.False(t, s.poller.Running())
	s.SetClaudeLimitsEnabled(true)
	assert.True(t, s.poller.Running())

	// The IPC server notices a closed subscriber on its next write.
	conn.Close()
	require.Eventually(t, func() bool {
		_ = s.SetLimits(Limits{Provider: "codex", Windows: []Window{{ID: "5h", UsedPercent: 1}}})
		return !s.poller.Running()
	}, 3*time.Second, 10*time.Millisecond)
	mu.Lock()
	assert.Equal(t, 1, calls, "re-enabling within the interval must not refetch")
	mu.Unlock()
}
