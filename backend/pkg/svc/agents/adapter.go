package agents

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
)

// StartOptions describe one agent process launch.
type StartOptions struct {
	Binary       string
	Cwd          string
	Effort       string
	Model        string
	ResumeID     string // agent-native session/thread id to resume
	Mode         string // "agent" | "shell"
	SystemPrompt string
	ExtraArgs    []string
	MCP          []MCPServer
	Env          []string    // extra KEY=VALUE entries
	Yolo         func() bool // current YOLO state (may change mid-session)
}

func (o StartOptions) yolo() bool { return o.Yolo != nil && o.Yolo() }

// PermissionRequest is an adapter's question to the user/policy.
type PermissionRequest struct {
	ID       string
	Tool     string
	Title    string
	Category string
	Input    any
	RuleKey  string // key remembered by "allow for this session"
	Path     string // file the call would change (edits), for the card's diff
	Diff     string // proposed change as a unified diff, when known up front
}

// Sink receives everything an adapter observes. Calls may come from the
// adapter's reader goroutine and must not block for long.
type Sink interface {
	Emit(ev Event)
	SetAgentSessionID(id string)
	// Permission asks the policy/user; reply is called exactly once with
	// DecisionAllow, DecisionAllowSession or DecisionDeny.
	Permission(req PermissionRequest, reply func(decision string))
	// Exited is called once when the process is gone.
	Exited(err error, stderrTail string)
}

// Conn is a running agent process.
type Conn interface {
	Send(text string, images []string) error
	Interrupt() error
	Close() error
}

// Capabilities advertised to the UI.
type Capabilities struct {
	Resume                 bool `json:"resume"`
	Images                 bool `json:"images"`
	InteractivePermissions bool `json:"interactivePermissions"`
	MCP                    bool `json:"mcp"`
	Interrupt              bool `json:"interrupt"`
}

// Adapter knows how to drive one CLI agent.
type Adapter interface {
	ID() string
	Label() string
	DefaultBinary() string
	VersionArgs() []string
	Capabilities() Capabilities
	Notes() string
	Start(ctx context.Context, opts StartOptions, sink Sink) (Conn, error)
}

var registry = map[string]Adapter{}

// Register adds an adapter to the registry (called from init()).
func Register(a Adapter) { registry[a.ID()] = a }

// Lookup returns the adapter with the given id.
func Lookup(id string) Adapter { return registry[id] }

// AdapterIDs lists registered adapters in a stable order.
func AdapterIDs() []string {
	ids := make([]string, 0, len(registry))
	for id := range registry {
		ids = append(ids, id)
	}
	order := map[string]int{"claude": 0, "codex": 1, "opencode": 2}
	sort.Slice(ids, func(i, j int) bool {
		oi, iok := order[ids[i]]
		oj, jok := order[ids[j]]
		if iok && jok {
			return oi < oj
		}
		if iok != jok {
			return iok
		}
		return ids[i] < ids[j]
	})
	return ids
}

// ResolveBinary finds an agent binary: explicit path, then PATH, then
// ~/.local/bin. Returns "" when not found.
func ResolveBinary(configured, def string) string {
	if configured != "" {
		if filepath.IsAbs(configured) {
			if isExecutable(configured) {
				return configured
			}
			return ""
		}
		def = configured
	}
	if def == "" {
		return ""
	}
	if p, err := exec.LookPath(def); err == nil {
		return p
	}
	if home, err := os.UserHomeDir(); err == nil {
		p := filepath.Join(home, ".local", "bin", def)
		if isExecutable(p) {
			return p
		}
	}
	return ""
}

func isExecutable(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir() && st.Mode()&0o111 != 0
}
