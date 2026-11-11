package axmon

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"time"
	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
)

type Monitor struct {
	ID        string                 `json:"id"`
	Name      string                 `json:"name"`
	Width     int                    `json:"width"`
	Height    int                    `json:"height"`
	Scale     float64                `json:"scale"`
	IsFocused bool                   `json:"is_focused"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
}

func (m Monitor) X() int {
	if v, ok := m.Metadata["x"].(float64); ok {
		return int(v)
	}
	return 0
}

func (m Monitor) Y() int {
	if v, ok := m.Metadata["y"].(float64); ok {
		return int(v)
	}
	return 0
}

func (m Monitor) Transform() int {
	if v, ok := m.Metadata["transform"].(float64); ok {
		return int(v)
	}
	return 0
}

// LogicalSize is the monitor's size in layout (logical) coordinates.
// Width/Height mean different things per compositor (raw mode pixels on
// Hyprland, logical on niri), so the daemon sends logical_width/height;
// without them (an older daemon) Width/Height are used as is.
func (m Monitor) LogicalSize() (int, int) {
	w, wok := m.Metadata["logical_width"].(float64)
	h, hok := m.Metadata["logical_height"].(float64)
	if wok && hok && w > 0 && h > 0 {
		return int(w), int(h)
	}
	return m.Width, m.Height
}

// ScreencopyLogical reports whether the compositor sends this monitor's
// screencopy frames already in logical orientation (Hyprland >= 0.57).
func (m Monitor) ScreencopyLogical() bool {
	v, _ := m.Metadata["screencopy_logical"].(bool)
	return v
}

func (m Monitor) EffectiveScale() float64 {
	if m.Scale > 0 {
		return m.Scale
	}
	return 1.0
}

// List returns the current monitor layout via the compositor daemon.
func List() ([]Monitor, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, paths.DaemonBinary(), "monitor", "list")
	// Bound inherited pipes as well if the daemon spawned a child.
	cmd.WaitDelay = 250 * time.Millisecond
	out, err := cmd.Output()
	if err != nil {
		if ctx.Err() != nil {
			err = ctx.Err()
		}
		return nil, fmt.Errorf("%s monitor list: %w", brand.Daemon, err)
	}
	var monitors []Monitor
	if err := json.Unmarshal(out, &monitors); err != nil {
		return nil, fmt.Errorf("parse monitors: %w", err)
	}
	return monitors, nil
}

// FindByName returns the monitor with the given output name.
func FindByName(monitors []Monitor, name string) (*Monitor, bool) {
	for i := range monitors {
		if monitors[i].Name == name {
			return &monitors[i], true
		}
	}
	return nil, false
}

// Focused returns the focused monitor, or the first one.
func Focused(monitors []Monitor) (*Monitor, bool) {
	for i := range monitors {
		if monitors[i].IsFocused {
			return &monitors[i], true
		}
	}
	if len(monitors) > 0 {
		return &monitors[0], true
	}
	return nil, false
}

// Containing resolves which monitor holds a logical global point.
func Containing(monitors []Monitor, x, y int) (*Monitor, bool) {
	for i := range monitors {
		m := &monitors[i]
		mx, my := m.X(), m.Y()
		w, h := m.LogicalSize()
		if x >= mx && x < mx+w && y >= my && y < my+h {
			return m, true
		}
	}
	return nil, false
}
