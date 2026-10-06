package yozakura

import (
	"encoding/json"
	"fmt"
	"math"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"yozakura/backend/pkg/catalog"
	yipc "yozakura/backend/pkg/yozd/ipc"
)

// Shared by the `display` CLI and the displays_* MCP tools: build an output
// config from the current state plus a change, start a confirm-or-revert
// session in the daemon (displays service) and persist a kept layout into
// displays.monitors like the Settings page does.

// OutputChange is a partial change to one output; nil/empty fields keep the
// current value.
type OutputChange struct {
	Name      string
	Mode      string // "WxH", "WxH@Hz" or "preferred"
	Scale     *float64
	Transform *int
	VRR       *int
	Enabled   *bool
	X, Y      *int
}

var modeRe = regexp.MustCompile(`^(\d+)x(\d+)(?:@(\d+(?:\.\d+)?)(?:hz|Hz)?)?$`)

// ListOutputs calls displays.list.
func ListOutputs(c Caller) ([]yipc.Output, error) {
	if c == nil {
		return nil, errNoDaemon
	}
	raw, err := c.Call("displays.list", nil)
	if err != nil {
		return nil, err
	}
	var outs []yipc.Output
	if err := json.Unmarshal(raw, &outs); err != nil {
		return nil, fmt.Errorf("displays.list: %v", err)
	}
	return outs, nil
}

// OutputConfigOf is the config that reproduces an output as it is now.
func OutputConfigOf(o yipc.Output) yipc.OutputConfig {
	c := yipc.OutputConfig{
		Name: o.Name, Enabled: o.Enabled, Width: o.Width, Height: o.Height,
		Refresh: o.Refresh, X: o.X, Y: o.Y, Scale: o.Scale, Transform: o.Transform,
	}
	if o.VRR {
		c.VRR = 1
	}
	return c
}

// FindOutput matches a connector name (case-insensitive) or a stable id.
func FindOutput(outs []yipc.Output, name string) (yipc.Output, error) {
	for _, o := range outs {
		if strings.EqualFold(o.Name, name) || (o.ID != "" && o.ID == name) {
			return o, nil
		}
	}
	names := make([]string, 0, len(outs))
	for _, o := range outs {
		names = append(names, o.Name)
	}
	return yipc.Output{}, fmt.Errorf("no display %q (connected: %s)", name, strings.Join(names, ", "))
}

// BuildOutputConfig applies ch to the current state of o. A requested mode
// must be one the output lists (when it lists any); a missing refresh picks
// the highest one for that size.
func BuildOutputConfig(o yipc.Output, ch OutputChange) (yipc.OutputConfig, error) {
	c := OutputConfigOf(o)
	if ch.Enabled != nil {
		c.Enabled = *ch.Enabled
	}
	if ch.Mode != "" {
		if err := applyMode(&c, o, ch.Mode); err != nil {
			return c, err
		}
	}
	if ch.Scale != nil {
		c.Scale = *ch.Scale
	}
	if ch.Transform != nil {
		c.Transform = *ch.Transform
	}
	if ch.VRR != nil {
		c.VRR = *ch.VRR
	}
	if ch.X != nil {
		c.X = *ch.X
	}
	if ch.Y != nil {
		c.Y = *ch.Y
	}
	return c, c.Validate()
}

func applyMode(c *yipc.OutputConfig, o yipc.Output, spec string) error {
	if strings.EqualFold(spec, "preferred") {
		c.Width, c.Height, c.Refresh = 0, 0, 0
		return nil
	}
	m := modeRe.FindStringSubmatch(spec)
	if m == nil {
		return fmt.Errorf("mode %q: use WIDTHxHEIGHT[@HZ] (e.g. 2560x1440@165) or preferred", spec)
	}
	w, _ := strconv.Atoi(m[1])
	h, _ := strconv.Atoi(m[2])
	var hz float64
	if m[3] != "" {
		hz, _ = strconv.ParseFloat(m[3], 64)
	}
	if len(o.Modes) == 0 {
		c.Width, c.Height, c.Refresh = w, h, hz
		return nil
	}
	best, found := yipc.Mode{}, false
	for _, md := range o.Modes {
		if md.Width != w || md.Height != h {
			continue
		}
		if hz > 0 && math.Abs(md.Refresh-hz) > 0.6 {
			continue
		}
		// no refresh asked: highest; one asked: the closest
		if !found || (hz == 0 && md.Refresh > best.Refresh) || (hz > 0 && math.Abs(md.Refresh-hz) < math.Abs(best.Refresh-hz)) {
			best, found = md, true
		}
	}
	if !found {
		return fmt.Errorf("%s does not support %s; available: %s", o.Name, spec, strings.Join(ModeList(o), ", "))
	}
	c.Width, c.Height, c.Refresh = best.Width, best.Height, best.Refresh
	return nil
}

// ModeList is the output's modes as "WxH@Hz", the largest first.
func ModeList(o yipc.Output) []string {
	modes := append([]yipc.Mode(nil), o.Modes...)
	sort.SliceStable(modes, func(i, j int) bool {
		a, b := modes[i], modes[j]
		if a.Width*a.Height != b.Width*b.Height {
			return a.Width*a.Height > b.Width*b.Height
		}
		return a.Refresh > b.Refresh
	})
	out := make([]string, 0, len(modes))
	for _, m := range modes {
		out = append(out, fmt.Sprintf("%dx%d@%s", m.Width, m.Height, strconv.FormatFloat(math.Round(m.Refresh*100)/100, 'f', -1, 64)))
	}
	return out
}

// DisplaySession is the answer of displays.apply.
type DisplaySession struct {
	Session  string `json:"session"`
	RevertIn int    `json:"revertIn"`
	Live     bool   `json:"live"`
}

// StartDisplayApply applies the configs live; the daemon reverts them after
// RevertIn seconds unless KeepDisplays confirms.
func StartDisplayApply(c Caller, cfgs []yipc.OutputConfig) (DisplaySession, error) {
	var s DisplaySession
	if c == nil {
		return s, errNoDaemon
	}
	raw, err := c.Call("displays.apply", map[string]any{"outputs": cfgs})
	if err != nil {
		return s, err
	}
	if err := json.Unmarshal(raw, &s); err != nil || s.Session == "" {
		return s, fmt.Errorf("displays.apply: unexpected answer")
	}
	return s, nil
}

// KeepDisplays confirms a session and saves the layout (store may be nil to
// skip saving).
func KeepDisplays(c Caller, store *catalog.Store, session string, cfgs []yipc.OutputConfig, outs []yipc.Output) error {
	if c == nil {
		return errNoDaemon
	}
	if _, err := c.Call("displays.keep", map[string]any{"session": session}); err != nil {
		return err
	}
	if store == nil {
		return nil
	}
	if err := PersistMonitors(store, cfgs, outs); err != nil {
		return fmt.Errorf("kept, but saving the layout failed: %v", err)
	}
	return nil
}

// RevertDisplays cancels a session.
func RevertDisplays(c Caller, session string) error {
	if c == nil {
		return errNoDaemon
	}
	_, err := c.Call("displays.revert", map[string]any{"session": session})
	return err
}

// PersistMonitors merges cfgs into displays.monitors (by stable id, else
// connector name), keeping entries of monitors that are not connected.
func PersistMonitors(store *catalog.Store, cfgs []yipc.OutputConfig, outs []yipc.Output) error {
	cur, _, err := store.Get("displays.monitors")
	if err != nil {
		return err
	}
	saved, _ := cur.([]any)
	ids := map[string]string{}
	for _, o := range outs {
		if o.ID != "" && o.ID != o.Name {
			ids[o.Name] = o.ID
		}
	}
	for _, c := range cfgs {
		entry := map[string]any{
			"id": ids[c.Name], "name": c.Name, "enabled": c.Enabled,
			"width": c.Width, "height": c.Height, "refresh": c.Refresh,
			"x": c.X, "y": c.Y, "autoPosition": c.AutoPosition,
			"scale": c.Scale, "transform": c.Transform, "vrr": c.VRR,
		}
		replaced := false
		for i, s := range saved {
			m, _ := s.(map[string]any)
			sid, _ := m["id"].(string)
			sname, _ := m["name"].(string)
			if (sid != "" && sid == ids[c.Name]) || (sid == "" || ids[c.Name] == "") && sname == c.Name {
				saved[i], replaced = entry, true
				break
			}
		}
		if !replaced {
			saved = append(saved, entry)
		}
	}
	_, err = store.Set("displays.monitors", saved, false)
	return err
}
