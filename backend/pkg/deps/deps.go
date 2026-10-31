// Package deps is the dependency list shared by install.sh and
// `yozakura doctor`: packages.tsv names every runtime and build dependency,
// how to detect it and which package provides it per distribution.
package deps

import (
	"context"
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/proc"
)

//go:embed packages.tsv
var table string

// Need classes, see packages.tsv.
const (
	NeedRequired = "required"
	Standard     = "standard"
	Build        = "build"
)

// Compositor-scoped need values: required only when that compositor is
// the configured one.
func Compositors() []string { return []string{"hyprland", "niri", "mango"} }

// DefaultCompositor is used when none is configured.
const DefaultCompositor = "hyprland"

// Dep is one row of packages.tsv.
type Dep struct {
	ID      string
	Need    string
	Checks  []string // alternatives; empty = package query only
	Arch    []string
	Fedora  []string
	Suse    []string
	Debian  []string
	Purpose string
}

// Optional reports whether the dependency belongs to an opt-in feature.
func (d Dep) Optional() bool {
	return d.Need != NeedRequired && d.Need != Standard && d.Need != Build && !d.CompositorScoped()
}

// CompositorScoped reports whether the row is required for one compositor only.
func (d Dep) CompositorScoped() bool {
	for _, c := range Compositors() {
		if d.Need == c {
			return true
		}
	}
	return false
}

// Packages returns the packages for a distro family ("arch", "fedora",
// "suse" or "debian"). An entry src:<name> is built by the installer.
func (d Dep) Packages(distro string) []string {
	switch distro {
	case "arch":
		return d.Arch
	case "fedora":
		return d.Fedora
	case "suse":
		return d.Suse
	case "debian":
		return d.Debian
	}
	return nil
}

// columns is the number of tab-separated fields of a row.
const columns = 8

// All parses the embedded table.
func All() []Dep {
	deps, err := Parse(table)
	if err != nil {
		panic(err) // the table is embedded and covered by tests
	}
	return deps
}

// Parse reads the tab-separated table; "#" lines are comments.
func Parse(text string) ([]Dep, error) {
	var out []Dep
	for i, line := range strings.Split(text, "\n") {
		if strings.TrimSpace(line) == "" || strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.Split(line, "\t")
		if len(f) != columns {
			return nil, fmt.Errorf("packages.tsv:%d: want %d columns, got %d", i+1, columns, len(f))
		}
		out = append(out, Dep{ID: f[0], Need: f[1], Checks: list(f[2], "|"), Arch: list(f[3], " "), Fedora: list(f[4], " "),
			Suse: list(f[5], " "), Debian: list(f[6], " "), Purpose: f[7]})
	}
	return out, nil
}

func list(field, sep string) []string {
	if field == "-" || field == "" {
		return nil
	}
	return strings.Split(field, sep)
}

// Checker answers whether a dependency is present. Its lookups are fields so
// tests can replace them.
type Checker struct {
	LookPath func(string) (string, error)
	Glob     func(string) ([]string, error)
	Fonts    func() string // lower-cased `fc-list : family` output
	Distro   string
	HasPkg   func(distro, pkg string) bool

	fonts *string
}

// NewChecker uses the real system.
func NewChecker() *Checker {
	return &Checker{LookPath: exec.LookPath, Glob: filepath.Glob, Fonts: systemFonts, Distro: Distro(), HasPkg: hasPackage}
}

// Present reports whether any alternative of d is satisfied. Rows without
// checks fall back to the package manager.
func (c *Checker) Present(d Dep) bool {
	if len(d.Checks) == 0 {
		pkgs := d.Packages(c.Distro)
		if len(pkgs) == 0 || c.HasPkg == nil {
			return true // nothing to verify here
		}
		for _, p := range pkgs {
			if strings.HasPrefix(p, "src:") || strings.HasPrefix(p, "flatpak:") {
				continue // not a distro package: only a check can tell
			}
			if !c.HasPkg(c.Distro, p) {
				return false
			}
		}
		return true
	}
	for _, alt := range d.Checks {
		switch {
		case strings.HasPrefix(alt, "font:"):
			if c.fonts == nil {
				f := c.Fonts()
				c.fonts = &f
			}
			if strings.Contains(*c.fonts, strings.ToLower(strings.TrimPrefix(alt, "font:"))) {
				return true
			}
		case strings.HasPrefix(alt, "/"):
			if m, _ := c.Glob(alt); len(m) > 0 {
				return true
			}
		case strings.HasPrefix(alt, "flatpak:"):
			for _, dir := range flatpakDirs() {
				if m, _ := c.Glob(filepath.Join(dir, strings.TrimPrefix(alt, "flatpak:"))); len(m) > 0 {
					return true
				}
			}
		default:
			if _, err := c.LookPath(alt); err == nil {
				return true
			}
		}
	}
	return false
}

// flatpakDirs are the system and the user Flatpak app directories.
func flatpakDirs() []string {
	dirs := []string{"/var/lib/flatpak/app"}
	if home, err := os.UserHomeDir(); err == nil {
		dirs = append(dirs, filepath.Join(home, ".local/share/flatpak/app"))
	}
	return dirs
}

func systemFonts() string {
	out, _ := proc.Run(context.Background(), "fc-list", ":", "family")
	return strings.ToLower(string(out))
}

func hasPackage(distro, pkg string) bool {
	pkg = strings.TrimPrefix(pkg, "aur:")
	switch distro {
	case "arch":
		return proc.Do(context.Background(), "pacman", "-Q", pkg) == nil
	case "fedora", "suse":
		return proc.Do(context.Background(), "rpm", "-q", "--whatprovides", pkg) == nil
	case "debian":
		out, err := proc.Run(context.Background(), "dpkg-query", "-W", "-f=${Status}", pkg)
		return err == nil && strings.HasSuffix(string(out), " installed")
	}
	return true
}

// Distro returns "nixos", "arch", "fedora", "suse", "debian" or "other"
// from /etc/os-release.
func Distro() string {
	data, _ := os.ReadFile("/etc/os-release")
	return distroFromOSRelease(string(data))
}

func distroFromOSRelease(text string) string {
	ids := ""
	for _, line := range strings.Split(text, "\n") {
		if k, v, ok := strings.Cut(line, "="); ok && (k == "ID" || k == "ID_LIKE") {
			ids += " " + strings.Trim(v, `"'`)
		}
	}
	for _, f := range strings.Fields(ids) {
		switch f {
		case "nixos":
			return "nixos"
		case "arch", "archlinux":
			return "arch"
		case "fedora":
			return "fedora"
		case "suse", "opensuse", "opensuse-tumbleweed", "opensuse-leap", "sles":
			return "suse"
		case "debian", "ubuntu":
			return "debian"
		}
	}
	return "other"
}

// InstallHint returns the command that installs pkgs on distro.
func InstallHint(distro string, pkgs []string) string {
	var repo, aur, src, flat []string
	for _, p := range pkgs {
		if name, ok := strings.CutPrefix(p, "flatpak:"); ok {
			flat = append(flat, name)
		} else if name, ok := strings.CutPrefix(p, "aur:"); ok {
			aur = append(aur, name)
		} else if name, ok := strings.CutPrefix(p, "src:"); ok {
			src = append(src, name)
		} else {
			repo = append(repo, p)
		}
	}
	var cmds []string
	switch distro {
	case "arch":
		if len(repo) > 0 {
			cmds = append(cmds, "sudo pacman -S --needed "+strings.Join(repo, " "))
		}
		if len(aur) > 0 {
			cmds = append(cmds, "paru -S "+strings.Join(aur, " ")+"   (or yay)")
		}
	case "fedora":
		if len(repo) > 0 {
			cmds = append(cmds, "sudo dnf copr enable lionheartp/Hyprland && sudo dnf install "+strings.Join(repo, " "))
			for _, p := range repo {
				if p == "niri" || p == "xwayland-satellite" {
					cmds = append(cmds, "niri and xwayland-satellite may need the niri COPR: sudo dnf copr enable yalter/niri")
					break
				}
			}
		}
	case "suse":
		if len(repo) > 0 {
			cmds = append(cmds, "sudo zypper install "+strings.Join(repo, " "))
		}
	case "debian":
		if len(repo) > 0 {
			cmds = append(cmds, "sudo apt install "+strings.Join(repo, " "))
		}
	default:
		return ""
	}
	if len(flat) > 0 {
		cmds = append(cmds, "flatpak install --user flathub "+strings.Join(flat, " "))
	}
	if len(src) > 0 {
		cmds = append(cmds, "re-run install.sh: it builds "+strings.Join(src, ", ")+" from source")
	}
	return strings.Join(cmds, "\n")
}
