package niri

import (
	"encoding/json"
	"fmt"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

func TestCoversOutput(t *testing.T) {
	out := [2]int{2560, 1440}
	cases := []struct {
		size [2]int
		want bool
	}{
		{[2]int{2560, 1440}, true},
		{[2]int{2559, 1441}, true},  // fractional-scale rounding
		{[2]int{2500, 1428}, false}, // maximize-window-to-edges stops at the panels
		{[2]int{1233, 1406}, false},
	}
	for _, c := range cases {
		if got := coversOutput(c.size, out); got != c.want {
			t.Errorf("coversOutput(%v) = %v, want %v", c.size, got, c.want)
		}
	}
	if coversOutput([2]int{0, 0}, [2]int{0, 0}) {
		t.Error("an unknown output size never matches")
	}
}

func TestLayoutsChangedOnlyOnFullscreenFlip(t *testing.T) {
	n := &Niri{}
	n.fs.setOutputs(map[string][2]int{"DP-1": {2560, 1440}})
	n.fs.resetWindows([]windowEntry{{id: 7, output: "DP-1", size: &[2]int{2500, 1428}}})

	layout := func(id int, w, h int) json.RawMessage {
		return json.RawMessage(fmt.Sprintf(`{"changes":[[%d,{"window_size":[%d,%d],"tile_size":[%d.0,%d.0]}]]}`, id, w, h, w, h))
	}
	ev := func(data json.RawMessage) ipc.EventType {
		e := ipc.Event{Payload: map[string]interface{}{}}
		n.handleEvent("WindowLayoutsChanged", data, &e)
		return e.Type
	}

	if got := ev(layout(7, 1233, 1406)); got != "" {
		t.Fatalf("a plain resize emitted %q", got)
	}
	if got := ev(layout(7, 2560, 1440)); got != ipc.EventFullscreenChanged {
		t.Fatalf("entering fullscreen emitted %q, want %q", got, ipc.EventFullscreenChanged)
	}
	if got := ev(layout(7, 2560, 1440)); got != "" {
		t.Fatalf("a repeated fullscreen layout emitted %q", got)
	}
	if got := ev(layout(7, 2500, 1428)); got != ipc.EventFullscreenChanged {
		t.Fatalf("leaving fullscreen emitted %q, want %q", got, ipc.EventFullscreenChanged)
	}
	// A window opened since the last list: matched against any output
	if got := ev(layout(9, 2560, 1440)); got != ipc.EventFullscreenChanged {
		t.Fatalf("a new fullscreen window emitted %q", got)
	}
}

func TestListWindowsDerivesFullscreen(t *testing.T) {
	f := newFakeNiri(t, func(req json.RawMessage) (any, error) {
		var s string
		_ = json.Unmarshal(req, &s)
		switch s {
		case "Workspaces":
			return map[string]any{"Workspaces": []map[string]any{
				{"id": 2, "idx": 1, "output": "DP-1", "is_active": true, "is_focused": true},
				{"id": 3, "idx": 1, "output": "HDMI-A-1", "is_active": true},
			}}, nil
		case "Outputs":
			return map[string]any{"Outputs": map[string]any{
				"DP-1":     map[string]any{"name": "DP-1", "logical": map[string]any{"width": 2560, "height": 1440, "scale": 1.0}},
				"HDMI-A-1": map[string]any{"name": "HDMI-A-1", "logical": map[string]any{"width": 1920, "height": 1080, "scale": 1.0}},
			}}, nil
		case "Windows":
			win := func(id, ws, w, h int) map[string]any {
				return map[string]any{"id": id, "workspace_id": ws, "layout": map[string]any{"window_size": []int{w, h}}}
			}
			return map[string]any{"Windows": []map[string]any{
				win(1, 2, 2560, 1440), // fullscreen on DP-1
				win(2, 2, 2500, 1428), // maximized to edges on DP-1
				win(3, 3, 2560, 1440), // bigger than HDMI-A-1: not its size
				win(4, 3, 1920, 1080), // fullscreen on HDMI-A-1
			}}, nil
		}
		return nil, fmt.Errorf("unexpected request: %s", string(req))
	})

	windows, err := f.Client().ListWindows()
	if err != nil {
		t.Fatalf("ListWindows() error = %v", err)
	}
	want := map[string]bool{"1": true, "2": false, "3": false, "4": true}
	for _, w := range windows {
		if w.IsFullscreen != want[w.ID] {
			t.Errorf("window %s fullscreen = %v, want %v", w.ID, w.IsFullscreen, want[w.ID])
		}
	}
}
