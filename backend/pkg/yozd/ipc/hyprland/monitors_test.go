package hyprland

import (
	"os"
	"testing"
)

func listMonitorsWithVersion(t *testing.T, version string) map[string]map[string]interface{} {
	t.Helper()
	monitorsJSON, err := os.ReadFile("testdata/monitors_rotated.json")
	if err != nil {
		t.Fatal(err)
	}
	runFakeHyprlandSocketWith(t, []string{version}, map[string]string{"j/monitors": string(monitorsJSON)})
	h := &Hyprland{signature: "test"}
	ms, err := h.ListMonitors()
	if err != nil {
		t.Fatalf("ListMonitors() error = %v", err)
	}
	byName := map[string]map[string]interface{}{}
	for _, m := range ms {
		byName[m.Name] = m.Metadata
		// Width/Height keep hyprctl's raw mode pixels: the shell rotates and
		// scales them itself (Overview, WallpaperCoverage).
		if m.Name == "DP-1" && (m.Width != 2560 || m.Height != 1440) {
			t.Fatalf("DP-1 raw size changed to %dx%d", m.Width, m.Height)
		}
	}
	return byName
}

// logical_width/height follow Hyprland's own m_size: the mode rotated by an
// odd transform, divided by the scale and rounded.
func TestListMonitorsLogicalSize(t *testing.T) {
	ms := listMonitorsWithVersion(t, `{"version":"0.55.0"}`)
	cases := []struct {
		name string
		w, h int
	}{
		{"DP-1", 960, 1707},    // 1440/1.5, 2560/1.5 = 1706.67
		{"HDMI-A-1", 960, 540}, // unrotated, scale 2
		{"DP-2", 960, 1536},    // flipped-270: 1200/1.25, 1920/1.25
	}
	for _, c := range cases {
		md := ms[c.name]
		if md["logical_width"] != c.w || md["logical_height"] != c.h {
			t.Fatalf("%s logical = %v x %v, want %d x %d", c.name, md["logical_width"], md["logical_height"], c.w, c.h)
		}
	}
}

// Hyprland >= 0.57 (901881c9f) renders screencopy frames in logical
// orientation; the screenshot engine needs to know to not rotate them again.
func TestListMonitorsScreencopyLogical(t *testing.T) {
	for version, want := range map[string]bool{
		`{"version":"0.56.1"}`: false,
		`{"version":"0.57.0"}`: true,
		`{"version":"1.0.0"}`:  true,
	} {
		ms := listMonitorsWithVersion(t, version)
		if got := ms["DP-1"]["screencopy_logical"]; got != want {
			t.Fatalf("%s: screencopy_logical = %v, want %v", version, got, want)
		}
	}
}
