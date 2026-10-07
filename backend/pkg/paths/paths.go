package paths

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"yozakura/backend/pkg/brand"
)

// Paths resolves XDG dirs for the shell.
type Paths struct {
	ConfigDir string
	DataDir   string
	StateDir  string
	CacheDir  string
}

func xdg(base, env, def string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp"
	}
	return filepath.Join(home, def)
}

// New resolves the standard dirs for the app (see package brand).
func New() *Paths {
	return &Paths{
		ConfigDir: filepath.Join(xdg("", "XDG_CONFIG_HOME", ".config"), brand.AppID),
		DataDir:   filepath.Join(xdg("", "XDG_DATA_HOME", ".local/share"), brand.AppID),
		StateDir:  filepath.Join(xdg("", "XDG_STATE_HOME", ".local/state"), brand.AppID),
		CacheDir:  filepath.Join(xdg("", "XDG_CACHE_HOME", ".cache"), brand.AppID),
	}
}

// HyprDir is the Hyprland config directory (<XDG_CONFIG_HOME>/hypr), the one
// place every component resolves it from.
func HyprDir() string {
	return filepath.Join(xdg("", "XDG_CONFIG_HOME", ".config"), "hypr")
}

func (p *Paths) Config(domain string) string {
	return filepath.Join(p.ConfigDir, "config", domain+".json")
}

func (p *Paths) SocketPath() string {
	return filepath.Join(RuntimeDir(), brand.AppID+".sock")
}

// RuntimeDir is XDG_RUNTIME_DIR, or /run/user/<uid> when a parent cleared
// the environment (Codex starts MCP servers with a minimal env, so
// `yozakura mcp` would otherwise look for the socket at "/yozakura.sock").
func RuntimeDir() string {
	if d := os.Getenv("XDG_RUNTIME_DIR"); d != "" {
		return d
	}
	if d := fmt.Sprintf("/run/user/%d", os.Getuid()); dirExists(d) {
		return d
	}
	return os.TempDir()
}

func dirExists(path string) bool {
	st, err := os.Stat(path)
	return err == nil && st.IsDir()
}

// QsPidFile stores the PID of the supervised Quickshell child. External
// CLI invocations (e.g. `yozakura brightness ...`) read this file to dispatch
// `qs ipc` calls back into the running shell — without it they would have
// to fall back to scanning processes via pgrep, which is racy.
func (p *Paths) QsPidFile() string {
	return filepath.Join(RuntimeDir(), brand.AppID+"-qs.pid")
}

// DaemonToml is the compositor daemon's config (brand.DaemonConfigFile),
// rendered by the backend and watched by the daemon.
func (p *Paths) DaemonToml() string {
	return filepath.Join(p.DataDir, brand.DaemonConfigFile())
}

// DaemonBinary resolves the compositor daemon executable (brand.Daemon):
// $<APP>_DAEMON_BIN when set, else the directory of the running executable
// (a `make build` tree or an install prefix ships both side by side, also
// through a symlink), else PATH. Falls back to the bare name so exec errors
// still name it.
func DaemonBinary() string {
	if v := os.Getenv(DaemonBinEnv); v != "" {
		return v
	}
	if exe, err := os.Executable(); err == nil {
		dirs := []string{filepath.Dir(exe)}
		if real, err := filepath.EvalSymlinks(exe); err == nil && filepath.Dir(real) != dirs[0] {
			dirs = append(dirs, filepath.Dir(real))
		}
		for _, dir := range dirs {
			if cand := filepath.Join(dir, brand.Daemon); isExecutable(cand) {
				return cand
			}
		}
	}
	if p, err := exec.LookPath(brand.Daemon); err == nil {
		return p
	}
	return brand.Daemon
}

// DaemonBinEnv names the env var holding the resolved daemon executable;
// the backend exports it to Quickshell so the shell runs the same binary.
var DaemonBinEnv = brand.EnvPrefix + "DAEMON_BIN"

// AppBinEnv names the env var holding the running app executable; the
// backend exports it so the shell calls the same binary that started it,
// not whichever one comes first on PATH.
var AppBinEnv = brand.EnvPrefix + "BIN"

func isExecutable(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular() && info.Mode()&0o111 != 0
}

func (p *Paths) StatesFile() string {
	return filepath.Join(p.StateDir, "states.json")
}

func (p *Paths) UsageFile() string {
	return filepath.Join(p.CacheDir, "usage.json")
}

func (p *Paths) NotificationsFile() string {
	return filepath.Join(p.CacheDir, "notifications.json")
}

func (p *Paths) UpdateCheckFile() string {
	return filepath.Join(p.CacheDir, "update_check.json")
}

func (p *Paths) ColorsFile() string {
	return filepath.Join(p.CacheDir, "colors.json")
}

// ClipboardDB is the legacy plaintext database; kept only so the daemon
// can migrate its contents into the encrypted stores and delete it.
func (p *Paths) ClipboardDB() string {
	return filepath.Join(p.DataDir, "clipboard.db")
}

func (p *Paths) ClipboardDataDir() string {
	return filepath.Join(p.DataDir, "clipboard-data")
}

func (p *Paths) ClipboardPinnedDB() string {
	return filepath.Join(p.DataDir, "clipboard-pinned.db")
}

// ClipboardUnpinnedDB is the local-share location for unpinned history
// (used when the tmpfs toggle is off).
func (p *Paths) ClipboardUnpinnedDB() string {
	return filepath.Join(p.DataDir, "clipboard-unpinned.db")
}

// ClipboardTmpDB is the tmpfs location for unpinned history (toggle on).
// It lives under XDG_RUNTIME_DIR so it is wiped on reboot.
func (p *Paths) ClipboardTmpDB() string {
	return filepath.Join(RuntimeDir(), brand.AppID, "clipboard-unpinned.db")
}

func (p *Paths) ClipboardKeyFile() string {
	return filepath.Join(p.StateDir, "clipboard.key")
}

// ClipboardImageCacheDir is a tmpfs cache where image blobs are
// materialized for drag-and-drop / external open.
func (p *Paths) ClipboardImageCacheDir() string {
	return filepath.Join(RuntimeDir(), brand.AppID, "clipboard-img")
}

func (p *Paths) KeysDB() string {
	return filepath.Join(p.DataDir, "keys.db")
}

func (p *Paths) PinnedAppsFile() string {
	return filepath.Join(p.DataDir, "pinnedapps.json")
}

func (p *Paths) ActivePresetFile() string {
	return filepath.Join(p.ConfigDir, "active_preset")
}

func (p *Paths) KeybindsFile() string {
	return filepath.Join(p.ConfigDir, "binds.json")
}

// ShellPathFile stores the repo location for the installed binary
// (/usr/local/bin) to find shell sources and scripts.
func (p *Paths) ShellPathFile() string {
	return filepath.Join(p.DataDir, "shell_repo")
}

func (p *Paths) ModsDir() string {
	return filepath.Join(p.DataDir, "mods")
}

func (p *Paths) ModPackagesDir() string {
	return filepath.Join(p.ModsDir(), "packages")
}

func (p *Paths) ModGenerationsDir() string {
	return filepath.Join(p.ModsDir(), "generations")
}

func (p *Paths) ModPendingActivationFile() string {
	return filepath.Join(p.ModsDir(), "pending-activation.json")
}

func (p *Paths) ModStateFile() string {
	return filepath.Join(p.ConfigDir, "mods.json")
}

func (p *Paths) ModSettingsDir() string {
	return filepath.Join(p.ConfigDir, "mods")
}

// ShellSourceDir returns the absolute path to the Yozakura shell source
// tree (see FindShellSource for the lookup rules). Callers that already
// hold a *Paths simply ignore it; the receiver is unused.
func (p *Paths) ShellSourceDir() string {
	return FindShellSource()
}

// userDir reads a directory entry from ~/.config/user-dirs.dirs,
// falling back to ~/ <def>.
func userDir(key, def string) string {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp"
	}
	fallback := filepath.Join(home, def)

	data, err := os.ReadFile(filepath.Join(home, ".config", "user-dirs.dirs"))
	if err != nil {
		return fallback
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "XDG_"+key+"_DIR") {
			continue
		}
		eq := strings.Index(line, "=")
		if eq < 0 {
			continue
		}
		val := strings.TrimSpace(line[eq+1:])
		val = strings.Trim(val, `"'`)
		switch {
		case strings.HasPrefix(val, "$HOME"):
			return filepath.Join(home, strings.TrimPrefix(strings.TrimPrefix(val, "$HOME"), "/"))
		case strings.HasPrefix(val, "/"):
			return val
		}
	}
	return fallback
}

// PicturesDir mirrors xdg-user-dir PICTURES.
func (p *Paths) PicturesDir() string {
	return userDir("PICTURES", "Pictures")
}

// VideosDir mirrors xdg-user-dir VIDEOS.
func (p *Paths) VideosDir() string {
	return userDir("VIDEOS", "Videos")
}
