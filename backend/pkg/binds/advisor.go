package binds

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/commands"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/specials"
	"yozakura/backend/pkg/yozd/ipc"
)

// App is an installed application (a .desktop entry).
type App struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// Routine is a saved routine a bind can run (svc/routines provides them;
// the provider sets the action that runs it).
type Routine struct {
	ID       string    `json:"id"`
	Name     string    `json:"name"`
	Keywords string    `json:"keywords,omitempty"`
	Action   ActionRef `json:"action"`
}

// Advisor answers bind questions and edits binds.json. Every side effect is
// a field, so tests inject them.
type Advisor struct {
	Catalog *Catalog
	File    string // binds.json
	// LockFile serialises writers ("" = no lock).
	LockFile string
	AppID    string // binds.json app root ("" = brand.AppID)
	Lang     string // label language ("" = en)
	// Compositor lists the compositor's binds (nil = unavailable).
	Compositor func() ([]ipc.Bind, error)
	// CompositorName is "hyprland", "niri", "mango" or "" (unknown).
	CompositorName string
	Apps           func() []App
	Commands       func() []commands.Command
	Routines       func() []Routine
	// Specials lists the special workspaces (their binds are listed
	// read-only, source shell-special).
	Specials func() ([]specials.Special, error)
}

func (a *Advisor) appID() string {
	if a.AppID != "" {
		return a.AppID
	}
	return brand.AppID
}

func (a *Advisor) lang() string {
	if a.Lang != "" {
		return a.Lang
	}
	return "en"
}

// New wires the real system for the shell source at root.
func New(root string) (*Advisor, error) {
	cat, err := LoadCatalog(root)
	if err != nil {
		return nil, err
	}
	p := paths.New()
	return &Advisor{
		Catalog:        cat,
		File:           p.KeybindsFile(),
		LockFile:       filepath.Join(p.StateDir, "binds.lock"),
		Compositor:     DaemonBinds,
		CompositorName: DetectCompositor(),
		Apps:           InstalledApps,
		Commands:       CommandsIn(root),
		Specials: func() ([]specials.Special, error) {
			c, err := catalog.Load(root)
			if err != nil {
				return nil, err
			}
			return specials.Store{Config: &catalog.Store{Cat: c, File: p.Config}}.Load()
		},
	}, nil
}

// DaemonBinds asks yozd for the compositor's binds (`yozd config
// list-binds`).
func DaemonBinds() ([]ipc.Bind, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, paths.DaemonBinary(), "config", "list-binds").Output()
	if err != nil {
		return nil, fmt.Errorf("%s: %v", brand.Daemon, err)
	}
	return ParseDaemonBinds(out)
}

// ParseDaemonBinds decodes `yozd config list-binds` (which prints
// "Error: ..." on failure).
func ParseDaemonBinds(out []byte) ([]ipc.Bind, error) {
	text := strings.TrimSpace(string(out))
	if msg, ok := strings.CutPrefix(text, "Error"); ok {
		return nil, fmt.Errorf("%s: %s", brand.Daemon, strings.TrimLeft(msg, ": "))
	}
	var binds []ipc.Bind
	if err := json.Unmarshal([]byte(text), &binds); err != nil {
		return nil, fmt.Errorf("%s config list-binds: %v", brand.Daemon, err)
	}
	return binds, nil
}

// DetectCompositor names the running compositor from its environment.
func DetectCompositor() string {
	switch {
	case os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "":
		return "hyprland"
	case os.Getenv("NIRI_SOCKET") != "":
		return "niri"
	case strings.Contains(strings.ToLower(os.Getenv("XDG_CURRENT_DESKTOP")), "mango"):
		return "mango"
	}
	return ""
}

// InstalledApps lists the installed .desktop applications.
func InstalledApps() []App { return AppsIn(specials.ApplicationDirs())() }

// AppsIn lists the .desktop applications of dirs (first dir wins).
func AppsIn(dirs []string) func() []App {
	return func() []App {
		var out []App
		for _, e := range specials.Entries(dirs) {
			out = append(out, App{ID: e.ID, Name: e.Name})
		}
		return out
	}
}

// CommandsIn lists the launcher commands of the shell source at root.
func CommandsIn(root string) func() []commands.Command {
	return func() []commands.Command {
		reg, err := commands.Load(root)
		if err != nil {
			return nil
		}
		return reg.Commands
	}
}

// Filter keeps the binds of a source ("" = all) whose combo, label, name or
// action id contains text (case-insensitive; "" = all).
func Filter(list []Bind, source, text string) []Bind {
	text = strings.ToLower(strings.TrimSpace(text))
	out := []Bind{}
	for _, b := range list {
		if source != "" && b.Source != source {
			continue
		}
		if text != "" {
			hay := strings.ToLower(b.Combo + " " + b.Label + " " + b.Name)
			for _, r := range b.Actions {
				hay += " " + r.ID
			}
			if !strings.Contains(hay, text) {
				continue
			}
		}
		out = append(out, b)
	}
	return out
}
