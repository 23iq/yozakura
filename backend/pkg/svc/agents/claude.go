package agents

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"mime"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// Claude Code: `claude -p` with stream-json in/out. One long-lived process
// per session; turns are user messages on stdin. Permission prompts arrive
// as control_request{subtype:can_use_tool} because of
// --permission-prompt-tool stdio, and are answered with control_response.
type claudeAdapter struct{}

func init() { Register(claudeAdapter{}) }

func (claudeAdapter) ID() string            { return "claude" }
func (claudeAdapter) Label() string         { return "Claude Code" }
func (claudeAdapter) DefaultBinary() string { return "claude" }
func (claudeAdapter) VersionArgs() []string { return []string{"--version"} }
func (claudeAdapter) Notes() string {
	return "Uses your Claude Code login. Permissions via --permission-prompt-tool stdio (every non-read tool is asked), resume via --resume."
}
func (claudeAdapter) Capabilities() Capabilities {
	return Capabilities{Resume: true, Images: true, InteractivePermissions: true, MCP: true, Interrupt: true}
}

// claudeMCPConfig is the --mcp-config document, or nil when none is needed.
// It can carry server env/headers (tokens), so it goes to a 0600 file and
// never into argv.
func claudeMCPConfig(o StartOptions) []byte {
	if len(o.MCP) == 0 && o.Mode != "shell" {
		return nil
	}
	servers := map[string]any{}
	for _, s := range o.MCP {
		switch s.Transport {
		case "http", "sse":
			e := map[string]any{"type": s.Transport, "url": s.URL}
			if len(s.Headers) > 0 {
				e["headers"] = s.Headers
			}
			servers[s.Name] = e
		default:
			e := map[string]any{"type": "stdio", "command": s.Command, "args": nonNil(s.Args)}
			if len(s.Env) > 0 {
				e["env"] = s.Env
			}
			servers[s.Name] = e
		}
	}
	cfg, _ := json.Marshal(map[string]any{"mcpServers": servers})
	return cfg
}

// claudeArgs builds the command line (exported to tests via the args log).
// mcpConfig is the path of the file written from claudeMCPConfig.
func claudeArgs(o StartOptions, mcpConfig string) []string {
	args := []string{"-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
		"--include-partial-messages", "--permission-prompt-tool", "stdio", "--permission-mode", "default"}
	if o.Model != "" {
		args = append(args, "--model", o.Model)
	}
	if o.ResumeID != "" {
		args = append(args, "--resume", o.ResumeID)
	}
	if mcpConfig != "" {
		args = append(args, "--mcp-config", mcpConfig)
	}
	if o.Mode == "shell" {
		// Desktop control only: no built-in tools, only the shell MCP.
		args = append(args, "--strict-mcp-config", "--tools", "")
	}
	if o.SystemPrompt != "" {
		args = append(args, "--append-system-prompt", o.SystemPrompt)
	}
	return append(args, o.ExtraArgs...)
}

func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

type claudeConn struct {
	p     *proc
	opts  StartOptions
	sink  Sink
	mu    sync.Mutex
	nreq  int
	inMsg map[string]bool // message ids streamed via partial events
	tools map[string]string
}

func (a claudeAdapter) Start(_ context.Context, o StartOptions, sink Sink) (Conn, error) {
	c := &claudeConn{opts: o, sink: sink, inMsg: map[string]bool{}, tools: map[string]string{}}
	var cfgPath string
	if data := claudeMCPConfig(o); data != nil {
		path, err := writePrivateFile("mcp-*.json", data)
		if err != nil {
			return nil, err
		}
		cfgPath = path
	}
	onExit := func(err error, stderr string) {
		if cfgPath != "" {
			_ = os.Remove(cfgPath)
		}
		sink.Exited(err, stderr)
	}
	p, err := startProc(o.Binary, claudeArgs(o, cfgPath), o.Cwd, o.Env, c.onLine, onExit)
	if err != nil {
		if cfgPath != "" {
			_ = os.Remove(cfgPath)
		}
		return nil, err
	}
	c.p = p
	if err := c.control(map[string]any{"subtype": "initialize", "hooks": nil}); err != nil {
		p.stop()
		return nil, err
	}
	return c, nil
}

func (c *claudeConn) control(req map[string]any) error {
	c.mu.Lock()
	c.nreq++
	id := fmt.Sprintf("yz-%d", c.nreq)
	c.mu.Unlock()
	return c.p.writeJSON(map[string]any{"type": "control_request", "request_id": id, "request": req})
}

func (c *claudeConn) Send(text string, images []string) error {
	var content any = text
	if len(images) > 0 {
		parts := []any{}
		for _, img := range images {
			data, err := os.ReadFile(img)
			if err != nil {
				return err
			}
			mt := mime.TypeByExtension(strings.ToLower(filepath.Ext(img)))
			if mt == "" {
				mt = "image/png"
			}
			parts = append(parts, map[string]any{"type": "image", "source": map[string]any{
				"type": "base64", "media_type": mt, "data": base64.StdEncoding.EncodeToString(data)}})
		}
		parts = append(parts, map[string]any{"type": "text", "text": text})
		content = parts
	}
	return c.p.writeJSON(map[string]any{"type": "user", "session_id": "", "parent_tool_use_id": nil,
		"message": map[string]any{"role": "user", "content": content}})
}

func (c *claudeConn) Interrupt() error { return c.control(map[string]any{"subtype": "interrupt"}) }

func (c *claudeConn) Close() error { c.p.stop(); return nil }

func (c *claudeConn) onLine(line []byte) {
	var m map[string]any
	if json.Unmarshal(line, &m) != nil {
		return
	}
	typ, _ := m["type"].(string)
	switch typ {
	case "system":
		if m["subtype"] == "init" {
			if id, _ := m["session_id"].(string); id != "" {
				c.sink.SetAgentSessionID(id)
			}
		}
	case "stream_event":
		if m["parent_tool_use_id"] != nil {
			return
		}
		c.onStreamEvent(asMap(m["event"]))
	case "assistant":
		if m["parent_tool_use_id"] != nil {
			return
		}
		c.onAssistant(asMap(m["message"]))
	case "user":
		if m["parent_tool_use_id"] != nil {
			return
		}
		c.onUser(m)
	case "control_request":
		c.onControlRequest(m)
	case "result":
		c.onResult(m)
	}
}

func (c *claudeConn) onStreamEvent(ev map[string]any) {
	switch ev["type"] {
	case "message_start":
		if id, _ := asMap(ev["message"])["id"].(string); id != "" {
			c.inMsg[id] = true
		}
	case "content_block_delta":
		d := asMap(ev["delta"])
		switch d["type"] {
		case "text_delta":
			if t, _ := d["text"].(string); t != "" {
				c.sink.Emit(Event{Kind: KindText, Text: t, Delta: true})
			}
		case "thinking_delta":
			if t, _ := d["thinking"].(string); t != "" {
				c.sink.Emit(Event{Kind: KindThinking, Text: t, Delta: true})
			}
		}
	}
}

func (c *claudeConn) onAssistant(msg map[string]any) {
	id, _ := msg["id"].(string)
	streamed := c.inMsg[id]
	for _, b := range asSlice(msg["content"]) {
		bm := asMap(b)
		switch bm["type"] {
		case "text":
			if t, _ := bm["text"].(string); t != "" && !streamed {
				c.sink.Emit(Event{Kind: KindText, Text: t, Delta: true})
			}
		case "thinking":
			if t, _ := bm["thinking"].(string); t != "" && !streamed {
				c.sink.Emit(Event{Kind: KindThinking, Text: t, Delta: true})
			}
		case "tool_use":
			name, _ := bm["name"].(string)
			tid, _ := bm["id"].(string)
			in := asMap(bm["input"])
			c.tools[tid] = name
			c.sink.Emit(Event{Kind: KindToolCall, ID: tid, Tool: name, Input: in,
				Title: toolTitle(name, in, c.opts.Cwd), Category: Classify(name, in)})
		}
	}
}

func (c *claudeConn) onUser(m map[string]any) {
	msg := asMap(m["message"])
	for _, b := range asSlice(msg["content"]) {
		bm := asMap(b)
		if bm["type"] != "tool_result" {
			continue
		}
		tid, _ := bm["tool_use_id"].(string)
		isErr, _ := bm["is_error"].(bool)
		c.sink.Emit(Event{Kind: KindToolResult, ID: tid, Tool: c.tools[tid], Output: truncate(contentText(bm["content"])), IsError: isErr})
		if res := asMap(m["tool_use_result"]); res != nil {
			if path, _ := res["filePath"].(string); path != "" {
				rel := path
				if c.opts.Cwd != "" && strings.HasPrefix(path, c.opts.Cwd+"/") {
					rel = strings.TrimPrefix(path, c.opts.Cwd+"/")
				}
				var diff string
				if hunks := asSlice(res["structuredPatch"]); len(hunks) > 0 {
					diff = structuredPatchDiff(rel, hunks)
				} else if res["type"] == "create" {
					content, _ := res["content"].(string)
					diff = unifiedDiff(rel, "", content)
				}
				if diff != "" {
					c.sink.Emit(Event{Kind: KindDiff, ID: tid, Tool: c.tools[tid], Path: rel, Diff: diff})
				}
			}
		}
	}
}

func (c *claudeConn) onControlRequest(m map[string]any) {
	rid, _ := m["request_id"].(string)
	req := asMap(m["request"])
	if req["subtype"] != "can_use_tool" {
		_ = c.p.writeJSON(map[string]any{"type": "control_response", "response": map[string]any{
			"subtype": "error", "request_id": rid, "error": "unsupported request"}})
		return
	}
	tool, _ := req["tool_name"].(string)
	in := asMap(req["input"])
	if in == nil {
		in = map[string]any{}
	}
	cat := Classify(tool, in)
	suggestions := asSlice(req["permission_suggestions"])
	pr := PermissionRequest{ID: rid, Tool: tool, Title: toolTitle(tool, in, c.opts.Cwd), Category: cat, Input: in,
		RuleKey: ruleKey(tool, cat, in)}
	if tu, _ := req["tool_use_id"].(string); tu != "" {
		pr.ID = tu
	}
	pr.Path, pr.Diff = proposedEdit(tool, in, c.opts.Cwd)
	c.sink.Permission(pr, func(decision string) {
		var resp map[string]any
		switch decision {
		case DecisionAllow, DecisionAllowSession:
			resp = map[string]any{"behavior": "allow", "updatedInput": in}
			if decision == DecisionAllowSession {
				// Only session-scoped suggestions: never write the user's settings files.
				var upd []any
				for _, s := range suggestions {
					if asMap(s)["destination"] == "session" {
						upd = append(upd, s)
					}
				}
				if len(upd) > 0 {
					resp["updatedPermissions"] = upd
				}
			}
		default:
			resp = map[string]any{"behavior": "deny", "message": "The user denied this action."}
		}
		_ = c.p.writeJSON(map[string]any{"type": "control_response", "response": map[string]any{
			"subtype": "success", "request_id": rid, "response": resp}})
	})
}

func (c *claudeConn) onResult(m map[string]any) {
	u := asMap(m["usage"])
	usage := &Usage{InputTokens: int64(num(u["input_tokens"])), OutputTokens: int64(num(u["output_tokens"])), CostUSD: num(m["total_cost_usd"])}
	if isErr, _ := m["is_error"].(bool); isErr {
		msg, _ := m["result"].(string)
		if msg == "" {
			msg, _ = m["subtype"].(string)
		}
		c.sink.Emit(Event{Kind: KindError, Message: msg})
	}
	c.sink.Emit(Event{Kind: KindDone, Usage: usage})
}

// --- small JSON helpers shared by adapters ---

func asMap(v any) map[string]any { m, _ := v.(map[string]any); return m }
func asSlice(v any) []any        { s, _ := v.([]any); return s }
func num(v any) float64          { f, _ := v.(float64); return f }

// contentText flattens a string or a list of {type:text,text} blocks.
func contentText(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case []any:
		var parts []string
		for _, b := range t {
			bm := asMap(b)
			if s, _ := bm["text"].(string); s != "" {
				parts = append(parts, s)
			} else if inner := asMap(bm["content"]); inner != nil {
				if s, _ := inner["text"].(string); s != "" {
					parts = append(parts, s)
				}
			}
		}
		return strings.Join(parts, "\n")
	}
	return ""
}

const maxOutput = 64 << 10

func truncate(s string) string {
	if len(s) > maxOutput {
		return s[:maxOutput] + "\n… (truncated)"
	}
	return s
}
