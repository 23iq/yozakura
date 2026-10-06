package compositor

import (
	"fmt"
	"strconv"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// DisplayInput is one saved monitor (displays.monitors in the shell config),
// already keyed by its current connector Name.
type DisplayInput struct {
	ID           string  `json:"id,omitempty"`
	Name         string  `json:"name"`
	Enabled      bool    `json:"enabled"`
	Width        int     `json:"width"`
	Height       int     `json:"height"`
	Refresh      float64 `json:"refresh"`
	X            int     `json:"x"`
	Y            int     `json:"y"`
	AutoPosition bool    `json:"autoPosition"`
	Scale        float64 `json:"scale"`
	Transform    int     `json:"transform"`
	VRR          int     `json:"vrr"`
}

// OutputConfig converts the saved entry to yozd's wire form.
func (d DisplayInput) OutputConfig() ipc.OutputConfig {
	return ipc.OutputConfig{
		Name: d.Name, Enabled: d.Enabled,
		Width: d.Width, Height: d.Height, Refresh: d.Refresh,
		X: d.X, Y: d.Y, AutoPosition: d.AutoPosition,
		Scale: d.Scale, Transform: d.Transform, VRR: d.VRR,
	}
}

// KeyboardLayout is one entry of keyboard.layouts.
type KeyboardLayout struct {
	Layout  string `json:"layout"`
	Variant string `json:"variant"`
}

// KeyboardInput mirrors the shell's keyboard config domain.
type KeyboardInput struct {
	Layouts     []KeyboardLayout `json:"layouts"`
	SwitchBind  string           `json:"switchBind"`
	Options     []string         `json:"options"`
	Model       string           `json:"model,omitempty"`
	RepeatRate  int              `json:"repeatRate"`
	RepeatDelay int              `json:"repeatDelay"`
}

// switchBindOptions maps keyboard.switchBind to its XKB group toggle.
var switchBindOptions = map[string]string{
	"alt_shift":   "grp:alt_shift_toggle",
	"super_space": "grp:win_space_toggle",
	"caps":        "grp:caps_toggle",
	"ctrl_shift":  "grp:ctrl_shift_toggle",
}

// SwitchBindOption returns the XKB option for a layout-switch bind name, or
// "" for "none" and unknown names.
func SwitchBindOption(bind string) string { return switchBindOptions[bind] }

// Settings converts the domain to normalized XKB settings: the switch-bind
// option comes first, then the user options, without duplicates. Invalid
// tokens are dropped (ipc.KeyboardSettings.Normalize).
func (k KeyboardInput) Settings() ipc.KeyboardSettings {
	s := ipc.KeyboardSettings{Model: k.Model, RepeatRate: k.RepeatRate, RepeatDelay: k.RepeatDelay}
	for _, l := range k.Layouts {
		s.Layouts = append(s.Layouts, l.Layout)
		s.Variants = append(s.Variants, l.Variant)
	}
	seen := map[string]bool{}
	for _, o := range append([]string{SwitchBindOption(k.SwitchBind)}, k.Options...) {
		if o = strings.TrimSpace(o); o != "" && !seen[o] {
			seen[o] = true
			s.Options = append(s.Options, o)
		}
	}
	return s.Normalize()
}

// writeMonitors renders one [[monitors]] table per saved display with a
// valid connector name (field names match yozd's config.MonitorConfig).
func writeMonitors(b *strings.Builder, displays []DisplayInput) {
	for _, d := range displays {
		m := d.OutputConfig()
		if m.Validate() != nil {
			continue
		}
		b.WriteString("\n[[monitors]]\n")
		fmt.Fprintf(b, "name = %s\n", tomlString(m.Name))
		fmt.Fprintf(b, "enabled = %t\n", m.Enabled)
		fmt.Fprintf(b, "width = %d\n", m.Width)
		fmt.Fprintf(b, "height = %d\n", m.Height)
		fmt.Fprintf(b, "refresh = %s\n", tomlFloat(m.Refresh))
		fmt.Fprintf(b, "x = %d\n", m.X)
		fmt.Fprintf(b, "y = %d\n", m.Y)
		fmt.Fprintf(b, "auto_position = %t\n", m.AutoPosition)
		fmt.Fprintf(b, "scale = %s\n", tomlFloat(m.Scale))
		fmt.Fprintf(b, "transform = %d\n", m.Transform)
		fmt.Fprintf(b, "vrr = %d\n", m.VRR)
	}
}

// writeKeyboard renders [input] / [input.keyboard]. Without a keyboard
// domain (the shell sends none until the user changes the keyboard in
// Yozakura, keyboard.managed) nothing is rendered, so yozd generates no
// keyboard settings and the user's own compositor config stays in effect.
func writeKeyboard(b *strings.Builder, k *KeyboardInput) {
	if k == nil {
		return
	}
	b.WriteString("\n[input]\n[input.keyboard]\n")
	s := k.Settings()
	layouts, variants, options := s.Joined()
	fmt.Fprintf(b, "layouts = %s\n", tomlString(layouts))
	fmt.Fprintf(b, "variants = %s\n", tomlString(variants))
	fmt.Fprintf(b, "options = %s\n", tomlString(options))
	fmt.Fprintf(b, "model = %s\n", tomlString(s.Model))
	fmt.Fprintf(b, "repeat_rate = %d\n", s.RepeatRate)
	fmt.Fprintf(b, "repeat_delay = %d\n", s.RepeatDelay)
}

// KeyboardFromSettings is the inverse of Settings: the keyboard domain for
// XKB settings read from the compositor. A known layout-switch option
// becomes switchBind (the first one found; "none" without one), every other
// option stays in Options.
func KeyboardFromSettings(s ipc.KeyboardSettings) KeyboardInput {
	s = s.Normalize()
	k := KeyboardInput{SwitchBind: "none", Layouts: []KeyboardLayout{}, Options: []string{},
		Model: s.Model, RepeatRate: s.RepeatRate, RepeatDelay: s.RepeatDelay}
	for i, l := range s.Layouts {
		k.Layouts = append(k.Layouts, KeyboardLayout{Layout: l, Variant: s.Variants[i]})
	}
	for _, o := range s.Options {
		if bind := switchBindOf(o); bind != "" && k.SwitchBind == "none" {
			k.SwitchBind = bind
			continue
		}
		k.Options = append(k.Options, o)
	}
	return k
}

// switchBindOf names the switch bind whose XKB option is o ("" for none).
func switchBindOf(o string) string {
	for bind, opt := range switchBindOptions {
		if opt == o {
			return bind
		}
	}
	return ""
}

// tomlFloat always carries a decimal point so TOML decodes it as a float.
func tomlFloat(v float64) string {
	s := strconv.FormatFloat(v, 'f', -1, 64)
	if !strings.ContainsAny(s, ".eE") {
		s += ".0"
	}
	return s
}
