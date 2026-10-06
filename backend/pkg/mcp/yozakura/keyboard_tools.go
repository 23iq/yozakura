package yozakura

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/mcp"
)

// Keyboard tools and the layout editing shared with `yozakura keyboard`.
// Layouts live in the keyboard config domain (keyboard.layouts,
// keyboard.switchBind); the shell applies them live and the backend renders
// them into the compositor config.

// SwitchBinds are the accepted keyboard.switchBind values.
var SwitchBinds = []string{"alt_shift", "super_space", "caps", "ctrl_shift", "none"}

// KeyboardLayout is one entry of keyboard.layouts.
type KeyboardLayout struct {
	Layout  string `json:"layout"`
	Variant string `json:"variant"`
}

func (l KeyboardLayout) String() string {
	if l.Variant == "" {
		return l.Layout
	}
	return l.Layout + ":" + l.Variant
}

var (
	layoutRe  = regexp.MustCompile(`^[a-z0-9_]+$`)
	variantRe = regexp.MustCompile(`^[A-Za-z0-9_.-]+$`)
)

// ParseLayoutSpec reads "ru", "us:intl" or "us(intl)".
func ParseLayoutSpec(s string) (KeyboardLayout, error) {
	s = strings.TrimSpace(s)
	l := KeyboardLayout{Layout: s}
	if i := strings.IndexAny(s, ":("); i >= 0 {
		l.Layout, l.Variant = s[:i], strings.TrimSuffix(s[i+1:], ")")
	}
	if !layoutRe.MatchString(l.Layout) {
		return l, fmt.Errorf("invalid layout %q: use <layout>[:<variant>], e.g. ru or us:intl", s)
	}
	if l.Variant != "" && !variantRe.MatchString(l.Variant) {
		return l, fmt.Errorf("invalid variant %q", l.Variant)
	}
	return l, nil
}

// AddLayout appends l unless present; the bool reports a change.
func AddLayout(list []KeyboardLayout, l KeyboardLayout) ([]KeyboardLayout, bool) {
	for _, x := range list {
		if x == l {
			return list, false
		}
	}
	return append(append([]KeyboardLayout(nil), list...), l), true
}

// RemoveLayout drops l (a bare layout name removes every variant of it). The
// last layout cannot be removed.
func RemoveLayout(list []KeyboardLayout, l KeyboardLayout) ([]KeyboardLayout, error) {
	var out []KeyboardLayout
	for _, x := range list {
		if x == l || (l.Variant == "" && x.Layout == l.Layout) {
			continue
		}
		out = append(out, x)
	}
	switch {
	case len(out) == len(list):
		return nil, fmt.Errorf("layout %s is not configured", l)
	case len(out) == 0:
		return nil, fmt.Errorf("cannot remove the last layout")
	}
	return out, nil
}

// ValidSwitchBind reports whether s is a known switch binding.
func ValidSwitchBind(s string) bool {
	for _, b := range SwitchBinds {
		if b == s {
			return true
		}
	}
	return false
}

// KeyboardState is the keyboard config plus the active layout (when the
// daemon answers).
type KeyboardState struct {
	Layouts    []KeyboardLayout `json:"layouts"`
	SwitchBind string           `json:"switchBind"`
	Active     json.RawMessage  `json:"active,omitempty"`
}

// ReadKeyboard reads the config; c may be nil (no active layout then).
func ReadKeyboard(store *catalog.Store, c Caller) (KeyboardState, error) {
	var st KeyboardState
	v, _, err := store.Get("keyboard.layouts")
	if err != nil {
		return st, err
	}
	raw, _ := json.Marshal(v)
	if err := json.Unmarshal(raw, &st.Layouts); err != nil {
		return st, err
	}
	b, _, err := store.Get("keyboard.switchBind")
	if err != nil {
		return st, err
	}
	st.SwitchBind, _ = b.(string)
	if c != nil {
		if a, err := c.Call("keyboard.active", nil); err == nil {
			st.Active = a
		}
	}
	return st, nil
}

// CheckLayoutKnown asks the daemon's XKB catalog; it passes when the daemon
// or the catalog is unavailable (the compositor validates in the end).
func CheckLayoutKnown(c Caller, l KeyboardLayout) error {
	if c == nil {
		return nil
	}
	raw, err := c.Call("keyboard.catalog", nil)
	if err != nil {
		return nil
	}
	var cat struct {
		Layouts []struct {
			Name     string
			Variants []struct{ Name string }
		}
	}
	if json.Unmarshal(raw, &cat) != nil || len(cat.Layouts) == 0 {
		return nil
	}
	for _, x := range cat.Layouts {
		if x.Name != l.Layout {
			continue
		}
		if l.Variant == "" {
			return nil
		}
		for _, v := range x.Variants {
			if v.Name == l.Variant {
				return nil
			}
		}
		return fmt.Errorf("layout %s has no variant %q", l.Layout, l.Variant)
	}
	return fmt.Errorf("unknown layout %q (see the XKB layout list)", l.Layout)
}

// SaveLayouts writes keyboard.layouts through the validated config layer.
func SaveLayouts(store *catalog.Store, list []KeyboardLayout) error {
	raw, _ := json.Marshal(list)
	var v any
	_ = json.Unmarshal(raw, &v)
	_, err := store.Set("keyboard.layouts", v, false)
	return err
}

func keyboardTools(d Deps) []mcp.ToolDef {
	return []mcp.ToolDef{
		define("keyboard_get", "Keyboard layouts",
			`The configured keyboard layouts, the layout switch binding and the layout that is active now.`,
			noArgs, toolOpts{readOnly: true}, d.keyboardGet),
		define("keyboard_set", "Set keyboard layouts",
			`Change the keyboard layouts. "add" / "remove": a layout like "ru" or "us:intl"; "switchBind": alt_shift, super_space, caps, ctrl_shift or none; "next": true switches to the next layout now. Give one or more.`,
			`{"type":"object","properties":{"add":{"type":"string"},"remove":{"type":"string"},"switchBind":{"type":"string","enum":["alt_shift","super_space","caps","ctrl_shift","none"]},"next":{"type":"boolean"}},"additionalProperties":false}`,
			toolOpts{idempotent: true}, d.keyboardSet),
	}
}

func (d Deps) keyboardGet(_ context.Context, _ json.RawMessage) (*mcp.CallToolResult, error) {
	_, store, err := d.catalog()
	if err != nil {
		return nil, err
	}
	var c Caller
	if d.IPC != nil {
		c = d.IPC
	}
	st, err := ReadKeyboard(store, c)
	if err != nil {
		return nil, err
	}
	return mcp.JSONResult(st), nil
}

func (d Deps) keyboardSet(_ context.Context, args json.RawMessage) (*mcp.CallToolResult, error) {
	var a struct {
		Add, Remove, SwitchBind string
		Next                    bool
	}
	if err := decode(args, &a); err != nil {
		return nil, err
	}
	if a.Add == "" && a.Remove == "" && a.SwitchBind == "" && !a.Next {
		return nil, fmt.Errorf("give add, remove, switchBind or next")
	}
	_, store, err := d.catalog()
	if err != nil {
		return nil, err
	}
	before, err := ReadKeyboard(store, nil)
	if err != nil {
		return nil, err
	}
	list := before.Layouts
	var back []map[string]any
	if a.Add != "" {
		l, err := ParseLayoutSpec(a.Add)
		if err != nil {
			return nil, err
		}
		if err := CheckLayoutKnown(d.callerOrNil(), l); err != nil {
			return nil, err
		}
		var changed bool
		if list, changed = AddLayout(list, l); changed {
			back = append(back, map[string]any{"remove": l.String()})
		}
	}
	if a.Remove != "" {
		l, err := ParseLayoutSpec(a.Remove)
		if err != nil {
			return nil, err
		}
		if list, err = RemoveLayout(list, l); err != nil {
			return nil, err
		}
		back = append(back, map[string]any{"add": l.String()})
	}
	if len(list) != len(before.Layouts) {
		if err := SaveLayouts(store, list); err != nil {
			return nil, err
		}
	}
	out := map[string]any{"layouts": list}
	if a.SwitchBind != "" {
		if !ValidSwitchBind(a.SwitchBind) {
			return nil, fmt.Errorf("switchBind must be one of %s", strings.Join(SwitchBinds, ", "))
		}
		if _, err := store.Set("keyboard.switchBind", a.SwitchBind, false); err != nil {
			return nil, err
		}
		out["switchBind"] = a.SwitchBind
		if before.SwitchBind != a.SwitchBind {
			back = append(back, map[string]any{"switchBind": before.SwitchBind})
		}
	}
	if a.Next {
		if _, err := d.call("keyboard.next", nil); err != nil {
			return nil, err
		}
		out["next"] = true
	}
	if len(back) == 1 && !a.Next {
		out["undo"] = undo("keyboard_set", back[0])
	}
	return mcp.JSONResult(out), nil
}

func (d Deps) callerOrNil() Caller {
	if d.IPC == nil {
		return nil
	}
	return d.IPC
}
