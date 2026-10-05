// Package mcp is the "mcp" IPC service: it lists the MCP servers imported
// from Claude Code, Codex and OpenCode plus the built-in Yozakura server,
// keeps a lazy pool of client connections and proxies tools/list and
// tools/call for chat models that support tool calling.
package mcp

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sync"
	"time"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/mcp"
	"yozakura/backend/pkg/mcp/yozakura"
)

const (
	idleTimeout  = 5 * time.Minute
	listTimeout  = 20 * time.Second
	callTimeout  = 120 * time.Second
	reapInterval = time.Minute
)

// Sources toggles the importers.
type Sources struct {
	Claude   bool `json:"claude"`
	Codex    bool `json:"codex"`
	Opencode bool `json:"opencode"`
}

// Config is pushed by the shell (mcp.configure).
type Config struct {
	Disabled []string `json:"disabled"`
	Enabled  []string `json:"enabled"` // force-enable servers disabled in their own config
	Sources  Sources  `json:"sources"`
	Yozakura bool     `json:"yozakura"`
}

// ConnectFunc opens a client for a spec (injectable for tests).
type ConnectFunc func(ctx context.Context, spec mcp.ServerSpec) (*mcp.Client, error)

type entry struct {
	key      string
	client   *mcp.Client
	tools    []mcp.Tool
	lastUsed time.Time
}

// Service is the IPC service.
type Service struct {
	mu      sync.Mutex
	cfg     Config
	opts    mcp.ImportOptions
	exe     string
	connect ConnectFunc
	pool    map[string]*entry
	lastErr map[string]string
	now     func() time.Time
	stop    chan struct{}
	once    sync.Once
}

// NewService builds the service with every source enabled.
func NewService() *Service {
	exe, _ := os.Executable()
	s := &Service{
		cfg:     Config{Sources: Sources{true, true, true}, Yozakura: true},
		exe:     exe,
		pool:    map[string]*entry{},
		lastErr: map[string]string{},
		now:     time.Now,
		stop:    make(chan struct{}),
	}
	s.connect = s.defaultConnect
	go s.reaper()
	return s
}

// SetImportOptions overrides config file locations (tests).
func (s *Service) SetImportOptions(o mcp.ImportOptions) {
	s.mu.Lock()
	s.opts = o
	s.mu.Unlock()
}

// SetConnect overrides the transport (tests).
func (s *Service) SetConnect(f ConnectFunc) {
	s.mu.Lock()
	s.connect = f
	s.mu.Unlock()
}

// Register wires the IPC methods.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "mcp",
		Methods: map[string]ipc.HandlerFunc{
			"configure": s.configure,
			"servers":   s.servers,
			"status":    s.status,
			"tools":     s.tools,
			"all_tools": s.allTools,
			"call":      s.call,
		},
		Async: map[string]bool{"tools": true, "all_tools": true, "call": true},
	})
}

// Close stops every client (daemon shutdown).
func (s *Service) Close() {
	s.once.Do(func() { close(s.stop) })
	s.mu.Lock()
	pool := s.pool
	s.pool = map[string]*entry{}
	s.mu.Unlock()
	for _, e := range pool {
		e.client.Close()
	}
}

func (s *Service) yozakuraSpec() mcp.ServerSpec {
	return mcp.ServerSpec{Name: brand.AppID, Source: mcp.SourceYozakura, Transport: mcp.TransportStdio,
		Command: s.exe, Args: []string{"mcp"}, Enabled: true}
}

// resolve imports every source and applies the enable/disable overrides.
func (s *Service) resolve() mcp.ImportResult {
	s.mu.Lock()
	cfg, opts := s.cfg, s.opts
	s.mu.Unlock()
	opts.Claude, opts.Codex, opts.Opencode = cfg.Sources.Claude, cfg.Sources.Codex, cfg.Sources.Opencode
	res := mcp.Import(opts)
	all := append([]mcp.ServerSpec{s.yozakuraSpec()}, res.Servers...)
	merged := mcp.Merge(all)
	merged.Duplicates = append(merged.Duplicates, res.Duplicates...)
	merged.Errors = res.Errors
	disabled, enabled := set(cfg.Disabled), set(cfg.Enabled)
	for i := range merged.Servers {
		sp := &merged.Servers[i]
		if sp.Source == mcp.SourceYozakura {
			sp.Enabled = cfg.Yozakura
			continue
		}
		if enabled[sp.Name] {
			sp.Enabled = true
		}
		if disabled[sp.Name] {
			sp.Enabled = false
		}
	}
	return merged
}

func set(list []string) map[string]bool {
	m := map[string]bool{}
	for _, v := range list {
		m[v] = true
	}
	return m
}

// EnabledSpecs returns the servers CLI agents should receive, with env
// and headers (never sent over IPC).
func (s *Service) EnabledSpecs() []mcp.ServerSpec {
	var out []mcp.ServerSpec
	for _, sp := range s.resolve().Servers {
		if sp.Enabled {
			out = append(out, sp)
		}
	}
	return out
}

func (s *Service) find(name string) (mcp.ServerSpec, error) {
	for _, sp := range s.resolve().Servers {
		if sp.Name == name {
			if !sp.Enabled {
				return sp, fmt.Errorf("mcp server %q is disabled", name)
			}
			return sp, nil
		}
	}
	return mcp.ServerSpec{}, fmt.Errorf("unknown mcp server %q", name)
}

func specKey(sp mcp.ServerSpec) string {
	data, _ := json.Marshal(sp)
	return string(data)
}

// defaultConnect runs the built-in server in-process and everything else
// through its transport.
func (s *Service) defaultConnect(ctx context.Context, sp mcp.ServerSpec) (*mcp.Client, error) {
	info := mcp.Implementation{Name: "yozakura-shell", Version: "1"}
	if sp.Source == mcp.SourceYozakura {
		srv := yozakura.NewServer(yozakura.DefaultDeps(), "1")
		cr, sw := io.Pipe()
		sr, cw := io.Pipe()
		go func() {
			_ = srv.Serve(context.Background(), sr, sw)
			sw.Close()
		}()
		c := mcp.NewStreamClient(cr, cw)
		if _, err := c.Initialize(ctx, info); err != nil {
			c.Close()
			return nil, err
		}
		return c, nil
	}
	return mcp.Connect(ctx, sp, info)
}

// client returns a live pooled client, (re)connecting when needed.
func (s *Service) client(ctx context.Context, sp mcp.ServerSpec) (*entry, error) {
	key := specKey(sp)
	s.mu.Lock()
	e := s.pool[sp.Name]
	if e != nil {
		select {
		case <-e.client.Done():
			delete(s.pool, sp.Name)
			e = nil
		default:
			if e.key != key { // config changed
				delete(s.pool, sp.Name)
				go e.client.Close()
				e = nil
			}
		}
	}
	if e != nil {
		e.lastUsed = s.now()
		s.mu.Unlock()
		return e, nil
	}
	connect := s.connect
	s.mu.Unlock()

	c, err := connect(ctx, sp)
	if err != nil {
		s.mu.Lock()
		s.lastErr[sp.Name] = err.Error()
		s.mu.Unlock()
		return nil, fmt.Errorf("connect %s: %w", sp.Name, err)
	}
	e = &entry{key: key, client: c, lastUsed: s.now()}
	s.mu.Lock()
	if old := s.pool[sp.Name]; old != nil { // lost a race
		s.mu.Unlock()
		c.Close()
		return old, nil
	}
	s.pool[sp.Name] = e
	delete(s.lastErr, sp.Name)
	s.mu.Unlock()
	return e, nil
}

func (s *Service) reaper() {
	t := time.NewTicker(reapInterval)
	defer t.Stop()
	for {
		select {
		case <-s.stop:
			return
		case <-t.C:
			s.reap()
		}
	}
}

func (s *Service) reap() {
	s.mu.Lock()
	var idle []*entry
	for name, e := range s.pool {
		if s.now().Sub(e.lastUsed) > idleTimeout {
			idle = append(idle, e)
			delete(s.pool, name)
		}
	}
	s.mu.Unlock()
	for _, e := range idle {
		e.client.Close()
	}
}

// ListTools returns the tools of one server (cached per connection).
func (s *Service) ListTools(ctx context.Context, name string) ([]mcp.Tool, error) {
	sp, err := s.find(name)
	if err != nil {
		return nil, err
	}
	e, err := s.client(ctx, sp)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	cached := e.tools
	s.mu.Unlock()
	if cached != nil {
		return cached, nil
	}
	tools, err := e.client.ListTools(ctx)
	if err != nil {
		return nil, err
	}
	if tools == nil {
		tools = []mcp.Tool{}
	}
	s.mu.Lock()
	e.tools = tools
	s.mu.Unlock()
	return tools, nil
}

// CallTool proxies tools/call; one retry after reconnect when the
// transport died.
func (s *Service) CallTool(ctx context.Context, server, tool string, args json.RawMessage) (*mcp.CallToolResult, error) {
	sp, err := s.find(server)
	if err != nil {
		return nil, err
	}
	var argv any = map[string]any{}
	if len(args) > 0 && string(args) != "null" {
		argv = args
	}
	for attempt := 0; ; attempt++ {
		e, err := s.client(ctx, sp)
		if err != nil {
			return nil, err
		}
		res, err := e.client.CallTool(ctx, tool, argv)
		if err != nil && attempt == 0 && isDead(e.client) {
			continue
		}
		return res, err
	}
}

func isDead(c *mcp.Client) bool {
	select {
	case <-c.Done():
		return true
	default:
		return false
	}
}
