package agents

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"sync"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/svc/usage"
)

// Codex: `codex app-server` (stdio JSON-RPC, protocol v2). One thread per
// session; each send is a turn/start. Approvals arrive as server requests
// (item/commandExecution/requestApproval, item/fileChange/requestApproval).
type codexAdapter struct{}

func init() { Register(codexAdapter{}) }

func (codexAdapter) ID() string            { return "codex" }
func (codexAdapter) Label() string         { return "Codex" }
func (codexAdapter) DefaultBinary() string { return "codex" }
func (codexAdapter) VersionArgs() []string { return []string{"--version"} }
func (codexAdapter) Notes() string {
	return "Uses your Codex login via `codex app-server`. Approval policy \"untrusted\" + workspace-write sandbox; YOLO = approval \"never\" + full access. Resume via thread/resume."
}
func (codexAdapter) Capabilities() Capabilities {
	return Capabilities{Resume: true, Images: true, InteractivePermissions: true, MCP: true, Interrupt: true}
}

// tomlValue renders a Go value as an inline TOML value for `-c key=value`.
func tomlValue(v any) string {
	switch t := v.(type) {
	case string:
		b, _ := json.Marshal(t) // JSON strings are valid TOML basic strings
		return string(b)
	case []string:
		parts := make([]string, len(t))
		for i, s := range t {
			parts[i] = tomlValue(s)
		}
		return "[" + strings.Join(parts, ", ") + "]"
	case map[string]string:
		keys := make([]string, 0, len(t))
		for k := range t {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		parts := make([]string, len(keys))
		for i, k := range keys {
			parts[i] = tomlValue(k) + " = " + tomlValue(t[k])
		}
		return "{" + strings.Join(parts, ", ") + "}"
	}
	return `""`
}

// codexArgs builds the command line and the extra environment. MCP env
// values and headers can be tokens, so they never go into `-c` (argv):
// stdio env is forwarded by name (env_vars) from Codex's own environment,
// and headers are read from private variables (env_http_headers) whose
// names contain SECRET, which Codex's default shell policy keeps away from
// the commands it runs.
func codexArgs(o StartOptions) ([]string, []string, error) {
	args := []string{"app-server"}
	if o.Mode == "oneshot" {
		return append(args, codexQuickArgs()...), nil, nil
	}
	var env []string
	vals := map[string]string{}
	for i, s := range o.MCP {
		key := "mcp_servers." + tomlValue(s.Name)
		if s.Transport == "http" || s.Transport == "sse" {
			args = append(args, "-c", key+".url="+tomlValue(s.URL))
			if len(s.Headers) > 0 {
				names := map[string]string{}
				for j, h := range sortedKeys(s.Headers) {
					name := fmt.Sprintf("%sMCP_SECRET_%d_%d", brand.EnvPrefix, i, j)
					names[h] = name
					env = append(env, name+"="+s.Headers[h])
				}
				args = append(args, "-c", key+".env_http_headers="+tomlValue(names))
			}
			continue
		}
		args = append(args, "-c", key+".command="+tomlValue(s.Command), "-c", key+".args="+tomlValue(nonNil(s.Args)))
		if len(s.Env) > 0 {
			names := sortedKeys(s.Env)
			for _, k := range names {
				if v, seen := vals[k]; seen && v != s.Env[k] {
					return nil, nil, fmt.Errorf("MCP servers need different values for %s; Codex can only pass one", k)
				}
				vals[k] = s.Env[k]
			}
			args = append(args, "-c", key+".env_vars="+tomlValue(names))
		}
	}
	for _, k := range sortedKeys(vals) {
		env = append(env, k+"="+vals[k])
	}
	return append(args, o.ExtraArgs...), env, nil
}

func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

type codexConn struct {
	p      *proc
	rpc    *rpcPeer
	opts   StartOptions
	sink   Sink
	mu     sync.Mutex
	thread string
	turn   string
	queue  []func()
	ready  bool
	deltas map[string]bool // agentMessage ids that streamed deltas
	sep    bool            // a message ended; separate the next one
	usage  *Usage
	cum    *usage.Cumulative // thread totals -> per-turn usage
	model  string            // model the thread runs (start/resume result)
	total  *[3]int64         // latest thread totals: input, output, cached
}

func (codexAdapter) Start(_ context.Context, o StartOptions, sink Sink) (Conn, error) {
	c := &codexConn{opts: o, sink: sink, deltas: map[string]bool{}, cum: usage.NewCumulative()}
	args, env, err := codexArgs(o)
	if err != nil {
		return nil, err
	}
	p, err := startProc(o.Binary, args, o.Cwd, append(append([]string{}, o.Env...), env...), func(l []byte) { c.rpc.Handle(l) }, sink.Exited)
	if err != nil {
		return nil, err
	}
	c.p = p
	c.rpc = newRPCPeer(p.writeJSON)
	c.rpc.onNotify = c.onNotify
	c.rpc.onRequest = c.onRequest
	// Pipelined handshake (the server processes requests in order).
	_ = c.rpc.Call("initialize", map[string]any{"clientInfo": map[string]any{"name": brand.AppID, "title": brand.DisplayName, "version": "1.0"}}, nil)
	_ = c.rpc.Notify("initialized", nil)
	if o.Mode != "oneshot" {
		// Limits show before the first turn, then refresh while alive.
		c.readLimits()
		go c.pollLimits()
	}
	params := map[string]any{"cwd": o.Cwd, "approvalPolicy": c.approval(), "approvalsReviewer": "user", "sandbox": c.sandbox()}
	if o.Model != "" {
		params["model"] = o.Model
	}
	if o.SystemPrompt != "" {
		params["developerInstructions"] = o.SystemPrompt
	}
	open := func() error { return c.openThread(params, o.ResumeID) }
	if o.Mode == "oneshot" {
		open = func() error { return c.openQuickThread(params) }
	}
	if err := open(); err != nil {
		p.stop()
		return nil, err
	}
	return c, nil
}

// openThread starts or resumes a thread. A failed resume preserves its identity;
// a failed start ends the pending turn and stops the process,
// so the session never stays "running" with nothing behind it.
func (c *codexConn) openThread(params map[string]any, resumeID string) error {
	method := "thread/start"
	if resumeID != "" {
		method = "thread/resume"
		params["threadId"] = resumeID
	}
	return c.rpc.Call(method, params, func(res json.RawMessage, e *rpcError) {
		if e != nil {
			c.sink.Emit(Event{Kind: KindError, Message: "codex: " + e.Message})
			c.failStart()
			return
		}
		var r struct {
			Thread struct {
				ID string `json:"id"`
			} `json:"thread"`
			Model string `json:"model"`
		}
		_ = json.Unmarshal(res, &r)
		c.mu.Lock()
		c.thread = r.Thread.ID
		c.model = r.Model
		c.ready = true
		q := c.queue
		c.queue = nil
		c.mu.Unlock()
		if r.Thread.ID != "" {
			c.sink.SetAgentSessionID(r.Thread.ID)
		}
		for _, f := range q {
			f()
		}
	})
}

// failStart drops queued turns, ends the turn and stops the process.
func (c *codexConn) failStart() {
	c.mu.Lock()
	c.queue = nil
	c.mu.Unlock()
	c.sink.Emit(Event{Kind: KindDone})
	go c.p.stop()
}

func (c *codexConn) approval() string {
	if c.opts.Mode == "oneshot" {
		return "never"
	}
	if c.opts.yolo() {
		return "never"
	}
	return "untrusted"
}

func (c *codexConn) sandbox() string {
	if c.opts.Mode == "oneshot" {
		return "read-only"
	}
	if c.opts.yolo() {
		return "danger-full-access"
	}
	if c.opts.Mode == ModeAssistant {
		// Writes and commands outside the read-only sandbox ask first.
		return "read-only"
	}
	return "workspace-write"
}

func (c *codexConn) Send(text string, images []string) error {
	run := func() {
		input := []any{map[string]any{"type": "text", "text": text}}
		for _, img := range images {
			input = append(input, map[string]any{"type": "localImage", "path": img})
		}
		c.mu.Lock()
		thread := c.thread
		c.mu.Unlock()
		params := map[string]any{"threadId": thread, "input": input, "approvalPolicy": c.approval()}
		if c.opts.Mode == "oneshot" {
			params["sandboxPolicy"] = codexQuickSandbox()
		}
		if c.opts.Model != "" {
			params["model"] = c.opts.Model
		}
		if c.opts.Effort != "" {
			params["effort"] = c.opts.Effort
		}
		err := c.rpc.Call("turn/start", params,
			func(res json.RawMessage, e *rpcError) {
				if e != nil {
					c.sink.Emit(Event{Kind: KindError, Message: "codex: " + e.Message})
					c.sink.Emit(Event{Kind: KindDone})
					return
				}
				var r struct {
					Turn struct {
						ID string `json:"id"`
					} `json:"turn"`
				}
				if json.Unmarshal(res, &r) == nil && r.Turn.ID != "" {
					c.mu.Lock()
					c.turn = r.Turn.ID
					c.mu.Unlock()
				}
			})
		if err != nil {
			c.sink.Emit(Event{Kind: KindError, Message: err.Error()})
		}
	}
	c.mu.Lock()
	if !c.ready {
		c.queue = append(c.queue, run)
		c.mu.Unlock()
		return nil
	}
	c.mu.Unlock()
	run()
	return nil
}

func (c *codexConn) Interrupt() error {
	c.mu.Lock()
	thread, turn := c.thread, c.turn
	c.mu.Unlock()
	if turn == "" {
		return nil
	}
	return c.rpc.Call("turn/interrupt", map[string]any{"threadId": thread, "turnId": turn}, nil)
}

func (c *codexConn) Close() error { c.p.stop(); return nil }

func (c *codexConn) rel(p string) string {
	if c.opts.Cwd != "" && strings.HasPrefix(p, c.opts.Cwd+"/") {
		return strings.TrimPrefix(p, c.opts.Cwd+"/")
	}
	return p
}

// commandCategory classifies a Codex command. Codex's own parse
// (commandActions) can only downgrade: a command is a read when Codex says
// so AND it passes IsSafeCommand, never on Codex's word alone.
func commandCategory(cmd string, actions []map[string]any) string {
	for _, a := range actions {
		switch a["type"] {
		case "read", "listFiles", "search":
		default:
			return CatExec
		}
	}
	if IsSafeCommand(cmd) {
		return CatRead
	}
	return CatExec
}

func (c *codexConn) onNotify(method string, params json.RawMessage) {
	var p struct {
		Item   codexItem `json:"item"`
		ItemID string    `json:"itemId"`
		Delta  string    `json:"delta"`
		TurnID string    `json:"turnId"`
		Diff   string    `json:"diff"`
		Turn   struct {
			ID     string `json:"id"`
			Status string `json:"status"`
			Error  *struct {
				Message string `json:"message"`
			} `json:"error"`
		} `json:"turn"`
		Thread struct {
			ID string `json:"id"`
		} `json:"thread"`
		Error struct {
			Message string `json:"message"`
		} `json:"error"`
		WillRetry  bool `json:"willRetry"`
		TokenUsage struct {
			Total struct {
				InputTokens       int64 `json:"inputTokens"`
				OutputTokens      int64 `json:"outputTokens"`
				CachedInputTokens int64 `json:"cachedInputTokens"`
			} `json:"total"`
			Last struct {
				TotalTokens int64 `json:"totalTokens"`
			} `json:"last"`
			ModelContextWindow int64 `json:"modelContextWindow"`
		} `json:"tokenUsage"`
		RateLimits *codexRateSnapshot `json:"rateLimits"`
	}
	_ = json.Unmarshal(params, &p)
	switch method {
	case "turn/started":
		c.mu.Lock()
		c.turn = p.Turn.ID
		c.mu.Unlock()
	case "item/agentMessage/delta":
		if p.Delta != "" {
			c.deltas[p.ItemID] = true
			c.text(p.Delta)
		}
	case "item/reasoning/summaryTextDelta", "item/reasoning/textDelta":
		if p.Delta != "" {
			c.sink.Emit(Event{Kind: KindThinking, Text: p.Delta, Delta: true})
		}
	case "item/reasoning/summaryPartAdded":
		c.sink.Emit(Event{Kind: KindThinking, Text: "\n\n", Delta: true})
	case "item/started":
		c.itemStarted(p.Item)
	case "item/completed":
		c.itemCompleted(p.Item)
	case "turn/diff/updated":
		if p.Diff != "" {
			c.sink.Emit(Event{Kind: KindDiff, ID: "turn:" + p.TurnID, Diff: p.Diff})
		}
	case "thread/tokenUsage/updated":
		// total is the whole thread; last is the latest request, which is
		// what currently fills the context window.
		c.usage = &Usage{InputTokens: p.TokenUsage.Total.InputTokens, OutputTokens: p.TokenUsage.Total.OutputTokens,
			ContextTokens: p.TokenUsage.Last.TotalTokens, ContextWindow: p.TokenUsage.ModelContextWindow}
		tot := p.TokenUsage.Total
		c.total = &[3]int64{tot.InputTokens, tot.OutputTokens, tot.CachedInputTokens}
		c.mu.Lock()
		inTurn := c.turn != ""
		c.mu.Unlock()
		if !inTurn && c.cum != nil {
			// A resumed thread reports its restored totals before the
			// first turn: they are the baseline, not this turn's usage.
			c.cum.Delta(usage.Record{InputTokens: tot.InputTokens, OutputTokens: tot.OutputTokens, CachedTokens: tot.CachedInputTokens})
		}
	case "account/rateLimits/updated":
		if p.RateLimits != nil {
			reportLimits(c.sink, codexLimits(*p.RateLimits))
		}
	case "error":
		if !p.WillRetry && p.Error.Message != "" {
			c.sink.Emit(Event{Kind: KindError, Message: p.Error.Message})
		}
	case "turn/completed":
		if p.Turn.Status == "failed" && p.Turn.Error != nil {
			c.sink.Emit(Event{Kind: KindError, Message: p.Turn.Error.Message})
		}
		c.mu.Lock()
		c.turn = ""
		c.mu.Unlock()
		c.sep = false
		if c.usage != nil && c.total != nil {
			u := *c.usage
			c.mu.Lock()
			model := c.model
			c.mu.Unlock()
			u.Turn = turnFrom(c.cum, model, c.total[0], c.total[1], c.total[2], 0)
			c.usage = &u
		}
		c.sink.Emit(Event{Kind: KindDone, Usage: c.usage})
	}
}

func (c *codexConn) text(t string) {
	if c.sep {
		t = "\n\n" + t
		c.sep = false
	}
	c.sink.Emit(Event{Kind: KindText, Text: t, Delta: true})
}
