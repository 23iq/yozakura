package config

import (
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// MonitorConfig is one [[monitors]] entry, mirroring ipc.OutputConfig.
type MonitorConfig struct {
	Name         string  `toml:"name"`
	Enabled      bool    `toml:"enabled"`
	Width        int     `toml:"width,omitempty"`
	Height       int     `toml:"height,omitempty"`
	Refresh      float64 `toml:"refresh,omitempty"`
	X            int     `toml:"x,omitempty"`
	Y            int     `toml:"y,omitempty"`
	AutoPosition bool    `toml:"auto_position,omitempty"`
	Scale        float64 `toml:"scale,omitempty"`
	Transform    int     `toml:"transform,omitempty"`
	VRR          int     `toml:"vrr,omitempty"`
}

func (m MonitorConfig) toIPC() ipc.OutputConfig {
	return ipc.OutputConfig{
		Name: m.Name, Enabled: m.Enabled,
		Width: m.Width, Height: m.Height, Refresh: m.Refresh,
		X: m.X, Y: m.Y, AutoPosition: m.AutoPosition,
		Scale: m.Scale, Transform: m.Transform, VRR: m.VRR,
	}
}

// splitCSV splits a comma-separated TOML string. Empty input gives nil;
// empty elements are kept so variants stay aligned with layouts.
func splitCSV(s string) []string {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return strings.Split(s, ",")
}

func (k *KeyboardConfig) toIPC() *ipc.KeyboardSettings {
	return &ipc.KeyboardSettings{
		Layouts:     splitCSV(k.Layouts),
		Variants:    splitCSV(k.Variants),
		Options:     splitCSV(k.Options),
		Model:       k.Model,
		RepeatRate:  k.RepeatRate,
		RepeatDelay: k.RepeatDelay,
	}
}
