package mango

import (
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// MangoWC has no IPC request listing binds: ListBinds reads the bind lines
// of <config>/mango/config.conf (best effort, following `source=` lines).
func (m *Mango) ListBinds() ([]ipc.Bind, error) {
	return ReadBinds(filepath.Join(ipc.ConfigHome(), "mango", "config.conf")), nil
}

// ReadBinds parses the binds of a mango config file and its sources.
func ReadBinds(path string) []ipc.Bind {
	out := []ipc.Bind{}
	readBinds(path, map[string]bool{}, &out)
	return out
}

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
		k, v, ok := strings.Cut(strings.TrimSpace(line), "=")
		if ok && strings.TrimSpace(k) == "source" {
			readBinds(ipc.ExpandPath(v, filepath.Dir(path)), seen, out)
		}
	}
}

// ParseBinds reads "bind[flags]=MODS,KEY,command,arg" lines (MODS like
// "SUPER+SHIFT" or "NONE"); mousebind/axisbind lines are mouse binds.
func ParseBinds(src, source string) []ipc.Bind {
	out := []ipc.Bind{}
	for _, raw := range strings.Split(src, "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		kind := strings.TrimSpace(k)
		mouse := strings.HasPrefix(kind, "mousebind") || strings.HasPrefix(kind, "axisbind")
		if !mouse && !strings.HasPrefix(kind, "bind") {
			continue
		}
		parts := strings.SplitN(v, ",", 4)
		if len(parts) < 3 {
			continue
		}
		b := ipc.Bind{Modifiers: []string{}, Key: strings.TrimSpace(parts[1]), Dispatcher: strings.TrimSpace(parts[2]), Mouse: mouse, Source: source}
		if len(parts) == 4 {
			b.Arg = strings.TrimSpace(parts[3])
		}
		flags := strings.TrimPrefix(kind, "bind")
		b.Locked = strings.Contains(flags, "l")
		b.Release = strings.Contains(flags, "r")
		for _, mod := range strings.Split(parts[0], "+") {
			if n, ok := ipc.NormalizeMod(mod); ok {
				b.Modifiers = append(b.Modifiers, n)
			}
		}
		out = append(out, b)
	}
	return out
}
