package niri

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// niri has no IPC request listing binds: ListBinds reads the `binds {}`
// blocks of the config file (best effort: $NIRI_CONFIG or
// <config>/niri/config.kdl, following `include` lines).
func (n *Niri) ListBinds() ([]ipc.Bind, error) {
	path := os.Getenv("NIRI_CONFIG")
	if path == "" {
		path = filepath.Join(ipc.ConfigHome(), "niri", "config.kdl")
	}
	return ReadBinds(path), nil
}

// ReadBinds parses the binds of a niri KDL config (and its includes).
func ReadBinds(path string) []ipc.Bind {
	out := []ipc.Bind{}
	readBinds(path, map[string]bool{}, &out)
	return out
}

var (
	kdlInclude = regexp.MustCompile(`^include\s+"([^"]+)"`)
	kdlTitle   = regexp.MustCompile(`hotkey-overlay-title="([^"]*)"`)
	kdlLocked  = regexp.MustCompile(`allow-when-locked=true`)
)

func readBinds(path string, seen map[string]bool, out *[]ipc.Bind) {
	if seen[path] || len(seen) > 16 {
		return
	}
	seen[path] = true
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	*out = append(*out, ParseBinds(string(data), path)...)
	for _, line := range strings.Split(string(data), "\n") {
		if m := kdlInclude.FindStringSubmatch(strings.TrimSpace(line)); m != nil {
			readBinds(ipc.ExpandPath(m[1], filepath.Dir(path)), seen, out)
		}
	}
}

// ParseBinds reads the `binds { ... }` blocks of KDL source: one bind per
// node ("Mod+T hotkey-overlay-title=\"..\" { spawn \"foot\"; }"), with the
// action on the same line or the next ones.
func ParseBinds(src, source string) []ipc.Bind {
	out := []ipc.Bind{}
	depth := 0
	var pending *ipc.Bind
	for _, raw := range strings.Split(src, "\n") {
		line := strings.TrimSpace(raw)
		if i := strings.Index(line, "//"); i >= 0 && !strings.Contains(line[:i], `"`) {
			line = strings.TrimSpace(line[:i])
		}
		if line == "" || strings.HasPrefix(line, "/-") {
			continue
		}
		switch {
		case depth == 0:
			if strings.HasPrefix(line, "binds") && strings.HasSuffix(line, "{") {
				depth = 1
			}
			continue
		case pending != nil:
			// Multi-line node body: the first statement is the action.
			if line != "}" {
				setAction(pending, line)
			}
			out = append(out, *pending)
			pending = nil
			if !strings.HasSuffix(line, "}") {
				depth = 3 // wait for the node's closing brace
			} else {
				depth = 1
			}
			continue
		case depth == 3:
			if strings.HasPrefix(line, "}") {
				depth = 1
			}
			continue
		}
		if line == "}" {
			depth = 0
			continue
		}
		open := strings.Index(line, "{")
		if open < 0 {
			continue
		}
		head := strings.TrimSpace(line[:open])
		combo := strings.Fields(head)
		if len(combo) == 0 {
			continue
		}
		b := comboBind(combo[0])
		b.Source = source
		if m := kdlTitle.FindStringSubmatch(head); m != nil {
			b.Description = m[1]
		}
		b.Locked = kdlLocked.MatchString(head)
		body := strings.TrimSpace(line[open+1:])
		if body == "" {
			pending = &b
			continue
		}
		setAction(&b, strings.TrimSuffix(body, "}"))
		out = append(out, b)
	}
	return out
}

func comboBind(combo string) ipc.Bind {
	parts := strings.Split(combo, "+")
	b := ipc.Bind{Modifiers: []string{}, Key: parts[len(parts)-1]}
	for _, m := range parts[:len(parts)-1] {
		if n, ok := ipc.NormalizeMod(m); ok {
			b.Modifiers = append(b.Modifiers, n)
		}
	}
	b.Mouse = strings.HasPrefix(strings.ToLower(b.Key), "mouse") || strings.HasPrefix(strings.ToLower(b.Key), "wheel")
	return b
}

// setAction stores `spawn "foot" "-e"; ` as dispatcher "spawn", arg
// `"foot" "-e"`.
func setAction(b *ipc.Bind, stmt string) {
	stmt = strings.TrimSpace(strings.TrimSuffix(strings.TrimSpace(stmt), ";"))
	name, arg, _ := strings.Cut(stmt, " ")
	b.Dispatcher = name
	b.Arg = strings.TrimSpace(arg)
}
