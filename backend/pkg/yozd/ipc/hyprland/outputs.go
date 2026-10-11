package hyprland

import (
	"encoding/json"
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

var hyprModeRe = regexp.MustCompile(`^(\d+)x(\d+)@([0-9.]+)Hz$`)

// parseHyprMode parses "2560x1440@239.97Hz".
func parseHyprMode(s string) (ipc.Mode, bool) {
	m := hyprModeRe.FindStringSubmatch(s)
	if m == nil {
		return ipc.Mode{}, false
	}
	w, err1 := strconv.Atoi(m[1])
	h, err2 := strconv.Atoi(m[2])
	r, err3 := strconv.ParseFloat(m[3], 64)
	if err1 != nil || err2 != nil || err3 != nil {
		return ipc.Mode{}, false
	}
	return ipc.Mode{Width: w, Height: h, Refresh: r}, true
}

type hyprMonitorJSON struct {
	Name           string          `json:"name"`
	Description    string          `json:"description"`
	Make           string          `json:"make"`
	Model          string          `json:"model"`
	Serial         string          `json:"serial"`
	Width          int             `json:"width"`
	Height         int             `json:"height"`
	PhysicalWidth  int             `json:"physicalWidth"`
	PhysicalHeight int             `json:"physicalHeight"`
	RefreshRate    float64         `json:"refreshRate"`
	X              int             `json:"x"`
	Y              int             `json:"y"`
	Scale          float64         `json:"scale"`
	Transform      int             `json:"transform"`
	VRR            bool            `json:"vrr"`
	MirrorOf       json.RawMessage `json:"mirrorOf"`
	Disabled       bool            `json:"disabled"`
	AvailableModes []string        `json:"availableModes"`
}

func parseHyprOutputs(data []byte) ([]ipc.Output, error) {
	var raw []hyprMonitorJSON
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parse monitors: %w", err)
	}
	outs := make([]ipc.Output, 0, len(raw))
	for _, m := range raw {
		o := ipc.Output{
			ID:               ipc.OutputID(m.Make, m.Model, m.Serial, m.Name),
			Name:             m.Name,
			Make:             m.Make,
			Model:            m.Model,
			Serial:           m.Serial,
			Description:      m.Description,
			Enabled:          !m.Disabled,
			Width:            m.Width,
			Height:           m.Height,
			Refresh:          m.RefreshRate,
			X:                m.X,
			Y:                m.Y,
			Scale:            m.Scale,
			Transform:        m.Transform,
			VRR:              m.VRR,
			MirrorOf:         mirrorName(m.MirrorOf),
			Modes:            dedupeModes(m.AvailableModes),
			PhysicalWidthMM:  m.PhysicalWidth,
			PhysicalHeightMM: m.PhysicalHeight,
		}
		outs = append(outs, o)
	}
	return outs, nil
}

// mirrorName reads hyprctl's mirrorOf, which is "none", null, -1 or the
// mirrored monitor (a name or an id depending on the version).
func mirrorName(raw json.RawMessage) string {
	t := strings.Trim(strings.TrimSpace(string(raw)), `"`)
	switch t {
	case "", "null", "none", "None", "-1", "false":
		return ""
	}
	return t
}

func dedupeModes(in []string) []ipc.Mode {
	seen := map[ipc.Mode]bool{}
	modes := []ipc.Mode{}
	for _, s := range in {
		m, ok := parseHyprMode(s)
		if !ok || seen[m] {
			continue
		}
		seen[m] = true
		modes = append(modes, m)
	}
	sort.SliceStable(modes, func(i, j int) bool {
		ai, aj := modes[i].Width*modes[i].Height, modes[j].Width*modes[j].Height
		if ai != aj {
			return ai > aj
		}
		return modes[i].Refresh > modes[j].Refresh
	})
	return modes
}

func fmtNum(f float64) string { return strconv.FormatFloat(f, 'f', -1, 64) }

// scaleStr is the scale as a bare number, or "auto" when unset.
func scaleStr(s float64) string {
	if s <= 0 {
		return "auto"
	}
	return fmtNum(s)
}

// hyprMonitorConf is the value of a hyprlang `monitor = ...` line (and of
// `keyword monitor ...`). cfg must have passed Validate.
func hyprMonitorConf(cfg ipc.OutputConfig) string {
	if !cfg.Enabled {
		return cfg.Name + ",disable"
	}
	return fmt.Sprintf("%s,%s,%s,%s,transform,%d,vrr,%d",
		cfg.Name, cfg.ModeString(), cfg.PositionString(), scaleStr(cfg.Scale), cfg.Transform, cfg.VRR)
}

// hyprMonitorLua is the `hl.monitor({ ... })` call for cfg. cfg must have
// passed Validate: Name is the only free-form field and is %q-quoted.
func hyprMonitorLua(cfg ipc.OutputConfig) string {
	if !cfg.Enabled {
		return fmt.Sprintf("hl.monitor({ output = %q, disabled = true })", cfg.Name)
	}
	scale := scaleStr(cfg.Scale)
	if cfg.Scale <= 0 {
		scale = `"auto"`
	}
	return fmt.Sprintf("hl.monitor({ output = %q, mode = %q, position = %q, scale = %s, transform = %d, vrr = %d })",
		cfg.Name, cfg.ModeString(), cfg.PositionString(), scale, cfg.Transform, cfg.VRR)
}

// buildHyprMonitorCmd builds the raw hyprctl request for cfg.
func buildHyprMonitorCmd(cfg ipc.OutputConfig, lua bool) string {
	if lua {
		return "eval " + hyprMonitorLua(cfg)
	}
	return "keyword monitor " + hyprMonitorConf(cfg)
}

// ListOutputs returns every monitor, including disabled ones.
func (h *Hyprland) ListOutputs() ([]ipc.Output, error) {
	resp, err := h.dispatch("j/monitors all")
	if err != nil {
		return nil, err
	}
	return parseHyprOutputs([]byte(resp))
}

// ApplyOutput applies one output's configuration at runtime.
func (h *Hyprland) ApplyOutput(cfg ipc.OutputConfig) error {
	if err := cfg.Validate(); err != nil {
		return err
	}
	cmd := buildHyprMonitorCmd(cfg, h.supportsLuaDispatchers())
	resp, err := h.dispatch(cmd)
	if err != nil {
		return err
	}
	return checkKeywordReply(cmd, resp)
}

// checkKeywordReply: Hyprland answers `keyword` with "ok" and with the
// config error text otherwise (e.g. an invalid monitor line), which the
// generic dispatch cannot tell from a success. The `eval` (Lua) reply is
// not documented, so it is only checked by dispatch's error prefixes.
func checkKeywordReply(cmd, resp string) error {
	if !strings.HasPrefix(cmd, "keyword ") {
		return nil
	}
	if r := strings.TrimSpace(resp); r != "" && r != "ok" {
		return fmt.Errorf("hyprland rejected monitor config: %s", r)
	}
	return nil
}
