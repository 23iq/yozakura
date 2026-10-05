// Package deps is the dependency list shared by install.sh and
// `yozakura doctor`: packages.tsv names every runtime and build dependency,
// how to detect it and which package provides it per distribution.
package deps

import (
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

//go:embed packages.tsv
var table string

// Need classes, see packages.tsv.
const (
	Required = "required"
	Standard = "standard"
	Build    = "build"
)

// Dep is one row of packages.tsv.
type Dep struct {
	ID      string
	Need    string
	Checks  []string // alternatives; empty = package query only
	Arch    []string
	Fedora  []string
	Purpose string
}

// Optional reports whether the dependency belongs to an opt-in feature.
func (d Dep) Optional() bool {
	return d.Need != Required && d.Need != Standard && d.Need != Build
}

// Packages returns the packages for a distro family ("arch" or "fedora").
func (d Dep) Packages(distro string) []string {
	switch distro {
	case "arch":
		return d.Arch
	case "fedora":
		return d.Fedora
	}
	return nil
}

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
		if len(f) != 6 {
			return nil, fmt.Errorf("packages.tsv:%d: want 6 columns, got %d", i+1, len(f))
		}
		out = append(out, Dep{ID: f[0], Need: f[1], Checks: list(f[2], "|"), Arch: list(f[3], " "), Fedora: list(f[4], " "), Purpose: f[5]})
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
		default:
			if _, err := c.LookPath(alt); err == nil {
				return true
			}
		}
	}
	return false
}

func systemFonts() string {
	out, _ := exec.Command("fc-list", ":", "family").Output()
	return strings.ToLower(string(out))
}

func hasPackage(distro, pkg string) bool {
	pkg = strings.TrimPrefix(pkg, "aur:")
	switch distro {
	case "arch":
		return exec.Command("pacman", "-Q", pkg).Run() == nil
	case "fedora":
		return exec.Command("rpm", "-q", "--whatprovides", pkg).Run() == nil
	}
	return true
}

// Distro returns "nixos", "arch", "fedora" or "other" from /etc/os-release.
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
		}
	}
	return "other"
}

// InstallHint returns the command that installs pkgs on distro.
func InstallHint(distro string, pkgs []string) string {
	var repo, aur []string
	for _, p := range pkgs {
		if name, ok := strings.CutPrefix(p, "aur:"); ok {
			aur = append(aur, name)
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
		}
	}
	return strings.Join(cmds, "\n")
}
