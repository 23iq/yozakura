package niri

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

// niri's logical block is already rotated and scaled: a 2560x1440 mode at
// transform 90 and scale 1.5 is 960x1707 in layout coordinates.
func TestListMonitorsLogicalSize(t *testing.T) {
	f := newFakeNiri(t, func(req json.RawMessage) (any, error) {
		if !strings.Contains(string(req), "Outputs") {
			return nil, fmt.Errorf("no workspaces")
		}
		return map[string]interface{}{
			"Outputs": map[string]interface{}{
				"DP-1": map[string]interface{}{
					"name":         "DP-1",
					"current_mode": float64(0),
					"modes": []map[string]interface{}{
						{"width": float64(2560), "height": float64(1440), "refresh_rate": float64(144000)},
					},
					"logical": map[string]interface{}{
						"x": float64(0), "y": float64(0),
						"width": float64(960), "height": float64(1707),
						"scale": 1.5, "transform": "90",
					},
				},
				"HDMI-A-1": map[string]interface{}{
					"name":         "HDMI-A-1",
					"current_mode": nil,
					"modes":        []map[string]interface{}{},
					"logical":      nil,
				},
			},
		}, nil
	})
	monitors, err := f.Client().ListMonitors()
	if err != nil {
		t.Fatalf("ListMonitors() error = %v", err)
	}
	for _, m := range monitors {
		switch m.Name {
		case "DP-1":
			if m.Metadata["logical_width"] != 960 || m.Metadata["logical_height"] != 1707 {
				t.Fatalf("logical = %v x %v, want 960 x 1707", m.Metadata["logical_width"], m.Metadata["logical_height"])
			}
		case "HDMI-A-1":
			if _, ok := m.Metadata["logical_width"]; ok {
				t.Fatalf("disabled output got a logical size: %v", m.Metadata)
			}
		}
	}
}
