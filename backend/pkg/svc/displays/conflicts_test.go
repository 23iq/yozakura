package displays

import (
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/yozd/ipc"
)

func write(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

// fixture builds a ~/.config/hypr tree like a real user's: a Lua entry with
// our marked block and a required monitors.lua, a legacy conf, and a symlink
// into our data dir that must be ignored.
func fixture(t *testing.T) (hypr, data, home string) {
	root := t.TempDir()
	home = root
	hypr = filepath.Join(root, "config", "hypr")
	data = filepath.Join(root, "share", brand.AppID)
	write(t, filepath.Join(hypr, "hyprland.lua"), strings.Join([]string{
		`require("monitors")`,
		brand.ConfigBlockMarker("--"),
		`hl.monitor({ output = "BLOCK-1", mode = "preferred" })`,
		``,
		`-- OVERRIDES`,
		brand.ConfigOverridesNote("--", "source"),
		`-- hl.monitor({ output = "DP-9" })`,
		`hl.monitor({ output = "HDMI-A-1", disabled = true }) -- tv`,
	}, "\n")+"\n")
	write(t, filepath.Join(hypr, "monitors.lua"),
		`hl.monitor({ output = "DP-1", mode = "2560x1440@240", position = "0x0", scale = 1 })`+"\n"+
			`hl.monitor({ output = "DP-2",`+"\n")
	write(t, filepath.Join(hypr, "conf", "hyprland.conf"), strings.Join([]string{
		`# monitor = DP-7,preferred,auto,1`,
		`monitor = DP-3,1920x1080@144.00Hz,2560x0,1.25,transform,1,vrr,2,bitdepth,10`,
		`monitor=,preferred,auto,auto`,
		`monitor = desc:LG Electronics 27GP,preferred,auto,1`,
		`monitor = DP-4,1920x1080@144.00Hz,2560x0,1.25,transform,1,vrr,2`,
		`monitorv2 {`,
		`source = ~/.local/share/` + brand.AppID + `/hyprland.conf`,
	}, "\n")+"\n")
	write(t, filepath.Join(data, "hyprland.conf"), "monitor = DP-1,disable\n")
	if err := os.Symlink(filepath.Join(data, "hyprland.conf"), filepath.Join(hypr, "generated.conf")); err != nil {
		t.Fatal(err)
	}
	return hypr, data, home
}

func TestScanConflicts(t *testing.T) {
	hypr, data, _ := fixture(t)
	got, err := ScanConflicts(hypr, data)
	if err != nil {
		t.Fatal(err)
	}
	var keys []string
	for _, c := range got {
		rel, _ := filepath.Rel(hypr, c.File)
		keys = append(keys, rel+":"+strconv.Itoa(c.Line))
	}
	// the catch-all fallback (empty name) and desc: rules are not conflicts:
	// they never override a connector-named generated rule
	want := []string{"conf/hyprland.conf:2", "conf/hyprland.conf:5", "hyprland.lua:8", "monitors.lua:1", "monitors.lua:2"}
	if !reflect.DeepEqual(keys, want) {
		t.Fatalf("conflicts = %v, want %v", keys, want)
	}
	if got[3].Text != `hl.monitor({ output = "DP-1", mode = "2560x1440@240", position = "0x0", scale = 1 })` {
		t.Fatalf("text = %q", got[3].Text)
	}
}

func TestMoveConflictsIdempotent(t *testing.T) {
	hypr, data, home := fixture(t)
	res, err := MoveConflicts(hypr, data, home)
	if err != nil {
		t.Fatal(err)
	}
	wantOut := []ipc.OutputConfig{
		{Name: "DP-4", Enabled: true, Width: 1920, Height: 1080, Refresh: 144, X: 2560, Y: 0, Scale: 1.25, Transform: 1, VRR: 2},
		{Name: "HDMI-A-1", Enabled: false},
		{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1},
	}
	if !reflect.DeepEqual(res.Outputs, wantOut) {
		t.Fatalf("outputs = %+v\nwant %+v", res.Outputs, wantOut)
	}
	if len(res.Moved) != 3 || len(res.Skipped) != 2 || res.Skipped[0].Reason != "unsupported: bitdepth" {
		t.Fatalf("moved %d skipped %d: %+v", len(res.Moved), len(res.Skipped), res.Skipped)
	}
	conf, _ := os.ReadFile(filepath.Join(hypr, "conf", "hyprland.conf"))
	if !strings.Contains(string(conf), "# "+brand.AppID+": moved monitor = DP-4,") ||
		!strings.Contains(string(conf), "\nmonitor = DP-3,") ||
		!strings.Contains(string(conf), "\nmonitor=,preferred,auto,auto\n") ||
		!strings.Contains(string(conf), "\nmonitor = desc:LG Electronics 27GP,") {
		t.Fatalf("conf after move:\n%s", conf)
	}
	lua, _ := os.ReadFile(filepath.Join(hypr, "monitors.lua"))
	if !strings.HasPrefix(string(lua), "-- "+brand.AppID+": moved hl.monitor({ output = \"DP-1\"") {
		t.Fatalf("lua after move:\n%s", lua)
	}
	gen, _ := os.ReadFile(filepath.Join(data, "hyprland.conf"))
	if string(gen) != "monitor = DP-1,disable\n" {
		t.Fatalf("data dir file touched: %q", gen)
	}

	again, err := MoveConflicts(hypr, data, home)
	if err != nil || len(again.Moved) != 0 || len(again.Outputs) != 0 || len(again.Skipped) != 2 {
		t.Fatalf("second move = %+v, %v", again, err)
	}
	conf2, _ := os.ReadFile(filepath.Join(hypr, "conf", "hyprland.conf"))
	if string(conf2) != string(conf) {
		t.Fatal("second move changed the file")
	}
}

func TestParseMonitorLine(t *testing.T) {
	cases := []struct {
		line string
		lua  bool
		want ipc.OutputConfig
		bad  bool
	}{
		{line: "monitor = DP-1,2560x1440@240,0x0,1", want: ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1}},
		{line: "monitor = eDP-1,preferred,auto,auto # laptop", want: ipc.OutputConfig{Name: "eDP-1", Enabled: true, AutoPosition: true}},
		{line: "monitor = HDMI-A-1,disable", want: ipc.OutputConfig{Name: "HDMI-A-1"}},
		{line: "monitor = DP-2,1920x1080,-1920x0,2,transform,3", want: ipc.OutputConfig{Name: "DP-2", Enabled: true, Width: 1920, Height: 1080, X: -1920, Scale: 2, Transform: 3}},
		{line: "monitor = DP-2,preferred,auto,1,mirror,DP-1", bad: true},
		{line: "monitor = DP-2,preferred,auto,1,cm,hdr", bad: true},
		{line: "monitor = DP-2,preferred,auto,1,transform", bad: true},
		{line: `hl.monitor({ output = "DP-1", mode = "preferred", bitdepth = 10 })`, lua: true, bad: true},
		{line: `hl.monitor({ output = "DP-1" }) foo()`, lua: true, bad: true},
		{line: `hl.monitor({ output = "DP-1", scale = 2 }); -- main`, lua: true, want: ipc.OutputConfig{Name: "DP-1", Enabled: true, AutoPosition: true, Scale: 2}},
		{line: "monitor = desc:Dell Inc. U2720Q,preferred,auto,1", bad: true},
		{line: "monitor = DP-1,highres,auto,1", bad: true},
		{line: `hl.monitor({ output = "DP-1", mode = "2560x1440@239.97", position = "auto-right", scale = "auto", vrr = 1 })`, lua: true,
			want: ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 239.97, AutoPosition: true, VRR: 1}},
		{line: `hl.monitor({ output = 'eDP-1', disabled = true })`, lua: true, want: ipc.OutputConfig{Name: "eDP-1"}},
		{line: `hl.monitor({ mode = "preferred" })`, lua: true, bad: true},
	}
	for _, c := range cases {
		got, err := ParseMonitorLine(c.line, c.lua)
		if c.bad {
			if err == nil {
				t.Errorf("%q: want error, got %+v", c.line, got)
			}
			continue
		}
		if err != nil || got != c.want {
			t.Errorf("%q: got %+v, %v\nwant %+v", c.line, got, err, c.want)
		}
	}
}

func TestScanMissingHyprDir(t *testing.T) {
	got, err := ScanConflicts(filepath.Join(t.TempDir(), "nope"), t.TempDir())
	if err != nil || got == nil || len(got) != 0 {
		t.Fatalf("got %v, %v", got, err)
	}
}

func TestParseReasons(t *testing.T) {
	_, err := ParseMonitorLine("monitor = DP-3,1920x1080,0x0,1,vrr,1,sdrbrightness,1.2", false)
	if err == nil || err.Error() != "unsupported: sdrbrightness" {
		t.Fatalf("err = %v", err)
	}
}

// A block whose OVERRIDES trailer was deleted ends at its first blank line.
func TestBlockWithoutTrailer(t *testing.T) {
	lines := []string{brand.ConfigBlockMarker("#"), "source = x", "", "monitor = DP-1,preferred,auto,1"}
	if got := conflictLines(lines, false); !reflect.DeepEqual(got, []int{3}) {
		t.Fatalf("conflicts = %v", got)
	}
}

// Read-only link targets, files outside home and /nix/store are never
// rewritten; the walk still moves the other files' rules.
func TestMoveSkipsUnwritableTargets(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root ignores file modes")
	}
	root := t.TempDir()
	home := filepath.Join(root, "home")
	hypr := filepath.Join(home, ".config", "hypr")
	ro := filepath.Join(home, "dotfiles", "ro.conf")
	write(t, ro, "monitor = DP-1,preferred,auto,1\n")
	if err := os.Chmod(ro, 0o444); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(root, "elsewhere", "out.conf")
	write(t, outside, "monitor = DP-2,preferred,auto,1\n")
	write(t, filepath.Join(hypr, "b.conf"), "monitor = DP-3,preferred,auto,1\n")
	for name, target := range map[string]string{"a.conf": ro, "c.conf": outside} {
		if err := os.Symlink(target, filepath.Join(hypr, name)); err != nil {
			t.Fatal(err)
		}
	}
	res, err := MoveConflicts(hypr, filepath.Join(home, ".local", "share", brand.AppID), home)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Outputs) != 1 || res.Outputs[0].Name != "DP-3" || len(res.Moved) != 1 {
		t.Fatalf("moved = %+v", res)
	}
	if len(res.Skipped) != 2 || !strings.HasPrefix(res.Skipped[0].Reason, "not writable") ||
		!strings.HasPrefix(res.Skipped[1].Reason, "outside home") {
		t.Fatalf("skipped = %+v", res.Skipped)
	}
	for _, p := range []string{ro, outside} {
		if b, _ := os.ReadFile(p); strings.Contains(string(b), "moved") {
			t.Fatalf("%s rewritten", p)
		}
	}
}

func TestUnwritableNixStore(t *testing.T) {
	if got := unwritable("/nix/store/abc-hypr/hyprland.conf", ""); !strings.Contains(got, "/nix/store") {
		t.Fatalf("got %q", got)
	}
}

func TestConflictsEmptyWhileExclusive(t *testing.T) {
	hypr, data, _ := fixture(t)
	s := newService(nil, hypr, data)
	got, err := s.conflicts(nil)
	if err != nil || len(got.([]Conflict)) == 0 {
		t.Fatalf("fixture must conflict first: %v %v", got, err)
	}
	active := true
	s.SetExclusiveCheck(func() bool { return active })
	got, err = s.conflicts(nil)
	list, ok := got.([]Conflict)
	if err != nil || !ok || list == nil || len(list) != 0 {
		t.Fatalf("exclusive: want empty non-nil list, got %#v %v", got, err)
	}
	active = false
	if got, _ = s.conflicts(nil); len(got.([]Conflict)) == 0 {
		t.Fatal("conflicts must come back when exclusive mode ends")
	}
}
