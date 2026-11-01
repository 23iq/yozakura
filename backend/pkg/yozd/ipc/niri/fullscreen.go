package niri

import (
	"encoding/json"
	"sync"
)

// niri's IPC has no fullscreen flag on windows. A fullscreen window ignores
// layer-shell exclusive zones and covers its whole output, so its logical
// size equals the output's; a maximized one (maximize-column,
// maximize-window-to-edges) stops at the panels' reservations. fsTracker
// keeps the output sizes and the last fullscreen state per window so a
// WindowLayoutsChanged event only refreshes the cache when a window really
// entered or left fullscreen, not on every resize.
type fsTracker struct {
	mu       sync.Mutex
	outputs  map[string][2]int // output name -> logical size
	outputOf map[uint64]string // window id -> output name (last ListWindows)
	state    map[uint64]bool   // window id -> fullscreen
}

// coversOutput reports whether a window of `size` fills an output of
// `out`. One logical pixel of slack absorbs fractional-scale rounding.
func coversOutput(size [2]int, out [2]int) bool {
	dw, dh := size[0]-out[0], size[1]-out[1]
	return out[0] > 0 && out[1] > 0 && dw >= -1 && dw <= 1 && dh >= -1 && dh <= 1
}

// fullscreenLocked: whether the window covers its output, or any output
// when its output is unknown (a window the tracker has not listed yet).
func (t *fsTracker) fullscreenLocked(id uint64, size *[2]int) bool {
	if size == nil {
		return false
	}
	if name, ok := t.outputOf[id]; ok && name != "" {
		return coversOutput(*size, t.outputs[name])
	}
	for _, out := range t.outputs {
		if coversOutput(*size, out) {
			return true
		}
	}
	return false
}

// setOutputs replaces the known output sizes; nil keeps the previous ones
// (the Outputs request failed).
func (t *fsTracker) setOutputs(outputs map[string][2]int) {
	if outputs == nil {
		return
	}
	t.mu.Lock()
	t.outputs = outputs
	t.mu.Unlock()
}

// windowEntry is one window of a ListWindows reply, for resetWindows.
type windowEntry struct {
	id     uint64
	output string
	size   *[2]int
}

// resetWindows records a full window list and returns the fullscreen state
// of each window, by id. Closed windows drop out.
func (t *fsTracker) resetWindows(list []windowEntry) map[uint64]bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.outputOf = make(map[uint64]string, len(list))
	t.state = make(map[uint64]bool, len(list))
	for _, w := range list {
		t.outputOf[w.id] = w.output
	}
	for _, w := range list {
		t.state[w.id] = t.fullscreenLocked(w.id, w.size)
	}
	out := make(map[uint64]bool, len(t.state))
	for id, fs := range t.state {
		out[id] = fs
	}
	return out
}

// layoutsChanged applies a WindowLayoutsChanged payload and reports whether
// any window entered or left fullscreen.
func (t *fsTracker) layoutsChanged(data json.RawMessage) bool {
	var d struct {
		Changes [][2]json.RawMessage `json:"changes"`
	}
	if json.Unmarshal(data, &d) != nil {
		return false
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.state == nil {
		t.state = make(map[uint64]bool)
	}
	changed := false
	for _, c := range d.Changes {
		var id uint64
		var layout niriWindowLayout
		if json.Unmarshal(c[0], &id) != nil || json.Unmarshal(c[1], &layout) != nil {
			continue
		}
		fs := t.fullscreenLocked(id, layout.WindowSize)
		if fs != t.state[id] {
			t.state[id] = fs
			changed = true
		}
	}
	return changed
}

// refreshOutputSizes reads the outputs' logical sizes into the tracker.
// Errors keep the previous sizes: fullscreen detection degrades, nothing
// else depends on it.
func (n *Niri) refreshOutputSizes() {
	raw, err := n.requestRaw("Outputs")
	if err != nil {
		return
	}
	variant, err := unwrapVariant(raw, "Outputs")
	if err != nil {
		return
	}
	var outputs map[string]niriOutput
	if json.Unmarshal(variant, &outputs) != nil {
		return
	}
	sizes := make(map[string][2]int, len(outputs))
	for name, o := range outputs {
		if o.Logical != nil {
			sizes[name] = [2]int{int(o.Logical.Width), int(o.Logical.Height)}
		}
	}
	n.fs.setOutputs(sizes)
}
