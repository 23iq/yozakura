package exclusive

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/exclusive"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/yozd/ipc"
)

type fakeSD struct{ enabled map[string]bool }

func (f *fakeSD) IsEnabled(u string) bool       { return f.enabled[u] }
func (f *fakeSD) IsActive(string) bool          { return false }
func (f *fakeSD) Disable(u string) error        { f.enabled[u] = false; return nil }
func (f *fakeSD) Enable(u string, _ bool) error { f.enabled[u] = true; return nil }
func (f *fakeSD) ListUserUnits(string) []string { return nil }

func testService(t *testing.T) (*Service, string, *fakeSD) {
	home := t.TempDir()
	hypr := filepath.Join(home, ".config/hypr")
	if err := os.MkdirAll(hypr, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(hypr, "hyprland.conf"), []byte("monitor = DP-1,preferred,auto,1\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	sd := &fakeSD{enabled: map[string]bool{"waybar.service": true}}
	reloads := 0
	s := &Service{opts: func() exclusive.Options {
		return exclusive.Options{
			Home: home, AppID: "yozakura", Compositor: "hyprland", Systemd: sd,
			Now:    func() time.Time { return time.Date(2026, 10, 6, 1, 2, 3, 0, time.Local) },
			Reload: func() error { reloads++; return nil },
		}
	}}
	return s, hypr, sd
}

func call(t *testing.T, f func(json.RawMessage) (any, error), params string) map[string]any {
	t.Helper()
	res, err := f(json.RawMessage(params))
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(res)
	var out map[string]any
	_ = json.Unmarshal(raw, &out)
	return out
}

func TestEnableRestoreOverIPCMethods(t *testing.T) {
	s, hypr, sd := testService(t)
	if st := call(t, s.status, ""); st["active"] != false {
		t.Fatalf("status %v", st)
	}
	plan := call(t, s.plan, "")
	if !reflect.DeepEqual(plan["units"], []any{"waybar.service"}) || plan["entry"] != "hyprland.conf" {
		t.Fatalf("plan %v", plan)
	}
	st := call(t, s.enable, "")
	if st["active"] != true || sd.enabled["waybar.service"] {
		t.Fatalf("enable %v", st)
	}
	again := call(t, s.enable, "")
	if again["backup"] != st["backup"] {
		t.Fatalf("second enable made another backup: %v vs %v", again["backup"], st["backup"])
	}
	rs := call(t, s.restore, `{}`)
	if rs["active"] != false || !sd.enabled["waybar.service"] || rs["replaced"] == "" {
		t.Fatalf("restore %v", rs)
	}
	data, _ := os.ReadFile(filepath.Join(hypr, "hyprland.conf"))
	if string(data) != "monitor = DP-1,preferred,auto,1\n" {
		t.Fatalf("entry not restored: %q", data)
	}
	if _, err := s.restore(nil); err == nil {
		t.Fatal("restore while not active must fail")
	}
}

func TestUnsupportedCompositor(t *testing.T) {
	s, _, _ := testService(t)
	base := s.opts
	s.opts = func() exclusive.Options { o := base(); o.Compositor = "niri"; return o }
	if _, err := s.enable(nil); err == nil {
		t.Fatal("niri must be refused")
	}
	if st := call(t, s.status, ""); st["reason"] == "" || st["reason"] == nil {
		t.Fatalf("status must say why: %v", st)
	}
}

func TestImportAndUnimportThroughConfig(t *testing.T) {
	if _, err := catalog.Load(paths.FindShellSource()); err != nil {
		t.Skip("no shell source:", err)
	}
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	kb := &ipc.KeyboardSettings{Layouts: []string{"us", "ru"}, Variants: []string{"", "phonetic"}, Options: []string{"grp:alt_shift_toggle"}, RepeatRate: 40}
	mon := []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 144, Scale: 1}}
	previous, err := importSettings(mon, kb)
	if err != nil {
		t.Fatal(err)
	}
	store, err := Store()
	if err != nil {
		t.Fatal(err)
	}
	got, _, _ := store.Get("keyboard.layouts")
	raw, _ := json.Marshal(got)
	if string(raw) != `[{"layout":"us","variant":""},{"layout":"ru","variant":"phonetic"}]` {
		t.Fatalf("layouts %s", raw)
	}
	if v, _, _ := store.Get("keyboard.repeatRate"); v != float64(40) && v != 40 {
		t.Fatalf("rate %v", v)
	}
	if m, _, _ := store.Get("displays.monitors"); len(m.([]any)) != 1 {
		t.Fatalf("monitors %v", m)
	}
	if v, _, _ := store.Get("keyboard.managed"); v != true {
		t.Fatalf("an imported keyboard must be managed (rendered), got %v", v)
	}
	if err := unimportSettings(previous); err != nil {
		t.Fatal(err)
	}
	if m, _, _ := store.Get("displays.monitors"); len(m.([]any)) != 0 {
		t.Fatalf("monitors not reverted: %v", m)
	}
	if v, _, _ := store.Get("keyboard.repeatRate"); v != float64(25) && v != 25 {
		t.Fatalf("rate not reverted: %v", v)
	}
	if v, _, _ := store.Get("keyboard.managed"); v != false {
		t.Fatalf("managed not reverted: %v", v)
	}
}

type fakeYozd struct {
	name        string
	nameErr     error
	errs        []string
	reloadErr   error
	reloadCalls int
}

func (f *fakeYozd) Compositor() (string, error)     { return f.name, f.nameErr }
func (f *fakeYozd) ReloadConfig() error             { f.reloadCalls++; return f.reloadErr }
func (f *fakeYozd) ConfigErrors() ([]string, error) { return f.errs, nil }

func TestReloadThroughYozd(t *testing.T) {
	ok := &fakeYozd{name: "hyprland"}
	if err := reloadWith(ok); err != nil || ok.reloadCalls != 1 {
		t.Fatalf("clean reload: %v %d", err, ok.reloadCalls)
	}
	bad := &fakeYozd{name: "hyprland", errs: []string{"line 3: bad", "line 9: worse"}}
	if err := reloadWith(bad); err == nil || !strings.Contains(err.Error(), "line 3: bad; line 9: worse") {
		t.Fatalf("config errors must fail: %v", err)
	}
}

func TestHostUsesXDGHyprDir(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", "/xdg/cfg")
	if got := Host().HyprDir; got != "/xdg/cfg/hypr" {
		t.Fatalf("host hypr dir %q", got)
	}
}
