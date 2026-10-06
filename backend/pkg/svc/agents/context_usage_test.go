package agents

import (
	"encoding/json"
	"testing"
)

func lastDone(t *testing.T, s *recSink) Event {
	t.Helper()
	evs, _, _ := s.snapshot()
	for i := len(evs) - 1; i >= 0; i-- {
		if evs[i].Kind == KindDone {
			return evs[i]
		}
	}
	t.Fatal("no done event")
	return Event{}
}

// Codex: thread/tokenUsage/updated carries the thread total, the last
// request (what fills the window) and the model's context window.
func TestCodexContextUsage(t *testing.T) {
	s := &recSink{}
	c := &codexConn{sink: s, deltas: map[string]bool{}}
	c.onNotify("thread/tokenUsage/updated", json.RawMessage(`{"threadId":"t","turnId":"u","tokenUsage":{
		"total":{"inputTokens":90000,"cachedInputTokens":50000,"outputTokens":3000,"reasoningOutputTokens":0,"totalTokens":93000},
		"last":{"inputTokens":61000,"cachedInputTokens":40000,"outputTokens":1200,"reasoningOutputTokens":0,"totalTokens":62200},
		"modelContextWindow":258400}}`))
	c.onNotify("turn/completed", json.RawMessage(`{"turn":{"id":"u","status":"completed"}}`))
	u := lastDone(t, s).Usage
	if u == nil || u.InputTokens != 90000 || u.OutputTokens != 3000 || u.ContextTokens != 62200 || u.ContextWindow != 258400 {
		t.Fatalf("usage = %+v", u)
	}
}

// A Codex build without modelContextWindow still reports the tokens; the
// window stays 0 (unknown) and is omitted from the JSON.
func TestCodexContextUsageWithoutWindow(t *testing.T) {
	s := &recSink{}
	c := &codexConn{sink: s, deltas: map[string]bool{}}
	c.onNotify("thread/tokenUsage/updated", json.RawMessage(`{"tokenUsage":{"total":{"inputTokens":10,"outputTokens":2},"last":{"totalTokens":12}}}`))
	c.onNotify("turn/completed", json.RawMessage(`{"turn":{"id":"u","status":"completed"}}`))
	u := lastDone(t, s).Usage
	if u.ContextTokens != 12 || u.ContextWindow != 0 {
		t.Fatalf("usage = %+v", u)
	}
	data, _ := json.Marshal(u)
	var m map[string]any
	_ = json.Unmarshal(data, &m)
	if _, ok := m["contextWindow"]; ok {
		t.Errorf("unknown window must be omitted: %s", data)
	}
}

// Claude: the last main-thread assistant message gives the context size
// (prompt incl. cache reads/writes + output); the result's modelUsage gives
// the window of the model that did the work (not the small helper model).
func TestClaudeContextUsage(t *testing.T) {
	s := &recSink{}
	c := &claudeConn{sink: s, inMsg: map[string]bool{}, tools: map[string]string{}}
	lines := []string{
		`{"type":"assistant","parent_tool_use_id":null,"message":{"id":"m1","content":[],"usage":{"input_tokens":5,"cache_read_input_tokens":1000,"cache_creation_input_tokens":200,"output_tokens":40}}}`,
		// a sub-agent's message does not count
		`{"type":"assistant","parent_tool_use_id":"toolu_1","message":{"id":"m2","content":[],"usage":{"input_tokens":99999,"output_tokens":1}}}`,
		`{"type":"assistant","parent_tool_use_id":null,"message":{"id":"m3","content":[],"usage":{"input_tokens":10,"cache_read_input_tokens":13796,"cache_creation_input_tokens":14542,"output_tokens":4}}}`,
		`{"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.03,"usage":{"input_tokens":15,"output_tokens":80},
		  "modelUsage":{"claude-haiku-4-5":{"inputTokens":300,"contextWindow":100000},
		                "claude-sonnet-4-5":{"inputTokens":10,"cacheReadInputTokens":13796,"cacheCreationInputTokens":14542,"contextWindow":200000}}}`,
	}
	for _, l := range lines {
		c.onLine([]byte(l))
	}
	u := lastDone(t, s).Usage
	if u == nil || u.ContextTokens != 10+13796+14542+4 || u.ContextWindow != 200000 || u.OutputTokens != 80 {
		t.Fatalf("usage = %+v", u)
	}
}

func TestClaudeContextWindowEmpty(t *testing.T) {
	if w := claudeContextWindow(nil); w != 0 {
		t.Fatalf("window = %d", w)
	}
}
