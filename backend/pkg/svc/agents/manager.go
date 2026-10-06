package agents

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"sync"
	"time"
)

// AgentConfig is the per-agent part of agents.configure.
type AgentConfig struct {
	Enabled   *bool    `json:"enabled"`
	Binary    string   `json:"binary"`
	Effort    string   `json:"effort"`
	Model     string   `json:"model"`
	ExtraArgs []string `json:"extraArgs"`
	Yolo      bool     `json:"yolo"`
}

// Config is pushed by the shell (agents.configure).
type Config struct {
	Agents      map[string]AgentConfig `json:"agents"`
	Policy      *Policy                `json:"policy"`
	YozakuraMCP *bool                  `json:"yozakuraMcp"`
}

// AgentInfo is one entry of agents.list_agents.
type AgentInfo struct {
	ID           string       `json:"id"`
	Label        string       `json:"label"`
	Available    bool         `json:"available"`
	Enabled      bool         `json:"enabled"`
	Binary       string       `json:"binary"`
	Version      string       `json:"version"`
	Capabilities Capabilities `json:"capabilities"`
	Notes        string       `json:"notes"`
}

// DefaultAssistantPrompt steers Assistant-space sessions.
const DefaultAssistantPrompt = "You are the user's assistant on their Linux desktop (Yozakura). Control the desktop shell through the `yozakura` MCP tools: " +
	"config, presets, wallpaper, windows/workspaces, notifications, clipboard, screenshots, media, do-not-disturb, " +
	"timers/reminders/focus, notes, apps, system and network status, Bluetooth/Wi-Fi/audio output, brightness/night light, " +
	"screen_look (see the screen), keybinds (binds_search/binds_check/binds_suggest, then binds_set once the user agrees) " +
	"and routines (routine_save bundles steps into one command a keybind can run). " +
	"Prefer those tools over shell commands; your own tools may read files and run commands, and the user confirms commands and file changes. " +
	"Act directly on clear requests and answer briefly."

// Manager owns all agent sessions.
type Manager struct {
	mu        sync.Mutex
	dir       string
	cfg       Config
	sessions  map[string]*session
	broadcast func(service string, data any)
	mcp       func() []MCPServer
	now       func() time.Time
	coalesce  time.Duration
	extraEnv  []string
	versions  map[string]string
	hooks     hooks // listeners + permission hook (hooks.go)
}

// NewManager loads persisted sessions from dir (created on demand).
func NewManager(dir string) *Manager {
	m := &Manager{
		dir:       dir,
		sessions:  map[string]*session{},
		broadcast: func(string, any) {},
		now:       time.Now,
		coalesce:  60 * time.Millisecond,
		versions:  map[string]string{},
	}
	m.broadcast = m.withListeners(m.broadcast)
	m.load()
	return m
}

// SetMCPProvider wires the list of enabled MCP servers (incl. yozakura).
func (m *Manager) SetMCPProvider(fn func() []MCPServer) {
	m.mu.Lock()
	m.mcp = fn
	m.mu.Unlock()
}

// SetBroadcast sets the subscription fan-out (service, data).
func (m *Manager) SetBroadcast(fn func(service string, data any)) {
	m.mu.Lock()
	m.broadcast = m.withListeners(fn)
	m.mu.Unlock()
}

// Configure replaces the shell-provided configuration.
func (m *Manager) Configure(c Config) {
	m.mu.Lock()
	m.cfg = c
	m.mu.Unlock()
	list := m.ListAgents()
	m.mu.Lock()
	b := m.broadcast
	m.mu.Unlock()
	b("agents.agents", list)
}

func (m *Manager) policy() Policy {
	if m.cfg.Policy != nil {
		return *m.cfg.Policy
	}
	return DefaultPolicy()
}

func (m *Manager) agentCfg(id string) AgentConfig {
	if c, ok := m.cfg.Agents[id]; ok {
		return c
	}
	return AgentConfig{}
}

// ListAgents reports every registered adapter and whether it can run.
func (m *Manager) ListAgents() []AgentInfo {
	ids := AdapterIDs()
	out := make([]AgentInfo, len(ids))
	var wg sync.WaitGroup
	for i, id := range ids {
		a := Lookup(id)
		m.mu.Lock()
		cfg := m.agentCfg(id)
		m.mu.Unlock()
		bin := ResolveBinary(cfg.Binary, a.DefaultBinary())
		enabled := cfg.Enabled == nil || *cfg.Enabled
		out[i] = AgentInfo{ID: id, Label: a.Label(), Binary: bin, Enabled: enabled, Available: bin != "" && enabled,
			Capabilities: a.Capabilities(), Notes: a.Notes()}
		// Probes run in parallel: a slow CLI costs one timeout, not one each.
		wg.Add(1)
		go func() {
			defer wg.Done()
			out[i].Version = m.version(bin, a.VersionArgs())
		}()
	}
	wg.Wait()
	return out
}

func (m *Manager) version(bin string, args []string) string {
	if bin == "" {
		return ""
	}
	m.mu.Lock()
	v, ok := m.versions[bin]
	m.mu.Unlock()
	if ok {
		return v
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, bin, args...).Output()
	if err == nil {
		v = strings.TrimSpace(strings.SplitN(string(out), "\n", 2)[0])
	}
	m.mu.Lock()
	m.versions[bin] = v
	m.mu.Unlock()
	return v
}

// CreateParams are the agents.create parameters.
type CreateParams struct {
	Agent        string `json:"agent"`
	Cwd          string `json:"cwd"`
	Title        string `json:"title"`
	Effort       string `json:"effort"`
	Model        string `json:"model"`
	Yolo         *bool  `json:"yolo"`
	Mode         string `json:"mode"`
	SystemPrompt string `json:"systemPrompt"`
}

func newID() string {
	b := make([]byte, 4)
	_, _ = rand.Read(b)
	return fmt.Sprintf("s%d-%s", time.Now().UnixMilli(), hex.EncodeToString(b))
}

// Create registers a new session; the process starts on the first Send.
func (m *Manager) Create(p CreateParams) (SessionMeta, error) {
	if Lookup(p.Agent) == nil {
		return SessionMeta{}, fmt.Errorf("unknown agent: %s", p.Agent)
	}
	if err := validateLaunch(Lookup(p.Agent), p.Mode, p.SystemPrompt); err != nil {
		return SessionMeta{}, err
	}
	p.Mode = normalizeMode(p.Mode)
	if p.Mode == "" {
		p.Mode = ModeAgent
	}
	if p.Cwd == "" {
		if p.Mode != ModeAssistant && p.Mode != ModeOneshot {
			return SessionMeta{}, errors.New("cwd is required")
		}
		p.Cwd, _ = os.UserHomeDir()
	}
	if st, err := os.Stat(p.Cwd); err != nil || !st.IsDir() {
		return SessionMeta{}, fmt.Errorf("not a directory: %s", p.Cwd)
	}
	m.mu.Lock()
	cfg := m.agentCfg(p.Agent)
	m.mu.Unlock()
	if p.Model == "" {
		p.Model = cfg.Model
	}

	if p.Effort == "" {
		p.Effort = cfg.Effort
	}
	if err := m.validateSettings(p.Agent, p.Cwd, p.Model, p.Effort); err != nil {
		return SessionMeta{}, err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	yolo := cfg.Yolo
	if p.Yolo != nil {
		yolo = *p.Yolo
	}
	if p.Mode == ModeOneshot || p.Mode == ModeAssistant {
		yolo = false
	}
	model := p.Model
	if model == "" {
		model = cfg.Model
	}
	now := m.now().UnixMilli()
	s := newSession(m, SessionMeta{ID: newID(), Agent: p.Agent, Cwd: p.Cwd, Title: p.Title, Created: now, Updated: now,
		Status: StatusIdle, Yolo: yolo, Effort: p.Effort, Model: model, Mode: p.Mode, SystemPrompt: p.SystemPrompt})
	m.sessions[s.meta.ID] = s
	m.saveLocked()
	m.broadcastSessionsLocked()
	return s.meta, nil
}

func (m *Manager) get(id string) (*session, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.sessions[id]
	if s == nil {
		return nil, fmt.Errorf("unknown session: %s", id)
	}
	return s, nil
}

// startOptions resolves everything a launch needs (m.mu held).
func (m *Manager) startOptionsLocked(s *session) (StartOptions, error) {
	a := Lookup(s.meta.Agent)
	cfg := m.agentCfg(s.meta.Agent)
	if cfg.Enabled != nil && !*cfg.Enabled {
		return StartOptions{}, fmt.Errorf("%s is disabled", a.Label())
	}
	bin := ResolveBinary(cfg.Binary, a.DefaultBinary())
	if bin == "" {
		return StartOptions{}, fmt.Errorf("%s is not installed (looked for %q)", a.Label(), a.DefaultBinary())
	}
	var servers []MCPServer
	if m.mcp != nil {
		servers = m.mcp()
	}
	yz := m.cfg.YozakuraMCP == nil || *m.cfg.YozakuraMCP
	var mcp []MCPServer
	haveYZ := false
	for _, srv := range servers {
		isYZ := srv.Name == YozakuraMCPName
		haveYZ = haveYZ || isYZ
		if !isYZ || yz || s.meta.Mode == ModeAssistant {
			mcp = append(mcp, srv)
		}
	}
	if s.meta.Mode == ModeAssistant && !haveYZ {
		if exe, err := os.Executable(); err == nil {
			mcp = append(mcp, MCPServer{Name: YozakuraMCPName, Transport: "stdio", Command: exe, Args: []string{"mcp"}})
		}
	}
	if s.meta.Mode == ModeOneshot {
		mcp = nil
	}
	prompt := s.meta.SystemPrompt
	if s.meta.Mode == ModeAssistant && prompt == "" {
		prompt = DefaultAssistantPrompt
	}
	id := s.meta.ID
	return StartOptions{Binary: bin, Cwd: s.meta.Cwd, Model: s.meta.Model, Effort: s.meta.Effort, ResumeID: s.meta.AgentSessionID, Mode: s.meta.Mode,
		SystemPrompt: prompt, ExtraArgs: cfg.ExtraArgs, MCP: mcp, Env: m.extraEnv,
		Yolo: func() bool {
			m.mu.Lock()
			defer m.mu.Unlock()
			if cur := m.sessions[id]; cur != nil {
				return cur.meta.Yolo
			}
			return false
		}}, nil
}

// Send delivers a user turn, (re)starting the agent process if needed.
func (m *Manager) Send(id, text string, images []string) error {
	s, err := m.get(id)
	if err != nil {
		return err
	}
	return s.send(text, images)
}

// Respond answers a pending permission request.
func (m *Manager) Respond(id, request, decision string) error {
	s, err := m.get(id)
	if err != nil {
		return err
	}
	return s.respond(request, decision)
}

// Cancel interrupts the running turn and denies pending requests.
func (m *Manager) Cancel(id string) error {
	s, err := m.get(id)
	if err != nil {
		return err
	}
	return s.cancel()
}

// CloseSession stops the process; the session stays resumable.
func (m *Manager) CloseSession(id string) error {
	s, err := m.get(id)
	if err != nil {
		return err
	}
	s.close()
	return nil
}

// Delete stops and forgets a session (including its event log).
func (m *Manager) Delete(id string) error {
	s, err := m.get(id)
	if err != nil {
		return err
	}
	s.close()
	m.mu.Lock()
	delete(m.sessions, id)
	_ = os.Remove(m.logPath(id))
	m.saveLocked()
	m.broadcastSessionsLocked()
	m.mu.Unlock()
	return nil
}

// Sessions lists sessions: pinned first, then most recently updated.
func (m *Manager) Sessions() []SessionMeta {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.sessionsLocked()
}

func (m *Manager) sessionsLocked() []SessionMeta {
	out := make([]SessionMeta, 0, len(m.sessions))
	for _, s := range m.sessions {
		out = append(out, s.meta)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Pinned != out[j].Pinned {
			return out[i].Pinned
		}
		if out[i].Updated != out[j].Updated {
			return out[i].Updated > out[j].Updated
		}
		return out[i].ID > out[j].ID
	})
	return out
}

func (m *Manager) broadcastSessionsLocked() { m.broadcast("agents.sessions", m.sessionsLocked()) }

// Shutdown stops every running agent process.
func (m *Manager) Shutdown() {
	m.mu.Lock()
	list := make([]*session, 0, len(m.sessions))
	for _, s := range m.sessions {
		list = append(list, s)
	}
	m.mu.Unlock()
	var wg sync.WaitGroup
	for _, s := range list {
		wg.Add(1)
		go func(s *session) { defer wg.Done(); s.close() }(s)
	}
	wg.Wait()
}
