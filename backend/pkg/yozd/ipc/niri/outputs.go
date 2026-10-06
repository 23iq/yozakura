package niri

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// niriTransforms maps the wl_output transform (0..7) to niri's wire names.
var niriTransforms = [8]string{"Normal", "90", "180", "270", "Flipped", "Flipped90", "Flipped180", "Flipped270"}

func niriTransformName(i int) (string, error) {
	if i < 0 || i >= len(niriTransforms) {
		return "", fmt.Errorf("transform %d out of range 0..7", i)
	}
	return niriTransforms[i], nil
}

// niriTransformIndex parses a transform as niri reports it. Both the bare
// ("90") and underscore ("_90") spellings are accepted.
func niriTransformIndex(s string) int {
	s = strings.TrimPrefix(s, "_")
	for i, name := range niriTransforms {
		if s == name {
			return i
		}
	}
	return 0
}

// parseNiriOutputs converts the `Outputs` reply payload (name -> output).
func parseNiriOutputs(data []byte) ([]ipc.Output, error) {
	var raw map[string]niriOutput
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parse outputs: %w", err)
	}
	outs := make([]ipc.Output, 0, len(raw))
	for name, o := range raw {
		serial := ""
		if o.Serial != nil {
			serial = *o.Serial
		}
		out := ipc.Output{
			ID:          ipc.OutputID(o.Make, o.Model, serial, name),
			Name:        name,
			Make:        o.Make,
			Model:       o.Model,
			Serial:      serial,
			Description: fmt.Sprintf("%s %s", o.Make, o.Model),
			Enabled:     o.Logical != nil,
			VRR:         o.VRREnabled,
			Scale:       1,
			Modes:       make([]ipc.Mode, 0, len(o.Modes)),
		}
		if o.PhysicalSize != nil {
			out.PhysicalWidthMM, out.PhysicalHeightMM = int(o.PhysicalSize[0]), int(o.PhysicalSize[1])
		}
		for _, m := range o.Modes {
			out.Modes = append(out.Modes, ipc.Mode{Width: int(m.Width), Height: int(m.Height), Refresh: float64(m.RefreshRate) / 1000})
		}
		if o.CurrentMode != nil && int(*o.CurrentMode) < len(o.Modes) {
			cur := o.Modes[*o.CurrentMode]
			out.Width, out.Height, out.Refresh = int(cur.Width), int(cur.Height), float64(cur.RefreshRate)/1000
		}
		if l := o.Logical; l != nil {
			out.X, out.Y, out.Scale = l.X, l.Y, l.Scale
			out.Transform = niriTransformIndex(l.Transform)
		}
		outs = append(outs, out)
	}
	sort.Slice(outs, func(i, j int) bool { return outs[i].Name < outs[j].Name })
	return outs, nil
}

// niriOutputActions builds the ordered `Output` action payloads for cfg.
// cfg must have passed Validate.
func niriOutputActions(cfg ipc.OutputConfig) ([]map[string]any, error) {
	wrap := func(action any) map[string]any {
		return map[string]any{"Output": map[string]any{"output": cfg.Name, "action": action}}
	}
	if !cfg.Enabled {
		return []map[string]any{wrap("Off")}, nil
	}
	var mode any = "Automatic"
	if cfg.Width > 0 && cfg.Height > 0 {
		spec := map[string]any{"width": cfg.Width, "height": cfg.Height}
		if cfg.Refresh > 0 {
			spec["refresh"] = cfg.Refresh
		}
		mode = map[string]any{"Specific": spec}
	}
	var scale any = "Automatic"
	if cfg.Scale > 0 {
		scale = map[string]any{"Specific": cfg.Scale}
	}
	var pos any = "Automatic"
	if !cfg.AutoPosition {
		pos = map[string]any{"Specific": map[string]any{"x": cfg.X, "y": cfg.Y}}
	}
	tr, err := niriTransformName(cfg.Transform)
	if err != nil {
		return nil, err
	}
	return []map[string]any{
		wrap("On"),
		wrap(map[string]any{"Mode": map[string]any{"mode": mode}}),
		wrap(map[string]any{"Scale": map[string]any{"scale": scale}}),
		wrap(map[string]any{"Transform": map[string]any{"transform": tr}}),
		wrap(map[string]any{"Position": map[string]any{"position": pos}}),
		wrap(map[string]any{"Vrr": map[string]any{"vrr": map[string]any{"vrr": cfg.VRR > 0, "on_demand": cfg.VRR == 2}}}),
	}, nil
}

// ListOutputs returns every output niri knows, with its mode list.
func (n *Niri) ListOutputs() ([]ipc.Output, error) {
	raw, err := n.requestRaw("Outputs")
	if err != nil {
		return nil, err
	}
	variant, err := unwrapVariant(raw, "Outputs")
	if err != nil {
		return nil, err
	}
	return parseNiriOutputs(variant)
}

// ApplyOutput applies one output's configuration at runtime.
func (n *Niri) ApplyOutput(cfg ipc.OutputConfig) error {
	if err := cfg.Validate(); err != nil {
		return err
	}
	reqs, err := niriOutputActions(cfg)
	if err != nil {
		return err
	}
	for _, req := range reqs {
		if err := n.request(req, nil); err != nil {
			return fmt.Errorf("output %s %s: %w", cfg.Name, niriActionName(req), err)
		}
	}
	return nil
}

// niriActionName names the action in an Output request, for error context.
func niriActionName(req map[string]any) string {
	out, _ := req["Output"].(map[string]any)
	switch a := out["action"].(type) {
	case string:
		return a
	case map[string]any:
		for k := range a {
			return k
		}
	}
	return "?"
}
