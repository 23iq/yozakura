// Package agents runs CLI coding agents (Claude Code, Codex, OpenCode, any
// ACP agent) that authenticate with their own login, and normalizes their
// streams into one event protocol for the shell UI.
package agents

import "yozakura/backend/pkg/brand"

// Event kinds of the normalized protocol.
const (
	KindUser               = "user"
	KindText               = "text"
	KindThinking           = "thinking"
	KindToolCall           = "tool_call"
	KindToolResult         = "tool_result"
	KindDiff               = "diff"
	KindPermissionRequest  = "permission_request"
	KindPermissionResolved = "permission_resolved"
	KindStatus             = "status"
	KindError              = "error"
	KindDone               = "done"
)

// Session status values (KindStatus events and SessionMeta.Status).
const (
	StatusStarting = "starting"
	StatusRunning  = "running"
	StatusIdle     = "idle"
	StatusWaiting  = "waiting"
	StatusExited   = "exited"
)

// Tool categories used by the permission policy and the UI.
const (
	CatRead    = "read"
	CatWrite   = "write"
	CatExec    = "exec"
	CatNetwork = "network"
	CatMCP     = "mcp"
	CatOther   = "other"
)

// Permission decisions.
const (
	DecisionAllow        = "allow"
	DecisionAllowSession = "allow_session"
	DecisionDeny         = "deny"
	DecisionAuto         = "auto" // only reported in permission_resolved
)

// Event is one normalized agent event. Session/Seq/TS are filled by the
// manager; adapters set the rest.
type Event struct {
	Session  string   `json:"session"`
	Seq      int64    `json:"seq"`
	TS       int64    `json:"ts"`
	Kind     string   `json:"kind"`
	Text     string   `json:"text,omitempty"`
	Delta    bool     `json:"delta,omitempty"`
	ID       string   `json:"id,omitempty"`
	Tool     string   `json:"tool,omitempty"`
	Title    string   `json:"title,omitempty"`
	Category string   `json:"category,omitempty"`
	Input    any      `json:"input,omitempty"`
	Output   string   `json:"output,omitempty"`
	IsError  bool     `json:"isError,omitempty"`
	Path     string   `json:"path,omitempty"`
	Diff     string   `json:"diff,omitempty"`
	Options  []string `json:"options,omitempty"`
	Decision string   `json:"decision,omitempty"`
	Status   string   `json:"status,omitempty"`
	Message  string   `json:"message,omitempty"`
	Usage    *Usage   `json:"usage,omitempty"`
}

// Usage is attached to done events when the agent reports it.
// ContextTokens is the size of the conversation the model saw in the last
// request of the turn (what fills the context window) and ContextWindow the
// model's window; both are 0 when the agent does not report them.
type Usage struct {
	InputTokens   int64   `json:"inputTokens"`
	OutputTokens  int64   `json:"outputTokens"`
	CostUSD       float64 `json:"costUsd"`
	ContextTokens int64   `json:"contextTokens,omitempty"`
	ContextWindow int64   `json:"contextWindow,omitempty"`
}

// SessionMeta is the persisted description of a session.
type SessionMeta struct {
	ID             string `json:"id"`
	Agent          string `json:"agent"`
	Cwd            string `json:"cwd"`
	Title          string `json:"title"`
	Created        int64  `json:"created"`
	Updated        int64  `json:"updated"`
	AgentSessionID string `json:"agentSessionId"`
	Status         string `json:"status"`
	Pinned         bool   `json:"pinned"`
	Yolo           bool   `json:"yolo"`
	Effort         string `json:"effort"`
	Model          string `json:"model"`
	Mode           string `json:"mode"` // agent (Code) | assistant | oneshot
	SystemPrompt   string `json:"systemPrompt,omitempty"`
	LastText       string `json:"lastText"`
	Pending        int    `json:"pending"`
	LastSeq        int64  `json:"lastSeq"`
}

// MCPServer is an MCP server handed to a CLI agent.
type MCPServer struct {
	Name      string            `json:"name"`
	Transport string            `json:"transport"` // stdio | http | sse
	Command   string            `json:"command,omitempty"`
	Args      []string          `json:"args,omitempty"`
	Env       map[string]string `json:"env,omitempty"`
	URL       string            `json:"url,omitempty"`
	Headers   map[string]string `json:"headers,omitempty"`
}

// YozakuraMCPName is the name of the built-in shell MCP server.
const YozakuraMCPName = brand.AppID
