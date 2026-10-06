package ipc

import (
	"fmt"
	"regexp"
	"strings"
)

// KeyboardSettings is the desired XKB configuration.
type KeyboardSettings struct {
	Layouts     []string `json:"layouts"`  // ["us","ru"]
	Variants    []string `json:"variants"` // padded to len(Layouts) with ""
	Options     []string `json:"options"`  // ["grp:alt_shift_toggle","caps:escape"]
	Model       string   `json:"model"`
	RepeatRate  int      `json:"repeat_rate"`  // 0 = compositor default
	RepeatDelay int      `json:"repeat_delay"` // 0 = compositor default
}

// KeyboardLayoutState is the layout currently active on the main keyboard.
type KeyboardLayoutState struct {
	Names []string `json:"names"`
	Index int      `json:"index"`
	Name  string   `json:"name"` // e.g. "Russian"
}

// KeyboardManager is implemented by compositors that can apply XKB settings
// and report the active layout. Others answer with ErrNotSupported.
type KeyboardManager interface {
	ApplyKeyboard(KeyboardSettings) error
	ActiveLayout() (KeyboardLayoutState, error)
}

var xkbTokenRe = regexp.MustCompile(`^[A-Za-z0-9_:+()-]+$`)

// Validate rejects any token that is not a plain XKB name. Empty variants are
// allowed; empty layouts and options are dropped by Normalize.
func (k KeyboardSettings) Validate() error {
	check := func(kind, s string, allowEmpty bool) error {
		if s == "" && allowEmpty {
			return nil
		}
		if !xkbTokenRe.MatchString(s) {
			return fmt.Errorf("invalid xkb %s %q", kind, s)
		}
		return nil
	}
	for _, l := range k.Layouts {
		if err := check("layout", strings.TrimSpace(l), true); err != nil {
			return err
		}
	}
	for _, v := range k.Variants {
		if err := check("variant", strings.TrimSpace(v), true); err != nil {
			return err
		}
	}
	for _, o := range k.Options {
		if err := check("option", strings.TrimSpace(o), true); err != nil {
			return err
		}
	}
	if err := check("model", strings.TrimSpace(k.Model), true); err != nil {
		return err
	}
	if k.RepeatRate < 0 || k.RepeatDelay < 0 {
		return fmt.Errorf("negative key repeat")
	}
	return nil
}

// Normalize trims tokens, drops empty layouts (with their variant) and empty
// options, and pads or truncates Variants to len(Layouts). Tokens that fail
// the xkb pattern are dropped too; call Validate first to reject instead.
func (k KeyboardSettings) Normalize() KeyboardSettings {
	out := KeyboardSettings{RepeatRate: k.RepeatRate, RepeatDelay: k.RepeatDelay}
	if m := strings.TrimSpace(k.Model); xkbTokenRe.MatchString(m) {
		out.Model = m
	}
	for i, l := range k.Layouts {
		l = strings.TrimSpace(l)
		if !xkbTokenRe.MatchString(l) {
			continue
		}
		v := ""
		if i < len(k.Variants) {
			v = strings.TrimSpace(k.Variants[i])
			if v != "" && !xkbTokenRe.MatchString(v) {
				v = ""
			}
		}
		out.Layouts = append(out.Layouts, l)
		out.Variants = append(out.Variants, v)
	}
	for _, o := range k.Options {
		if o = strings.TrimSpace(o); xkbTokenRe.MatchString(o) {
			out.Options = append(out.Options, o)
		}
	}
	return out
}

// Joined returns the comma-separated layout, variant and option strings.
func (k KeyboardSettings) Joined() (layouts, variants, options string) {
	return strings.Join(k.Layouts, ","), strings.Join(k.Variants, ","), strings.Join(k.Options, ",")
}
