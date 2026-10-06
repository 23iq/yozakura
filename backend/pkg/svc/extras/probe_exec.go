package extras

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const probeTimeout = 10 * time.Second

// ExecProbe is the real Probe: it shells out with timeouts and treats every
// failure (missing tool, offline, timeout) as "nothing found".
type ExecProbe struct{}

// LookPath checks PATH, ~/.local/bin and ~/.npm-global/bin.
func (ExecProbe) LookPath(bin string) bool {
	if _, err := exec.LookPath(bin); err == nil {
		return true
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return false
	}
	for _, d := range []string{".local/bin", ".npm-global/bin"} {
		if fi, err := os.Stat(filepath.Join(home, d, bin)); err == nil && !fi.IsDir() {
			return true
		}
	}
	return false
}

// InstalledPkgs lists installed native packages (pacman or rpm).
func (ExecProbe) InstalledPkgs() map[string]bool {
	if _, err := exec.LookPath("pacman"); err == nil {
		return lines(runOut("pacman", "-Qq"))
	}
	if _, err := exec.LookPath("rpm"); err == nil {
		return lines(runOut("rpm", "-qa", "--qf", "%{NAME}\n"))
	}
	return map[string]bool{}
}

// Flatpaks lists installed flatpak app ids (user and system).
func (ExecProbe) Flatpaks() map[string]bool {
	if _, err := exec.LookPath("flatpak"); err != nil {
		return map[string]bool{}
	}
	return lines(runOut("flatpak", "list", "--app", "--columns=application"))
}

// Glob reports whether the pattern ("~" allowed) matches anything.
func (ExecProbe) Glob(pattern string) bool {
	m, err := filepath.Glob(expandHome(pattern))
	return err == nil && len(m) > 0
}

// FontFamilies lists the fontconfig font families (one family name per
// entry; fc-list joins a font's localized names with commas).
func (ExecProbe) FontFamilies() []string {
	var out []string
	for l := range lines(runOut("fc-list", ":", "family")) {
		for _, f := range strings.Split(l, ",") {
			if f = strings.TrimSpace(f); f != "" {
				out = append(out, f)
			}
		}
	}
	return out
}

func runOut(name string, args ...string) string {
	ctx, cancel := context.WithTimeout(context.Background(), probeTimeout)
	defer cancel()
	var buf bytes.Buffer
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdout = &buf
	if err := cmd.Run(); err != nil {
		return ""
	}
	return buf.String()
}

func lines(s string) map[string]bool {
	m := map[string]bool{}
	for _, l := range strings.Split(s, "\n") {
		if l = strings.TrimSpace(l); l != "" {
			m[l] = true
		}
	}
	return m
}
