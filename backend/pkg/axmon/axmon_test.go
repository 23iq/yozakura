package axmon

import "testing"

// testMonitors is a `monitor list` reply as yozd sends it on Hyprland:
// width/height are the raw mode pixels, the layout size is in metadata.
// DP-1 is a 2560x1440 panel turned portrait (transform 1) at scale 1.5,
// HDMI-A-1 a 1920x1080 panel at scale 2 placed right of it.
func testMonitors() []Monitor {
	return []Monitor{
		{Name: "DP-1", Width: 2560, Height: 1440, Scale: 1.5, IsFocused: true,
			Metadata: map[string]interface{}{"x": float64(0), "y": float64(0), "transform": float64(1),
				"logical_width": float64(960), "logical_height": float64(1707)}},
		{Name: "HDMI-A-1", Width: 1920, Height: 1080, Scale: 2,
			Metadata: map[string]interface{}{"x": float64(960), "y": float64(100), "transform": float64(0),
				"logical_width": float64(960), "logical_height": float64(540)}},
	}
}

func TestGeometryAccessors(t *testing.T) {
	ms := testMonitors()
	m := ms[1]
	if m.X() != 960 || m.Y() != 100 {
		t.Fatalf("position: got %d,%d", m.X(), m.Y())
	}
	if m.Transform() != 0 || ms[0].Transform() != 1 {
		t.Fatalf("transform: got %d, %d", ms[0].Transform(), m.Transform())
	}
	if m.EffectiveScale() != 2 {
		t.Fatalf("scale: got %v", m.EffectiveScale())
	}
}

func TestEffectiveScaleFallback(t *testing.T) {
	m := Monitor{Name: "eDP-1", Scale: 0}
	if m.EffectiveScale() != 1.0 {
		t.Fatalf("expected 1.0 fallback, got %v", m.EffectiveScale())
	}
}

func TestFindByName(t *testing.T) {
	ms := testMonitors()
	m, ok := FindByName(ms, "HDMI-A-1")
	if !ok || m.Scale != 2 {
		t.Fatalf("find failed: %v %v", ok, m)
	}
	if _, ok := FindByName(ms, "missing"); ok {
		t.Fatal("expected miss")
	}
}

func TestFocused(t *testing.T) {
	ms := testMonitors()
	m, ok := Focused(ms)
	if !ok || m.Name != "DP-1" {
		t.Fatalf("focused: %v %v", ok, m)
	}
	none := []Monitor{{Name: "A"}, {Name: "B"}}
	if m, _ := Focused(none); m.Name != "A" {
		t.Fatalf("fallback expected first, got %s", m.Name)
	}
}

func TestContaining(t *testing.T) {
	ms := testMonitors()
	cases := []struct {
		x, y int
		want string
	}{
		{480, 850, "DP-1"},
		// bottom of the portrait monitor: past the raw 1440 mode height
		{100, 1600, "DP-1"},
		{959, 1706, "DP-1"},
		// inside the raw 2560 mode width of DP-1, but logically HDMI-A-1
		{1000, 200, "HDMI-A-1"},
		{1919, 639, "HDMI-A-1"},
		{1920, 200, ""},
		{1000, 50, ""},
		{100, 1707, ""},
		{-50, -50, ""},
	}
	for _, c := range cases {
		m, ok := Containing(ms, c.x, c.y)
		got := ""
		if ok {
			got = m.Name
		}
		if got != c.want {
			t.Fatalf("Containing(%d,%d): got %q want %q", c.x, c.y, got, c.want)
		}
	}
}

// Without logical metadata (an older daemon) width/height are used as is.
func TestContainingWithoutLogicalSize(t *testing.T) {
	ms := []Monitor{{Name: "DP-1", Width: 1920, Height: 1080,
		Metadata: map[string]interface{}{"x": float64(0), "y": float64(0)}}}
	if m, ok := Containing(ms, 1919, 1079); !ok || m.Name != "DP-1" {
		t.Fatalf("fallback miss: %v %v", ok, m)
	}
	if _, ok := Containing(ms, 1920, 0); ok {
		t.Fatal("expected miss past the width")
	}
}
