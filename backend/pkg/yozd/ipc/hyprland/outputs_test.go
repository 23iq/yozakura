package hyprland

import (
	"os"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func mustRead(t *testing.T, p string) []byte {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestParseHyprMode(t *testing.T) {
	m, ok := parseHyprMode("2560x1440@239.97Hz")
	if !ok || m.Width != 2560 || m.Height != 1440 || m.Refresh != 239.97 {
		t.Fatal(m)
	}
	if _, ok := parseHyprMode("garbage"); ok {
		t.Fatal("accepted garbage")
	}
}

func TestListOutputsParsesAll(t *testing.T) {
	outs, err := parseHyprOutputs(mustRead(t, "testdata/monitors_all.json"))
	if err != nil || len(outs) != 2 {
		t.Fatal(outs, err)
	}
	dp := outs[0]
	if dp.ID != "Lenovo Group Limited|Legion 27Q-10|UNA08414" || dp.Refresh != 240 || !dp.Enabled || dp.PhysicalWidthMM != 600 {
		t.Fatalf("%+v", dp)
	}
	if len(dp.Modes) != 8 || dp.Modes[0] != (ipc.Mode{Width: 2560, Height: 1440, Refresh: 240}) {
		t.Fatalf("modes %+v", dp.Modes)
	}
	hd := outs[1]
	if hd.Enabled || hd.ID != "HDMI-A-1" || len(hd.Modes) != 2 {
		t.Fatalf("%+v", hd)
	}
}

func TestApplyOutputLuaCommand(t *testing.T) {
	cfg := ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1}
	want := `eval hl.monitor({ output = "DP-1", mode = "2560x1440@240", position = "0x0", scale = 1, transform = 0, vrr = 0 })`
	if got := buildHyprMonitorCmd(cfg, true); got != want {
		t.Fatal(got)
	}
	cfg.Scale, cfg.AutoPosition, cfg.Width = 0, true, 0
	want = `eval hl.monitor({ output = "DP-1", mode = "preferred", position = "auto", scale = "auto", transform = 0, vrr = 0 })`
	if got := buildHyprMonitorCmd(cfg, true); got != want {
		t.Fatal(got)
	}
}

func TestApplyOutputLegacyCommand(t *testing.T) {
	cfg := ipc.OutputConfig{Name: "DP-1", Enabled: true, Width: 2560, Height: 1440, Refresh: 240, Scale: 1}
	want := `keyword monitor DP-1,2560x1440@240,0x0,1,transform,0,vrr,0`
	if got := buildHyprMonitorCmd(cfg, false); got != want {
		t.Fatal(got)
	}
}

func TestApplyOutputDisable(t *testing.T) {
	cfg := ipc.OutputConfig{Name: "HDMI-A-1"}
	if got := buildHyprMonitorCmd(cfg, true); got != `eval hl.monitor({ output = "HDMI-A-1", disabled = true })` {
		t.Fatal(got)
	}
	if got := buildHyprMonitorCmd(cfg, false); got != `keyword monitor HDMI-A-1,disable` {
		t.Fatal(got)
	}
}

func TestOutputConfigValidateRejectsInjection(t *testing.T) {
	if err := (ipc.OutputConfig{Name: `DP-1"; os.exit()`}).Validate(); err == nil {
		t.Fatal("accepted injection")
	}
	bad := []ipc.OutputConfig{{Name: "A", Transform: 8}, {Name: "A", VRR: 3}, {Name: "A", Scale: 5}, {Name: "A", Width: -1}}
	for _, c := range bad {
		if c.Validate() == nil {
			t.Fatalf("accepted %+v", c)
		}
	}
	if err := (ipc.OutputConfig{Name: "DP-1", Scale: 1.25}).Validate(); err != nil {
		t.Fatal(err)
	}
}
