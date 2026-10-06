package ipc

import (
	"os"
	"path/filepath"
	"strings"
)

// Bind is one key binding the compositor knows about (read-only listing for
// the bind advisor, `Config.ListBinds`). Modifiers use the shell's names
// (SUPER, CTRL, ALT, SHIFT); Key is as the compositor reports it.
type Bind struct {
	Modifiers   []string `json:"modifiers"`
	Key         string   `json:"key"`
	Dispatcher  string   `json:"dispatcher,omitempty"`
	Arg         string   `json:"arg,omitempty"`
	Description string   `json:"description,omitempty"`
	Submap      string   `json:"submap,omitempty"`
	Release     bool     `json:"release,omitempty"`
	Locked      bool     `json:"locked,omitempty"`
	Mouse       bool     `json:"mouse,omitempty"`
	// Source is where the bind was read: "ipc" (live compositor state) or
	// the config file it came from (best-effort parsers).
	Source string `json:"source,omitempty"`
}

// BindLister is implemented by compositors that can list their key binds.
// Others answer Config.ListBinds with ErrNotSupported.
type BindLister interface {
	ListBinds() ([]Bind, error)
}

// ModsFromMask decodes an X11/Hyprland modifier mask.
func ModsFromMask(mask int) []string {
	out := []string{}
	for _, m := range []struct {
		bit  int
		name string
	}{{64, "SUPER"}, {4, "CTRL"}, {8, "ALT"}, {1, "SHIFT"}} {
		if mask&m.bit != 0 {
			out = append(out, m.name)
		}
	}
	return out
}

// NormalizeMod maps a modifier spelling (Mod, Mod4, Super, Win, Control,
// Mod1...) to the shell's name; ok is false for anything else.
func NormalizeMod(m string) (string, bool) {
	switch strings.ToUpper(strings.TrimSpace(m)) {
	case "SUPER", "MOD", "MOD4", "WIN", "LOGO", "META":
		return "SUPER", true
	case "CTRL", "CONTROL":
		return "CTRL", true
	case "ALT", "MOD1":
		return "ALT", true
	case "SHIFT":
		return "SHIFT", true
	}
	return "", false
}

// ConfigHome is $XDG_CONFIG_HOME (or ~/.config).
func ConfigHome() string {
	if d := os.Getenv("XDG_CONFIG_HOME"); d != "" {
		return d
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config")
}

// ExpandPath resolves "~/" and paths relative to the including file's dir.
func ExpandPath(p, relTo string) string {
	p = strings.Trim(strings.TrimSpace(p), `"'`)
	if strings.HasPrefix(p, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, p[2:])
	}
	if !filepath.IsAbs(p) {
		return filepath.Join(relTo, p)
	}
	return p
}
