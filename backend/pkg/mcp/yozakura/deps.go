// Package yozakura implements the built-in MCP tools that let any AI agent
// read and drive the desktop shell: config, presets, wallpaper, windows and
// workspaces, notifications, clipboard, screenshots, media, volume and DND.
package yozakura

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/svc/usage"
)

// Runner executes external commands. stdin may be nil.
type Runner interface {
	Run(ctx context.Context, stdin []byte, name string, args ...string) ([]byte, error)
	LookPath(name string) bool
}

// Caller performs daemon IPC calls (service.method). It returns an error
// when the daemon is not running.
type Caller interface {
	Call(method string, params any) (json.RawMessage, error)
}

// Deps are the side effects of every tool, injectable for tests.
type Deps struct {
	Run               Runner
	IPC               Caller
	ShellSource       string                     // repo root holding config/defaults/*.js
	ConfigFile        func(domain string) string // live config file of a domain
	PresetsDir        string                     // user presets ($XDG_CONFIG_HOME/<app>/presets)
	ScreenshotDir     string                     // fallback when screenshot.dir IPC fails
	NotificationsFile string
	WallpapersFile    string   // <cache dir>/wallpapers.json
	StateDir          string   // preset trash and trial/edit sessions
	BindsFile         string   // binds.json (special workspace bind conflicts)
	AppDirs           []string // .desktop dirs (nil: the XDG ones)
	UsageDir          string   // AI usage ledger (pkg/svc/usage)
	Now               func() time.Time
}

// DefaultDeps wires the real system.
func DefaultDeps() Deps {
	p := paths.New()
	return Deps{
		Run:               ExecRunner{},
		IPC:               ipcCaller{client: ipc.NewClient(p.SocketPath())},
		ShellSource:       paths.FindShellSource(),
		ConfigFile:        p.Config,
		PresetsDir:        filepath.Join(p.ConfigDir, "presets"),
		ScreenshotDir:     filepath.Join(p.PicturesDir(), "Screenshots"),
		NotificationsFile: p.NotificationsFile(),
		WallpapersFile:    filepath.Join(p.CacheDir, "wallpapers.json"),
		StateDir:          p.StateDir,
		BindsFile:         p.KeybindsFile(),
		UsageDir:          usage.DefaultDir(p.DataDir),
		Now:               time.Now,
	}
}

// ExecRunner runs real processes with a 30 s cap.
type ExecRunner struct{}

func (ExecRunner) Run(ctx context.Context, stdin []byte, name string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, resolveBin(name), args...)
	if stdin != nil {
		cmd.Stdin = bytes.NewReader(stdin)
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg != "" {
			return out, fmt.Errorf("%s: %w: %s", name, err, msg)
		}
		return out, fmt.Errorf("%s: %w", name, err)
	}
	return out, nil
}

func (ExecRunner) LookPath(name string) bool {
	_, err := exec.LookPath(resolveBin(name))
	return err == nil
}

// resolveBin maps the compositor daemon's name to its resolved executable
// (next to this binary first, then PATH); other names are left to PATH.
func resolveBin(name string) string {
	if name == brand.Daemon {
		return paths.DaemonBinary()
	}
	return name
}

type ipcCaller struct{ client *ipc.Client }

func (c ipcCaller) Call(method string, params any) (json.RawMessage, error) {
	return c.client.Call(method, params)
}

var errNoDaemon = errors.New("the Yozakura shell daemon is not running")

func (d Deps) call(method string, params any) (json.RawMessage, error) {
	if d.IPC == nil {
		return nil, errNoDaemon
	}
	return d.IPC.Call(method, params)
}

func (d Deps) now() time.Time {
	if d.Now != nil {
		return d.Now()
	}
	return time.Now()
}

// uiRun sends a shell UI command (same as `yozakura run <cmd>`).
func (d Deps) uiRun(cmd string) error {
	_, err := d.call("ui.run", map[string]any{"command": cmd})
	return err
}

func msToISO(ms float64) string {
	return time.UnixMilli(int64(ms)).Format(time.RFC3339)
}
