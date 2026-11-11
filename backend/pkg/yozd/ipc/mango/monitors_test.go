package mango

import "testing"

// mango's get all-monitors reports the wlr_output_layout box, which is
// already the logical (rotated, scaled) size.
func TestListMonitorsLogicalSize(t *testing.T) {
	s := newFakeServer(t, func(t *testing.T, parts []string) (string, bool, bool, string) {
		if len(parts) >= 2 && parts[0] == "get" && parts[1] == "all-monitors" {
			return mustJSON(t, []map[string]any{
				{"name": "DP-1", "active": float64(1), "focused": float64(1), "x": float64(0), "y": float64(0), "width": float64(960), "height": float64(1707), "scale": float64(150), "index": float64(0)},
			}), false, true, ""
		}
		return "", true, false, "unexpected"
	})
	monitors, err := s.Client(t).ListMonitors()
	if err != nil {
		t.Fatalf("ListMonitors error = %v", err)
	}
	md := monitors[0].Metadata
	if md["logical_width"] != 960 || md["logical_height"] != 1707 {
		t.Fatalf("logical = %v x %v, want 960 x 1707", md["logical_width"], md["logical_height"])
	}
}
