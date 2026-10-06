// Package term is the "term" IPC service: terminal prompt presets, previews
// and the writer that follows the theme (see backend/pkg/termlook).
//
// IPC (service "term"); the terminal domain is config/terminal.json:
//
//	presets {}                       -> [{id, name, description, nerdFont, lines}]
//	preview {engine?, prompt?, width?} -> {left: [[span]], right: [span], exact, engine, reason}
//	                                    (engine/prompt default to the config; a span is
//	                                    {text, fg, bg, bold, italic, underline})
//	apply {}                         -> Status  (writes the prompt config and the fish hook
//	                                    when terminal.enabled, else removes the hook)
//	status {}                        -> Status
//
// Status is {enabled, engine, fishInstalled, fishIsLoginShell, engineInstalled:
// {starship, ohmyposh}, foreignPromptInit, foreignFile, hookPath, hookPresent}.
// Installing an engine or fish is not done here: the UI calls extras.install
// (ids starship, oh-my-posh, fish) and extras.setLoginShell.
//
// The service also watches colors.json (and terminal.json): the prompt is
// re-rendered when the palette changes while the prompt is enabled.
package term

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/termlook"
)

var presetID = regexp.MustCompile(`^[a-z0-9-]+$`)

// Options are the host bindings (faked in tests).
type Options struct {
	ConfigFile string // terminal.json
	ColorsFile string // colors.json
	PresetsDir string // assets/terminal/prompts; "" = the shell source
	Env        termlook.Env
	Passwd     func() ([]byte, error) // /etc/passwd
	User       func() string          // current user name
	Debounce   time.Duration
}

// Status is the state the settings page shows.
type Status struct {
	Enabled           bool            `json:"enabled"`
	Engine            string          `json:"engine"`
	FishInstalled     bool            `json:"fishInstalled"`
	FishIsLoginShell  bool            `json:"fishIsLoginShell"`
	EngineInstalled   map[string]bool `json:"engineInstalled"`
	ForeignPromptInit bool            `json:"foreignPromptInit"`
	ForeignFile       string          `json:"foreignFile,omitempty"`
	HookPath          string          `json:"hookPath"`
	HookPresent       bool            `json:"hookPresent"`
}

// Service is the term IPC service.
type Service struct {
	o  Options
	mu sync.Mutex // one write at a time

	stop chan struct{}
	done chan struct{}
	wg   sync.WaitGroup // the initial apply
}

// NewService uses the real host.
func NewService(p *paths.Paths) *Service {
	home, _ := os.UserHomeDir()
	return New(Options{
		ConfigFile: p.Config("terminal"),
		ColorsFile: p.ColorsFile(),
		Env: termlook.Env{
			Home: home, ConfigHome: xdgDir("XDG_CONFIG_HOME", home, ".config"),
			CacheHome: xdgDir("XDG_CACHE_HOME", home, ".cache"), AppID: brand.AppID,
			LookPath: func(bin string) (string, bool) {
				path, err := exec.LookPath(bin)
				return path, err == nil
			},
		},
		Passwd: func() ([]byte, error) { return os.ReadFile("/etc/passwd") },
		User: func() string {
			if u, err := user.Current(); err == nil {
				return u.Username
			}
			return ""
		},
	})
}

// New returns a service with explicit options.
func New(o Options) *Service {
	if o.Debounce == 0 {
		o.Debounce = 300 * time.Millisecond
	}
	return &Service{o: o}
}

func xdgDir(env, home, def string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	return filepath.Join(home, def)
}

// Register exposes the service over IPC.
func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "term",
		Methods: map[string]ipc.HandlerFunc{
			"presets": s.presets, "preview": s.preview, "apply": s.apply, "status": s.status,
		},
		Async: map[string]bool{"preview": true, "apply": true, "status": true},
	})
}

func (s *Service) presetsDir() string {
	if s.o.PresetsDir != "" {
		return s.o.PresetsDir
	}
	return filepath.Join(paths.FindShellSource(), "assets", "terminal", "prompts")
}

// config is the terminal domain subset the service reads; missing keys keep
// the defaults of config/defaults/terminal.js.
func (s *Service) config() termlook.Config {
	c := termlook.Config{Engine: termlook.EngineStarship, Prompt: "sakura-powerline", Greeting: "none"}
	data, err := os.ReadFile(s.o.ConfigFile)
	if err != nil {
		return c
	}
	var raw struct {
		Enabled  *bool   `json:"enabled"`
		Engine   *string `json:"engine"`
		Prompt   *string `json:"prompt"`
		Greeting *string `json:"greeting"`
	}
	if json.Unmarshal(data, &raw) != nil {
		return c
	}
	if raw.Enabled != nil {
		c.Enabled = *raw.Enabled
	}
	if raw.Engine != nil {
		c.Engine = *raw.Engine
	}
	if raw.Prompt != nil {
		c.Prompt = *raw.Prompt
	}
	if raw.Greeting != nil {
		c.Greeting = *raw.Greeting
	}
	return c
}

func (s *Service) palette() (termlook.Palette, error) {
	data, err := os.ReadFile(s.o.ColorsFile)
	if err != nil {
		return nil, fmt.Errorf("no palette yet: %w", err)
	}
	return termlook.PaletteFromColorsJSON(data)
}

func (s *Service) loadPresets() ([]termlook.Preset, error) {
	return termlook.LoadPresets(s.presetsDir())
}

type presetInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	NerdFont    bool   `json:"nerdFont"`
	Lines       int    `json:"lines"`
}

func (s *Service) presets(json.RawMessage) (any, error) {
	ps, err := s.loadPresets()
	if err != nil {
		return nil, err
	}
	out := make([]presetInfo, 0, len(ps))
	for _, p := range ps {
		out = append(out, presetInfo{p.ID, p.Name, p.Description, p.NerdFont, p.Lines})
	}
	return out, nil
}

type spanJSON struct {
	Text      string `json:"text"`
	FG        string `json:"fg,omitempty"`
	BG        string `json:"bg,omitempty"`
	Bold      bool   `json:"bold,omitempty"`
	Italic    bool   `json:"italic,omitempty"`
	Underline bool   `json:"underline,omitempty"`
}

func spans(in []termlook.Span) []spanJSON {
	out := make([]spanJSON, 0, len(in))
	for _, sp := range in {
		out = append(out, spanJSON{sp.Text, sp.FG, sp.BG, sp.Bold, sp.Italic, sp.Underline})
	}
	return out
}

type previewJSON struct {
	Left   [][]spanJSON `json:"left"`
	Right  []spanJSON   `json:"right"`
	Exact  bool         `json:"exact"`
	Engine string       `json:"engine"`
	Reason string       `json:"reason,omitempty"`
}

func (s *Service) preview(params json.RawMessage) (any, error) {
	var p struct {
		Engine string `json:"engine"`
		Prompt string `json:"prompt"`
		Width  int    `json:"width"`
	}
	if len(params) > 0 {
		if err := json.Unmarshal(params, &p); err != nil {
			return nil, err
		}
	}
	cfg := s.config()
	if p.Engine != "" {
		cfg.Engine = p.Engine
	}
	if p.Prompt != "" {
		cfg.Prompt = p.Prompt
	}
	if cfg.Engine != termlook.EngineStarship && cfg.Engine != termlook.EngineOMP {
		return nil, fmt.Errorf("unknown engine %q (starship or ohmyposh)", cfg.Engine)
	}
	if !presetID.MatchString(cfg.Prompt) {
		return nil, fmt.Errorf("invalid prompt preset id %q", cfg.Prompt)
	}
	ps, err := s.loadPresets()
	if err != nil {
		return nil, err
	}
	preset, ok := findPreset(ps, cfg.Prompt)
	if !ok {
		return nil, fmt.Errorf("unknown prompt preset %q", cfg.Prompt)
	}
	pal, err := s.palette()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	res, err := termlook.Preview(ctx, cfg, preset, pal, s.o.Env, p.Width)
	if err != nil {
		return nil, err
	}
	out := previewJSON{Left: [][]spanJSON{}, Right: spans(res.Right), Exact: res.Exact, Engine: res.Engine, Reason: res.Reason}
	for _, line := range res.Left {
		out.Left = append(out.Left, spans(line))
	}
	return out, nil
}

func findPreset(ps []termlook.Preset, id string) (termlook.Preset, bool) {
	for _, p := range ps {
		if p.ID == id {
			return p, true
		}
	}
	return termlook.Preset{}, false
}

// Apply writes the prompt files for the current config and palette (the
// hook is removed when the prompt is disabled).
func (s *Service) Apply() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	cfg := s.config()
	var pal termlook.Palette
	var ps []termlook.Preset
	if cfg.Enabled {
		var err error
		if pal, err = s.palette(); err != nil {
			return err
		}
		if ps, err = s.loadPresets(); err != nil {
			return err
		}
	}
	return termlook.Apply(cfg, pal, ps, s.o.Env)
}

func (s *Service) apply(json.RawMessage) (any, error) {
	if err := s.Apply(); err != nil {
		return nil, err
	}
	return s.currentStatus(), nil
}

func (s *Service) status(json.RawMessage) (any, error) { return s.currentStatus(), nil }

var foreignInit = regexp.MustCompile(`(^|[^\w-])(starship|oh-my-posh)\s+init\s+fish\b`)

func (s *Service) currentStatus() Status {
	cfg := s.config()
	env := s.o.Env
	st := Status{Enabled: cfg.Enabled, Engine: cfg.Engine, EngineInstalled: map[string]bool{}, HookPath: termlook.HookFile(env)}
	_, st.FishInstalled = env.LookPath("fish")
	_, st.EngineInstalled[termlook.EngineStarship] = env.LookPath("starship")
	_, st.EngineInstalled[termlook.EngineOMP] = env.LookPath("oh-my-posh")
	_, err := os.Stat(st.HookPath)
	st.HookPresent = err == nil
	st.FishIsLoginShell = s.fishIsLoginShell()
	st.ForeignFile = foreignPromptFile(filepath.Join(env.ConfigHome, "fish"), st.HookPath)
	st.ForeignPromptInit = st.ForeignFile != ""
	return st
}

// fishIsLoginShell reads the user's passwd entry.
func (s *Service) fishIsLoginShell() bool {
	if s.o.Passwd == nil || s.o.User == nil {
		return false
	}
	name := s.o.User()
	data, err := s.o.Passwd()
	if name == "" || err != nil {
		return false
	}
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.Split(line, ":")
		if len(f) >= 7 && f[0] == name {
			return filepath.Base(f[6]) == "fish"
		}
	}
	return false
}

// foreignPromptFile returns the first of config.fish and conf.d/*.fish
// (other than our hook) that initializes starship or oh-my-posh itself.
func foreignPromptFile(fishDir, hook string) string {
	files := []string{filepath.Join(fishDir, "config.fish")}
	if more, err := filepath.Glob(filepath.Join(fishDir, "conf.d", "*.fish")); err == nil {
		files = append(files, more...)
	}
	for _, f := range files {
		if f == hook {
			continue
		}
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(data), "\n") {
			if t := strings.TrimSpace(line); !strings.HasPrefix(t, "#") && foreignInit.MatchString(t) {
				return f
			}
		}
	}
	return ""
}

var errStarted = errors.New("term: already started")

// Start applies the prompt once when enabled and re-applies it whenever
// colors.json or terminal.json changes, until Stop.
func (s *Service) Start() error {
	s.mu.Lock()
	if s.stop != nil {
		s.mu.Unlock()
		return errStarted
	}
	s.stop, s.done = make(chan struct{}), make(chan struct{})
	stop, done := s.stop, s.done
	s.mu.Unlock()
	w, err := newWatcher(stop, done, []string{s.o.ColorsFile, s.o.ConfigFile}, s.o.Debounce, s.onChange)
	if err != nil {
		s.mu.Lock()
		s.stop, s.done = nil, nil
		s.mu.Unlock()
		return err
	}
	go w.run()
	if s.config().Enabled {
		s.wg.Add(1)
		go func() {
			defer s.wg.Done()
			s.reapply()
		}()
	}
	return nil
}

// Stop ends the watcher.
func (s *Service) Stop() {
	s.mu.Lock()
	stop, done := s.stop, s.done
	s.stop = nil
	s.mu.Unlock()
	if stop == nil {
		return
	}
	close(stop)
	<-done
	s.wg.Wait()
}

func (s *Service) onChange(file string) {
	// A colors change matters only while the prompt is on; a terminal.json
	// change always (turning it off removes the hook).
	if file == s.o.ColorsFile && !s.config().Enabled {
		return
	}
	s.reapply()
}

func (s *Service) reapply() {
	if err := s.Apply(); err != nil {
		log.Printf("[yozakura] term: %v", err)
	}
}
