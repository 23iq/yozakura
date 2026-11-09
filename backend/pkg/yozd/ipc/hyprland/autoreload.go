package hyprland

import (
	"encoding/json"
	"sync"
	"time"
)

// autoreloadQuiet is how long Hyprland's config autoreload stays off after
// the last live write. Hyprland handles the inotify event of the write in
// its next event loop pass, well inside this window.
var autoreloadQuiet = 1500 * time.Millisecond

// autoreloadGuard tracks a runtime `misc:disable_autoreload` override.
type autoreloadGuard struct {
	mu     sync.Mutex
	active bool // yozd turned autoreload off and has not restored it yet
	gen    int  // bumped per suppression; only the newest one restores
	timer  *time.Timer
}

// SuppressAutoreload turns Hyprland's config autoreload off at runtime
// while yozd rewrites the generated (sourced) file for a live update:
// with autoreload on (Hyprland's default), the write alone would trigger
// the full reload the live update avoids. The returned func turns it back
// on after autoreloadQuiet; overlapping calls extend the window. Nothing
// changes when the user turned autoreload off themselves or the option
// cannot be read or set.
func (h *Hyprland) SuppressAutoreload() (release func()) {
	g := &h.autoreload
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.active {
		enabled, ok := h.autoreloadEnabled()
		if !ok || !enabled {
			return func() {}
		}
	}
	// Set it on every call: a reload in between resets runtime options.
	if err := h.setAutoreloadDisabled(true); err != nil {
		return func() {}
	}
	g.active = true
	g.gen++
	gen := g.gen
	return func() {
		g.mu.Lock()
		defer g.mu.Unlock()
		if g.timer != nil {
			g.timer.Stop()
		}
		g.timer = time.AfterFunc(autoreloadQuiet, func() {
			g.mu.Lock()
			defer g.mu.Unlock()
			if g.gen != gen || !g.active {
				return
			}
			g.active = false
			_ = h.setAutoreloadDisabled(false)
		})
	}
}

// autoreloadEnabled reads `misc:disable_autoreload`; ok=false when the
// reply cannot be parsed.
func (h *Hyprland) autoreloadEnabled() (enabled, ok bool) {
	resp, err := h.dispatch("j/getoption misc:disable_autoreload")
	if err != nil {
		return false, false
	}
	var opt struct {
		Int *int `json:"int"`
	}
	if json.Unmarshal([]byte(resp), &opt) != nil || opt.Int == nil {
		return false, false
	}
	return *opt.Int == 0, true
}

func (h *Hyprland) setAutoreloadDisabled(disabled bool) error {
	var err error
	if h.UsesLuaConfig() {
		v := "false"
		if disabled {
			v = "true"
		}
		_, err = h.dispatch("eval hl.config({ misc = { disable_autoreload = " + v + " } })")
	} else {
		v := "0"
		if disabled {
			v = "1"
		}
		_, err = h.dispatch("keyword misc:disable_autoreload " + v)
	}
	return err
}
