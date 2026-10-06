package ipc

import (
	"fmt"
	"regexp"
	"strconv"
)

// Mode is one resolution/refresh combination an output supports.
type Mode struct {
	Width   int     `json:"width"`
	Height  int     `json:"height"`
	Refresh float64 `json:"refresh"`
}

// Output is one monitor as the compositor reports it.
type Output struct {
	ID               string  `json:"id"`
	Name             string  `json:"name"`
	Make             string  `json:"make"`
	Model            string  `json:"model"`
	Serial           string  `json:"serial"`
	Description      string  `json:"description"`
	Enabled          bool    `json:"enabled"`
	Width            int     `json:"width"`
	Height           int     `json:"height"`
	Refresh          float64 `json:"refresh"`
	X                int     `json:"x"`
	Y                int     `json:"y"`
	Scale            float64 `json:"scale"`
	Transform        int     `json:"transform"` // 0..7 (wl_output transform)
	VRR              bool    `json:"vrr"`
	Modes            []Mode  `json:"modes"`
	PhysicalWidthMM  int     `json:"physical_width_mm"`
	PhysicalHeightMM int     `json:"physical_height_mm"`
}

// OutputConfig is the desired state of one output.
type OutputConfig struct {
	Name         string  `json:"name"` // connector, required
	Enabled      bool    `json:"enabled"`
	Width        int     `json:"width"`
	Height       int     `json:"height"`
	Refresh      float64 `json:"refresh"` // 0 = preferred
	X            int     `json:"x"`
	Y            int     `json:"y"`
	AutoPosition bool    `json:"auto_position"`
	Scale        float64 `json:"scale"` // 0 = auto
	Transform    int     `json:"transform"`
	VRR          int     `json:"vrr"` // 0 off, 1 on, 2 fullscreen-only
}

// OutputManager is implemented by compositors that can list and configure
// outputs. Others answer with ErrNotSupported.
type OutputManager interface {
	ListOutputs() ([]Output, error)
	ApplyOutput(cfg OutputConfig) error
}

var connectorRe = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)

// OutputID is the stable identity of a monitor: "make|model|serial" when
// the EDID provides them, else the connector name.
func OutputID(make, model, serial, name string) string {
	if make == "" && model == "" && serial == "" {
		return name
	}
	return make + "|" + model + "|" + serial
}

// Validate rejects values that must never reach a compositor command.
func (c OutputConfig) Validate() error {
	if !connectorRe.MatchString(c.Name) {
		return fmt.Errorf("invalid output name %q", c.Name)
	}
	if c.Width < 0 || c.Height < 0 || c.Refresh < 0 {
		return fmt.Errorf("negative mode for %s", c.Name)
	}
	if c.Transform < 0 || c.Transform > 7 {
		return fmt.Errorf("transform %d out of range 0..7", c.Transform)
	}
	if c.VRR < 0 || c.VRR > 2 {
		return fmt.Errorf("vrr %d out of range 0..2", c.VRR)
	}
	if c.Scale != 0 && (c.Scale < 0.25 || c.Scale > 4) {
		return fmt.Errorf("scale %v out of range 0.25..4", c.Scale)
	}
	return nil
}

// ModeString is "WxH@R", or "preferred" when no size is requested.
func (c OutputConfig) ModeString() string {
	if c.Width <= 0 || c.Height <= 0 {
		return "preferred"
	}
	s := fmt.Sprintf("%dx%d", c.Width, c.Height)
	if c.Refresh > 0 {
		s += "@" + strconv.FormatFloat(c.Refresh, 'f', -1, 64)
	}
	return s
}

// PositionString is "XxY", or "auto".
func (c OutputConfig) PositionString() string {
	if c.AutoPosition {
		return "auto"
	}
	return fmt.Sprintf("%dx%d", c.X, c.Y)
}
