package server

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/hyprland"
	"yozakura/backend/pkg/yozd/ipc/mock"
	"yozakura/backend/pkg/yozd/ipc/niri"
)

// fakeHypr records reloads and batch requests.
type fakeHypr struct {
	*mock.Compositor
	lua     bool
	reloads int
	batches []string
}

func (f *fakeHypr) ReloadConfig() error       { f.reloads++; return nil }
func (f *fakeHypr) RawBatch(cmd string) error { f.batches = append(f.batches, cmd); return nil }
func (f *fakeHypr) UsesLuaConfig() bool       { return f.lua }

func hyprHandler(t *testing.T, lua bool) (*ConfigHandler, *fakeHypr, string) {
	t.Helper()
	dir := t.TempDir()
	f := &fakeHypr{Compositor: mock.NewCompositor(), lua: lua}
	conf := filepath.Join(dir, "hyprland.yozd.conf")
	return &ConfigHandler{
		compositor: f,
		generator:  &hyprland.Generator{},
		luaGen:     &hyprland.LuaGenerator{},
		paths:      configPaths{primary: conf, alt: filepath.Join(dir, "hyprland.yozd.lua")},
	}, f, conf
}

func hyprPayload(gapsIn int) ipc.ConfigUniversal {
	return ipc.ConfigUniversal{
		Monitors: []ipc.OutputConfig{{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 144, Scale: 1}},
		Appearance: ipc.ConfigAppearance{
			Gaps:   &ipc.Gaps{Inner: intPtr(gapsIn), Outer: intPtr(10)},
			Border: &ipc.Border{Width: intPtr(2), ActiveColor: strPtr("#ff0000")},
		},
		Keybinds: ipc.ConfigKeybinds{Custom: []ipc.Keybind{{
			Modifiers: []string{"SUPER"}, Key: "Q", Dispatcher: "exec", Argument: "kitty", Enabled: true,
		}}},
	}
}

func TestHyprlandSliderDragAppliesLiveWithoutReload(t *testing.T) {
	h, f, conf := hyprHandler(t, false)
	if err := h.ApplyConfig(hyprPayload(5)); err != nil {
		t.Fatal(err)
	}
	if f.reloads != 1 {
		t.Fatalf("first apply: reloads = %d, want 1", f.reloads)
	}
	// A slider drag: gaps 6..12, each step a regenerated config.
	for g := 6; g <= 12; g++ {
		if err := h.ApplyConfig(hyprPayload(g)); err != nil {
			t.Fatal(err)
		}
	}
	if f.reloads != 1 {
		t.Fatalf("appearance-only changes reloaded Hyprland %d extra times", f.reloads-1)
	}
	if len(f.batches) != 7 || f.batches[6] != "keyword general:gaps_in 12" {
		t.Fatalf("batches = %q", f.batches)
	}
	for _, b := range f.batches {
		if strings.Contains(b, "monitor") {
			t.Fatalf("monitor rules re-emitted live: %q", b)
		}
	}
	data, _ := os.ReadFile(conf)
	if !strings.Contains(string(data), "gaps_in = 12") {
		t.Fatalf("file not persisted: %s", data)
	}
}

func TestHyprlandLuaModeUsesEval(t *testing.T) {
	h, f, _ := hyprHandler(t, true)
	_ = h.ApplyConfig(hyprPayload(5))
	_ = h.ApplyConfig(hyprPayload(7))
	if f.reloads != 1 || len(f.batches) != 1 {
		t.Fatalf("reloads=%d batches=%q", f.reloads, f.batches)
	}
	if !strings.HasPrefix(f.batches[0], "eval hl.config({") || strings.Contains(f.batches[0], "\n") {
		t.Fatalf("lua live update = %q", f.batches[0])
	}
}

func TestHyprlandIdenticalRegenNeitherWritesNorReloads(t *testing.T) {
	h, f, conf := hyprHandler(t, false)
	_ = h.ApplyConfig(hyprPayload(5))
	before, _ := os.Stat(conf)
	_ = h.ApplyConfig(hyprPayload(5))
	after, _ := os.Stat(conf)
	if f.reloads != 1 || len(f.batches) != 0 {
		t.Fatalf("identical regen: reloads=%d batches=%q", f.reloads, f.batches)
	}
	if !after.ModTime().Equal(before.ModTime()) {
		t.Fatal("identical regen rewrote the file")
	}
}

func TestHyprlandBindOrMonitorChangeReloads(t *testing.T) {
	h, f, _ := hyprHandler(t, false)
	_ = h.ApplyConfig(hyprPayload(5))

	p := hyprPayload(5)
	p.Keybinds.Custom[0].Key = "W"
	_ = h.ApplyConfig(p)
	if f.reloads != 2 {
		t.Fatalf("bind change: reloads = %d, want 2", f.reloads)
	}

	p.Monitors[0].Refresh = 60
	_ = h.ApplyConfig(p)
	if f.reloads != 3 || len(f.batches) != 0 {
		t.Fatalf("monitor change: reloads=%d batches=%q", f.reloads, f.batches)
	}
}

func TestHyprlandExternalEditForcesReload(t *testing.T) {
	h, f, conf := hyprHandler(t, false)
	_ = h.ApplyConfig(hyprPayload(5))
	if err := os.WriteFile(conf, []byte("# edited by hand\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	_ = h.ApplyConfig(hyprPayload(6))
	if f.reloads != 2 {
		t.Fatalf("unknown on-disk state must reload, reloads = %d", f.reloads)
	}
}

func TestNiriIdenticalRegenSkipsReload(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	loader := &fakeLoader{Compositor: mock.NewCompositor()}
	h := NewConfigHandler(&niri.Niri{})
	h.compositor = loader
	payload := ipc.ConfigUniversal{Appearance: ipc.ConfigAppearance{Gaps: &ipc.Gaps{Inner: intPtr(4)}}}
	_ = h.ApplyConfig(payload)
	loader.reloaded = false
	_ = h.ApplyConfig(payload)
	if loader.reloaded {
		t.Fatal("byte-identical niri config must not reload")
	}
	payload.Appearance.Gaps.Inner = intPtr(8)
	_ = h.ApplyConfig(payload)
	if !loader.reloaded {
		t.Fatal("changed niri config must still reload")
	}
}
