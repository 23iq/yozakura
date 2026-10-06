package agents

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"mime"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
)

// acpSpec configures the generic Agent Client Protocol adapter for one
// agent (OpenCode, or any other `--acp` capable CLI).
type acpSpec struct {
	id, label, binary, notes string
	args                     func(o StartOptions) []string
	env                      func(o StartOptions) []string
}

// acpAdapter drives an ACP agent over stdio JSON-RPC:
// initialize -> session/new|session/load -> [session/set_config_option]
// -> session/prompt (one per turn); session/cancel interrupts;
// session/request_permission is answered with the selected option.
type acpAdapter struct{ spec acpSpec }

func (a acpAdapter) ID() string            { return a.spec.id }
func (a acpAdapter) Label() string         { return a.spec.label }
func (a acpAdapter) DefaultBinary() string { return a.spec.binary }
func (a acpAdapter) VersionArgs() []string { return []string{"--version"} }
func (a acpAdapter) Notes() string         { return a.spec.notes }
func (a acpAdapter) Capabilities() Capabilities {
	return Capabilities{Resume: true, Images: true, InteractivePermissions: true, MCP: true, Interrupt: true}
}

type acpConn struct {
	p        *proc
	rpc      *rpcPeer
	opts     StartOptions
	sink     Sink
	mu       sync.Mutex
	session  string
	ready    bool
	loading  bool // session/load replays history; it is already in our log
	queue    []func()
	imageCap bool
	tools    map[string]*acpTool
}

type acpTool struct {
	title, kind string
	input       map[string]any
	emitted     bool
	done        bool
}

func acpMCPServers(list []MCPServer) []any {
	out := []any{}
	pairs := func(m map[string]string) []any {
		keys := make([]string, 0, len(m))
		for k := range m {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		ps := []any{}
		for _, k := range keys {
			ps = append(ps, map[string]any{"name": k, "value": m[k]})
		}
		return ps
	}
	for _, s := range list {
		if s.Transport == "http" || s.Transport == "sse" {
			out = append(out, map[string]any{"type": s.Transport, "name": s.Name, "url": s.URL, "headers": pairs(s.Headers)})
			continue
		}
		out = append(out, map[string]any{"name": s.Name, "command": s.Command, "args": nonNil(s.Args), "env": pairs(s.Env)})
	}
	return out
}

func (a acpAdapter) Start(_ context.Context, o StartOptions, sink Sink) (Conn, error) {
	c := &acpConn{opts: o, sink: sink, tools: map[string]*acpTool{}}
	var env []string
	if a.spec.env != nil {
		env = a.spec.env(o)
	}
	env = append(env, o.Env...)
	p, err := startProc(o.Binary, a.spec.args(o), o.Cwd, env, func(l []byte) { c.rpc.Handle(l) }, sink.Exited)
	if err != nil {
		return nil, err
	}
	c.p = p
	c.rpc = newRPCPeer(p.writeJSON)
	c.rpc.onNotify = c.onNotify
	c.rpc.onRequest = c.onRequest
	fail := func(what string, e *rpcError) bool {
		if e == nil {
			return false
		}
		sink.Emit(Event{Kind: KindError, Message: a.spec.label + " " + what + ": " + e.Message})
		return true
	}
	err = c.rpc.Call("initialize", map[string]any{"protocolVersion": 1, "clientCapabilities": map[string]any{
		"fs": map[string]any{"readTextFile": false, "writeTextFile": false}, "terminal": false}},
		func(res json.RawMessage, e *rpcError) {
			if fail("initialize", e) {
				c.failStart()
				return
			}
			var r struct {
				AgentCapabilities struct {
					LoadSession        bool `json:"loadSession"`
					PromptCapabilities struct {
						Image bool `json:"image"`
					} `json:"promptCapabilities"`
				} `json:"agentCapabilities"`
			}
			_ = json.Unmarshal(res, &r)
			c.imageCap = r.AgentCapabilities.PromptCapabilities.Image
			resume := ""
			if o.ResumeID != "" && !r.AgentCapabilities.LoadSession {
				sink.Emit(Event{Kind: KindError, Message: "agent does not support native session resume"})
				c.failStart()
				return
			}
			if o.ResumeID != "" && r.AgentCapabilities.LoadSession {
				resume = o.ResumeID
			}
			if err := c.openSession(resume, fail); err != nil {
				c.failStart()
			}
		})
	if err != nil {
		p.stop()
		return nil, err
	}
	return c, nil
}

// openSession creates a session or loads resumeID; failures end the turn.
func (c *acpConn) openSession(resumeID string, fail func(string, *rpcError) bool) error {
	o := c.opts
	params := map[string]any{"cwd": o.Cwd, "mcpServers": acpMCPServers(o.MCP)}
	method := "session/new"
	if resumeID != "" {
		method = "session/load"
		params["sessionId"] = resumeID
		c.mu.Lock()
		c.session = resumeID
		c.loading = true
		c.mu.Unlock()
	}
	return c.rpc.Call(method, params, func(res json.RawMessage, e *rpcError) {
		c.mu.Lock()
		c.loading = false
		c.mu.Unlock()
		if fail(method, e) {
			c.failStart()
			return
		}
		var s struct {
			SessionID     string            `json:"sessionId"`
			ConfigOptions []acpConfigOption `json:"configOptions"`
		}
		_ = json.Unmarshal(res, &s)
		c.mu.Lock()
		if s.SessionID != "" {
			c.session = s.SessionID
		}
		sid := c.session
		c.mu.Unlock()
		c.sink.SetAgentSessionID(sid)
		c.applySettings(sid, s.ConfigOptions)
	})
}

// failStart drops queued prompts, ends the turn and stops the process, so
// the session never stays "running" after a failed handshake.
func (c *acpConn) failStart() {
	c.mu.Lock()
	c.queue = nil
	c.mu.Unlock()
	c.sink.Emit(Event{Kind: KindDone})
	go c.p.stop()
}

func (c *acpConn) markReady() {
	c.mu.Lock()
	c.ready = true
	q := c.queue
	c.queue = nil
	c.mu.Unlock()
	for _, f := range q {
		f()
	}
}

func (c *acpConn) Send(text string, images []string) error {
	run := func() {
		prompt := []any{}
		if c.opts.SystemPrompt != "" && c.opts.Mode == ModeAssistant {
			text = c.opts.SystemPrompt + "\n\n" + text
		}
		if c.imageCap {
			for _, img := range images {
				data, err := os.ReadFile(img)
				if err != nil {
					continue
				}
				mt := mime.TypeByExtension(strings.ToLower(filepath.Ext(img)))
				if mt == "" {
					mt = "image/png"
				}
				prompt = append(prompt, map[string]any{"type": "image", "mimeType": mt, "data": base64.StdEncoding.EncodeToString(data)})
			}
		}
		prompt = append(prompt, map[string]any{"type": "text", "text": text})
		c.mu.Lock()
		sid := c.session
		c.mu.Unlock()
		err := c.rpc.Call("session/prompt", map[string]any{"sessionId": sid, "prompt": prompt}, func(res json.RawMessage, e *rpcError) {
			if e != nil {
				c.sink.Emit(Event{Kind: KindError, Message: e.Message})
				c.sink.Emit(Event{Kind: KindDone})
				return
			}
			var r struct {
				StopReason string `json:"stopReason"`
				Usage      struct {
					InputTokens       int64 `json:"inputTokens"`
					OutputTokens      int64 `json:"outputTokens"`
					CachedReadTokens  int64 `json:"cachedReadTokens"`
					CachedWriteTokens int64 `json:"cachedWriteTokens"`
				} `json:"usage"`
			}
			_ = json.Unmarshal(res, &r)
			if r.StopReason == "refusal" {
				c.sink.Emit(Event{Kind: KindError, Message: "The agent refused to continue."})
			}
			// ACP reports the usage of this prompt turn: it is the turn's share.
			u := r.Usage
			c.sink.Emit(Event{Kind: KindDone, Usage: &Usage{InputTokens: u.InputTokens, OutputTokens: u.OutputTokens,
				Turn: &TurnUsage{Model: c.opts.Model, InputTokens: u.InputTokens + u.CachedReadTokens + u.CachedWriteTokens,
					OutputTokens: u.OutputTokens, CachedTokens: u.CachedReadTokens}}})
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

func (c *acpConn) Interrupt() error {
	c.mu.Lock()
	sid := c.session
	c.mu.Unlock()
	return c.rpc.Notify("session/cancel", map[string]any{"sessionId": sid})
}

func (c *acpConn) Close() error { c.p.stop(); return nil }

type acpToolCall struct {
	ToolCallID string           `json:"toolCallId"`
	Title      string           `json:"title"`
	Kind       string           `json:"kind"`
	Status     string           `json:"status"`
	RawInput   map[string]any   `json:"rawInput"`
	Content    []map[string]any `json:"content"`
	Locations  []struct {
		Path string `json:"path"`
	} `json:"locations"`
}

func (c *acpConn) rel(p string) string {
	if c.opts.Cwd != "" && strings.HasPrefix(p, c.opts.Cwd+"/") {
		return strings.TrimPrefix(p, c.opts.Cwd+"/")
	}
	return p
}

func (c *acpConn) toolName(t *acpTool) string {
	if t.kind != "" {
		return t.kind
	}
	return "other"
}

func (c *acpConn) onNotify(method string, params json.RawMessage) {
	if method != "session/update" {
		return
	}
	c.mu.Lock()
	loading := c.loading
	c.mu.Unlock()
	if loading {
		return
	}
	var p struct {
		Update struct {
			acpToolCall
			SessionUpdate string          `json:"sessionUpdate"`
			Content       json.RawMessage `json:"content"`
		} `json:"update"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	u := p.Update
	switch u.SessionUpdate {
	case "agent_message_chunk", "agent_thought_chunk":
		var blk struct {
			Type string `json:"type"`
			Text string `json:"text"`
		}
		_ = json.Unmarshal(u.Content, &blk)
		if blk.Text == "" {
			return
		}
		kind := KindText
		if u.SessionUpdate == "agent_thought_chunk" {
			kind = KindThinking
		}
		c.sink.Emit(Event{Kind: kind, Text: blk.Text, Delta: true})
	case "tool_call", "tool_call_update":
		var content []map[string]any
		_ = json.Unmarshal(u.Content, &content)
		u.acpToolCall.Content = content
		c.onToolCall(u.acpToolCall)
	}
}

func (c *acpConn) onToolCall(tc acpToolCall) {
	t := c.tools[tc.ToolCallID]
	if t == nil {
		t = &acpTool{}
		c.tools[tc.ToolCallID] = t
	}
	changed := false
	if tc.Kind != "" && tc.Kind != t.kind {
		t.kind, changed = tc.Kind, true
	}
	if tc.Title != "" && tc.Title != t.title {
		t.title, changed = tc.Title, true
	}
	if len(tc.RawInput) > 0 {
		t.input, changed = tc.RawInput, true
	}
	tool := c.toolName(t)
	if !t.done && (changed || !t.emitted) {
		t.emitted = true
		c.sink.Emit(Event{Kind: KindToolCall, ID: tc.ToolCallID, Tool: tool, Input: t.input, Title: c.title(t), Category: Classify(tool, t.input)})
	}
	for _, blk := range tc.Content {
		if blk["type"] == "diff" {
			path, _ := blk["path"].(string)
			oldT, _ := blk["oldText"].(string)
			newT, _ := blk["newText"].(string)
			if d := unifiedDiff(c.rel(path), oldT, newT); d != "" {
				c.sink.Emit(Event{Kind: KindDiff, ID: tc.ToolCallID, Tool: tool, Path: c.rel(path), Diff: d})
			}
		}
	}
	if (tc.Status == "completed" || tc.Status == "failed") && !t.done {
		t.done = true
		var parts []string
		for _, blk := range tc.Content {
			if blk["type"] == "content" {
				if s := contentText([]any{blk["content"]}); s != "" {
					parts = append(parts, s)
				}
			}
		}
		c.sink.Emit(toolResultEvent(tc.ToolCallID, tool, strings.Join(parts, "\n"), tc.Status == "failed"))
	}
}

func (c *acpConn) title(t *acpTool) string {
	if t.input != nil {
		if cmd, _ := t.input["command"].(string); cmd != "" {
			return "$ " + oneLine(cmd, 120)
		}
		if p, _ := t.input["path"].(string); p != "" && t.kind == "edit" {
			return "Edit " + c.rel(p)
		}
		if p, _ := t.input["filePath"].(string); p != "" && t.title != "" {
			return strings.ToUpper(t.title[:1]) + t.title[1:] + " " + c.rel(p)
		}
	}
	if t.title != "" {
		return t.title
	}
	return t.kind
}
