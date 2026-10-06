// Package sysinstall is the logic behind the privileged `sys` helper that
// runs as root under pkexec. It only turns catalog ids and fixed verbs into
// package-manager argv; every value handed to a root command is re-validated
// here, independently of the catalog's own validation.
package sysinstall

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strings"

	"yozakura/backend/pkg/svc/extras"
)

var (
	reID   = regexp.MustCompile(`^[a-z0-9-]+$`)
	rePkg  = regexp.MustCompile(`^[a-z0-9@._+-]+$`)
	reUnit = regexp.MustCompile(`^[a-zA-Z0-9@._-]+$`)
)

// ErrNeedsMultilib reports an arch entry whose packages live in [multilib]
// while it is disabled; the caller runs `sys enable-multilib` first.
var ErrNeedsMultilib = errors.New("needs multilib")

// ValidPkg reports whether name is safe to pass to pacman/dnf as a package
// argument (never an option).
func ValidPkg(name string) bool {
	return rePkg.MatchString(name) && !strings.HasPrefix(name, "-")
}

// ValidUnit reports whether name is safe to pass to systemctl as a unit.
func ValidUnit(name string) bool {
	return reUnit.MatchString(name) && !strings.HasPrefix(name, "-")
}

// ResolveSystemPkgs maps catalog ids to the native packages and system units
// of the platform. GPU variants override the distro method's packages. It
// fails on an invalid or unknown id, on an entry without a native (repo)
// method for this distro, and on unsafe package/unit names.
func ResolveSystemPkgs(c *extras.Catalog, p extras.Platform, ids []string) (pkgs []string, units []string, err error) {
	if len(ids) == 0 {
		return nil, nil, errors.New("no ids given")
	}
	seenPkg, seenUnit := map[string]bool{}, map[string]bool{}
	for _, id := range ids {
		if !reID.MatchString(id) || strings.HasPrefix(id, "-") {
			return nil, nil, fmt.Errorf("invalid id %q", id)
		}
		e, ok := c.Get(id)
		if !ok {
			return nil, nil, fmt.Errorf("unknown id %q", id)
		}
		list, err := nativePkgs(e, p)
		if err != nil {
			return nil, nil, err
		}
		for _, name := range list {
			// dnf reads a leading "@" as a group or module.
			if !ValidPkg(name) || (p.Distro == "fedora" && strings.HasPrefix(name, "@")) {
				return nil, nil, fmt.Errorf("%s: bad package name %q", id, name)
			}
			if !seenPkg[name] {
				seenPkg[name] = true
				pkgs = append(pkgs, name)
			}
		}
		if u := e.Install.Service; u != "" {
			if !ValidUnit(u) {
				return nil, nil, fmt.Errorf("%s: bad unit name %q", id, u)
			}
			if !seenUnit[u] {
				seenUnit[u] = true
				units = append(units, u)
			}
		}
	}
	return pkgs, units, nil
}

func nativePkgs(e extras.Entry, p extras.Platform) ([]string, error) {
	notSystem := fmt.Errorf("%s: not a system package on %s", e.ID, p.Distro)
	if len(e.Only) > 0 && !contains(e.Only, p.Distro) {
		return nil, notSystem
	}
	var m *extras.Method
	switch p.Distro {
	case "arch":
		m = e.Install.Arch
	case "fedora":
		m = e.Install.Fedora
	default:
		return nil, notSystem
	}
	if m == nil {
		return nil, notSystem
	}
	pkgs := m.Pkgs
	if v, ok := m.GPU[p.GPU]; ok && len(v) > 0 {
		pkgs = v
	}
	if len(pkgs) == 0 {
		return nil, notSystem
	}
	if p.Distro == "arch" && e.Multilib && !p.Multilib {
		return nil, fmt.Errorf("%s: %w", e.ID, ErrNeedsMultilib)
	}
	return pkgs, nil
}

func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}

// EnableMultilib uncomments the "#[multilib]" section header of pacman.conf
// and the commented Include/Server lines right under it. When the section is
// already enabled it returns conf unchanged and false. It fails when there is
// no commented header or nothing under it to uncomment.
func EnableMultilib(conf []byte) ([]byte, bool, error) {
	lines := strings.Split(string(conf), "\n")
	for _, l := range lines {
		if strings.TrimSpace(l) == "[multilib]" {
			return conf, false, nil
		}
	}
	for i, l := range lines {
		if !strings.HasPrefix(strings.TrimSpace(l), "#") || uncomment(l) != "[multilib]" {
			continue
		}
		lines[i] = "[multilib]"
		repos := 0
		for j := i + 1; j < len(lines); j++ {
			body := uncomment(lines[j])
			if !strings.HasPrefix(strings.TrimSpace(lines[j]), "#") ||
				!(strings.HasPrefix(body, "Include") || strings.HasPrefix(body, "Server")) {
				break
			}
			lines[j] = body
			repos++
		}
		if repos == 0 {
			return conf, false, errors.New("pacman.conf: no Include/Server line under #[multilib]")
		}
		return []byte(strings.Join(lines, "\n")), true, nil
	}
	return conf, false, errors.New("pacman.conf: no #[multilib] section to enable")
}

func uncomment(line string) string {
	t := strings.TrimSpace(line)
	if !strings.HasPrefix(t, "#") {
		return t
	}
	return strings.TrimSpace(strings.TrimLeft(t, "#"))
}

// ValidShell reports whether shell is an absolute path listed verbatim in
// /etc/shells (comments and blank lines ignored).
func ValidShell(etcShells []byte, shell string) bool {
	if !strings.HasPrefix(shell, "/") || strings.ContainsAny(shell, " \t\r\n") {
		return false
	}
	sc := bufio.NewScanner(bytes.NewReader(etcShells))
	for sc.Scan() {
		if strings.TrimSpace(sc.Text()) == shell {
			return true
		}
	}
	return false
}

// streamLines calls emit for each line of r, splitting on \n and \r so
// progress bars redrawn with \r arrive as separate lines.
func streamLines(r io.Reader, emit func(string)) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), 1024*1024)
	sc.Split(func(data []byte, atEOF bool) (int, []byte, error) {
		if i := bytes.IndexAny(data, "\r\n"); i >= 0 {
			adv := i + 1
			if data[i] == '\r' && i+1 < len(data) && data[i+1] == '\n' {
				adv++
			} else if data[i] == '\r' && i+1 == len(data) && !atEOF {
				return 0, nil, nil // wait: might be \r\n split across reads
			}
			return adv, data[:i], nil
		}
		if atEOF && len(data) > 0 {
			return len(data), data, nil
		}
		return 0, nil, nil
	})
	for sc.Scan() {
		emit(sc.Text())
	}
}
