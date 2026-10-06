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
// keyboard.switchBind); once keyboard.managed is set (ManageKeyboard) the
// shell applies them live and the backend renders them into the compositor
// config.

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
// daemon answers). Managed is false while the user's own compositor
// settings are in effect; the layouts are then the compositor's (when the
// daemon reports them).
type KeyboardState struct {
	Layouts    []KeyboardLayout `json:"layouts"`
	SwitchBind string           `json:"switchBind"`
	Managed    bool             `json:"managed"`
	Active     json.RawMessage  `json:"active,omitempty"`
}

// ReadKeyboard reads the config; c may be nil (no active layout and no
// compositor values then).
func ReadKeyboard(store *catalog.Store, c Caller) (KeyboardState, error) {
	st, err := readKeyboardConfig(store)
	if err != nil || c == nil {
		return st, err
	}
	if !st.Managed {
		if cur, err := CurrentKeyboard(c); err == nil && cur.Available {
			st.Layouts, st.SwitchBind = cur.Layouts, cur.SwitchBind
		}
	}
	if a, err := c.Call("keyboard.active", nil); err == nil {
		st.Active = a
	}
	return st, nil
}

// readKeyboardConfig reads keyboard.layouts, switchBind and managed.
func readKeyboardConfig(store *catalog.Store) (KeyboardState, error) {
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
	st.Managed, err = KeyboardManaged(store)
	return st, err
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
			`The keyboard layouts, the layout switch binding and the layout that is active now. managed=false: Yozakura does not manage the keyboard yet and the compositor's own settings are shown; the first keyboard_set takes them over.`,
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
	// validate everything before writing anything
	var adds, removes []KeyboardLayout
	var err error
	if adds, err = parseLayoutList(a.Add); err != nil {
		return nil, err
	}
	if removes, err = parseLayoutList(a.Remove); err != nil {
		return nil, err
	}
	for _, l := range adds {
		if err := CheckLayoutKnown(d.callerOrNil(), l); err != nil {
			return nil, err
		}
	}
	if a.SwitchBind != "" && !ValidSwitchBind(a.SwitchBind) {
		return nil, fmt.Errorf("switchBind must be one of %s", strings.Join(SwitchBinds, ", "))
	}
	_, store, err := d.catalog()
	if err != nil {
		return nil, err
	}
	if a.Add != "" || a.Remove != "" || a.SwitchBind != "" {
		if err := ManageKeyboard(store, d.callerOrNil()); err != nil {
			return nil, err
		}
	}
	before, err := ReadKeyboard(store, nil)
	if err != nil {
		return nil, err
	}
	list := before.Layouts
	var back []map[string]any
	var added []string
	for _, l := range adds {
		var changed bool
		if list, changed = AddLayout(list, l); changed {
			added = append(added, l.String())
		}
	}
	if len(added) > 0 {
		back = append(back, map[string]any{"remove": strings.Join(added, ",")})
	}
	for _, l := range removes {
		prev := list
		if list, err = RemoveLayout(list, l); err != nil {
			return nil, err
		}
		var gone []string
		for _, x := range prev {
			if x == l || (l.Variant == "" && x.Layout == l.Layout) {
				gone = append(gone, x.String())
			}
		}
		back = append(back, map[string]any{"add": strings.Join(gone, ",")})
	}
	if len(list) != len(before.Layouts) {
		if err := SaveLayouts(store, list); err != nil {
			return nil, err
		}
	}
	out := map[string]any{"layouts": list}
	if a.SwitchBind != "" {
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

// parseLayoutList reads one spec or a comma separated list ("" = none).
func parseLayoutList(s string) ([]KeyboardLayout, error) {
	var out []KeyboardLayout
	for _, p := range strings.Split(s, ",") {
		if strings.TrimSpace(p) == "" {
			continue
		}
		l, err := ParseLayoutSpec(p)
		if err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, nil
}
