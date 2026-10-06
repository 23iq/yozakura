package exclusive

import (
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/yozd/ipc"
)

// fakeSystemd records enable/disable calls over a set of known units.
type fakeSystemd struct {
	enabled   map[string]bool
	active    map[string]bool
	listed    []string
	disabled  []string
	started   []string
	failOn    string
	onDisable func(unit string)
}

func (f *fakeSystemd) IsEnabled(u string) bool { return f.enabled[u] }
func (f *fakeSystemd) IsActive(u string) bool  { return f.active[u] }
func (f *fakeSystemd) Disable(u string) error {
	if f.onDisable != nil {
		f.onDisable(u)
	}
	if u == f.failOn {
		return fs.ErrPermission
	}
	f.enabled[u], f.active[u] = false, false
	f.disabled = append(f.disabled, u)
	return nil
}
func (f *fakeSystemd) Enable(u string, start bool) error {
	f.enabled[u] = true
	if start {
		f.active[u] = true
		f.started = append(f.started, u)
	}
	return nil
}
func (f *fakeSystemd) ListUserUnits(pattern string) []string {
	var out []string
	for _, u := range f.listed {
		if ok, _ := filepath.Match(pattern, u); ok {
			out = append(out, u)
		}
	}
	return out
}

type recorder struct {
	imports   int
	monitors  []ipc.OutputConfig
	kb        *ipc.KeyboardSettings
	reloads   int
	unimports []map[string]any
}

func testOptions(t *testing.T, home string, sd *fakeSystemd, rec *recorder) Options {
	t.Helper()
	clock := time.Date(2026, 10, 6, 12, 0, 0, 0, time.Local)
	return Options{
		Home: home, AppID: "yozakura", Compositor: "hyprland",
		Now:     func() time.Time { clock = clock.Add(time.Second); return clock },
		Systemd: sd,
		Import: func(m []ipc.OutputConfig, kb *ipc.KeyboardSettings) (map[string]any, error) {
			rec.imports++
			rec.monitors, rec.kb = m, kb
			return map[string]any{"keyboard.layouts": "us"}, nil
		},
		Unimport: func(prev map[string]any) error { rec.unimports = append(rec.unimports, prev); return nil },
		Reload:   func() error { rec.reloads++; return nil },
	}
}

func write(t *testing.T, path, text string, mode os.FileMode) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(text), mode); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(path, mode); err != nil {
		t.Fatal(err)
	}
}

// snapshot describes a tree: type, permissions and content or link target.
func snapshot(t *testing.T, root string) map[string]string {
	t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(root, p)
		info, err := os.Lstat(p)
		if err != nil {
			return err
		}
		switch {
		case info.Mode()&os.ModeSymlink != 0:
			target, _ := os.Readlink(p)
			out[rel] = "link:" + target
		case info.IsDir():
			out[rel] = "dir:" + info.Mode().Perm().String()
		default:
			data, _ := os.ReadFile(p)
			out[rel] = "file:" + info.Mode().Perm().String() + ":" + string(data)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func sameTree(t *testing.T, want, got map[string]string) {
	t.Helper()
	var diffs []string
	for k, v := range want {
		if got[k] != v {
			diffs = append(diffs, k+": want "+v+" got "+got[k])
		}
	}
	for k := range got {
		if _, ok := want[k]; !ok {
			diffs = append(diffs, k+": unexpected")
		}
	}
	sort.Strings(diffs)
	if len(diffs) > 0 {
		t.Fatalf("trees differ:\n%s", strings.Join(diffs, "\n"))
	}
}

func backups(t *testing.T, home string) []string {
	t.Helper()
	entries, _ := os.ReadDir(filepath.Join(home, ".local/share/yozakura/backups"))
	var out []string
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".") {
			continue
		}
		out = append(out, e.Name())
	}
	return out
}
