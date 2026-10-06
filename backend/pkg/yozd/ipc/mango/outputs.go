package mango

import (
	"yozakura/backend/pkg/yozd/ipc"
)

// parseMangoOutputs converts `get all-monitors`. Mango exposes no mode list
// or refresh rate, so Modes holds only the current size.
func parseMangoOutputs(ms []mangoMonitor) []ipc.Output {
	out := make([]ipc.Output, 0, len(ms))
	for _, mm := range ms {
		scale := 1.0
		if mm.Scale > 0 {
			scale = float64(mm.Scale) / 100.0
		}
		o := ipc.Output{
			ID:      ipc.OutputID("", "", "", mm.Name),
			Name:    mm.Name,
			Enabled: mm.Active != 0,
			Width:   mm.Width,
			Height:  mm.Height,
			X:       mm.X,
			Y:       mm.Y,
			Scale:   scale,
			Modes:   []ipc.Mode{},
		}
		if mm.Width > 0 && mm.Height > 0 {
			o.Modes = append(o.Modes, ipc.Mode{Width: mm.Width, Height: mm.Height})
		}
		out = append(out, o)
	}
	return out
}

// ListOutputs returns the monitors mango reports.
func (m *Mango) ListOutputs() ([]ipc.Output, error) {
	conn, err := m.acquire()
	if err != nil {
		return nil, err
	}
	var ms []mangoMonitor
	if err := conn.Query("get all-monitors", &ms); err != nil {
		return nil, err
	}
	return parseMangoOutputs(ms), nil
}

// ApplyOutput: mango has no live per-output command; the backend persists
// the layout through config generation instead.
func (m *Mango) ApplyOutput(cfg ipc.OutputConfig) error {
	if err := cfg.Validate(); err != nil {
		return err
	}
	return ipc.ErrNotSupported
}
