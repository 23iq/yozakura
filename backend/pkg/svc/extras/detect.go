package extras

import (
	"os"
	"path/filepath"
	"strings"
)

// State is the install state of one catalog entry.
type State string

// Entry states.
const (
	StateInstalled   State = "installed"
	StateMissing     State = "missing"
	StateInstalling  State = "installing"
	StateFailed      State = "failed"
	StateUnavailable State = "unavailable"
)

// Status is the detected state of one entry.
type Status struct {
	ID      string
	State   State
	Source  string // pkg|flatpak|npm|bin|path
	Version string
	Reason  string
}

// Probe queries the host; every method must degrade to "not found".
type Probe interface {
	LookPath(bin string) bool       // PATH + ~/.local/bin + ~/.npm-global/bin
	InstalledPkgs() map[string]bool // pacman -Qq or rpm -qa
	Flatpaks() map[string]bool      // flatpak list --app
	Glob(pattern string) bool
}

// Detect resolves the state of every catalog entry (including hidden ones).
func Detect(c *Catalog, p Platform, probe Probe) map[string]Status {
	out := make(map[string]Status, len(c.Entries))
	pkgs := probe.InstalledPkgs()
	flat := probe.Flatpaks()
	for _, e := range c.Entries {
		out[e.ID] = detectEntry(e, p, probe, pkgs, flat)
	}
	return out
}

func detectEntry(e Entry, p Platform, probe Probe, pkgs, flat map[string]bool) Status {
	st := Status{ID: e.ID}
	if src := firstSource(e, probe, pkgs, flat); src != "" {
		st.State, st.Source = StateInstalled, src
		return st
	}
	if len(e.Only) > 0 && !contains(e.Only, p.Distro) {
		st.State, st.Reason = StateUnavailable, "only_distro"
		return st
	}
	if !hasMethod(e.Install, p) {
		st.State, st.Reason = StateUnavailable, "no_method"
		return st
	}
	st.State = StateMissing
	return st
}

func firstSource(e Entry, probe Probe, pkgs, flat map[string]bool) string {
	for _, b := range e.Detect.Bins {
		if probe.LookPath(b) {
			return "bin"
		}
	}
	for _, n := range e.Detect.Pkgs {
		if pkgs[n] {
			return "pkg"
		}
	}
	if e.Detect.Flatpak != "" && flat[e.Detect.Flatpak] {
		return "flatpak"
	}
	for _, g := range e.Detect.Paths {
		if probe.Glob(g) {
			return "path"
		}
	}
	return ""
}

// hasMethod reports whether the entry can be installed on this platform
// (structural: tool availability is handled at plan time).
func hasMethod(in Install, p Platform) bool {
	if in.Script != nil || in.Shell != "" || in.Npm != "" || in.Flatpak != "" {
		return true
	}
	switch p.Distro {
	case "arch":
		return in.Arch != nil
	case "fedora":
		return in.Fedora != nil
	}
	return false
}

func contains(l []string, s string) bool {
	for _, v := range l {
		if v == s {
			return true
		}
	}
	return false
}

func expandHome(pat string) string {
	if strings.HasPrefix(pat, "~/") {
		if h, err := os.UserHomeDir(); err == nil {
			return filepath.Join(h, pat[2:])
		}
	}
	return pat
}
