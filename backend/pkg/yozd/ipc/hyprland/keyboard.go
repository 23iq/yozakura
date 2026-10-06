package hyprland

import (
	"encoding/json"
	"fmt"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

type hyprKeyboardJSON struct {
	Name         string `json:"name"`
	Layout       string `json:"layout"`
	ActiveKeymap string `json:"active_keymap"`
	Main         bool   `json:"main"`
}

// parseHyprActiveLayout reads `j/devices` and returns the main keyboard's
// layout state. Index is always 0: j/devices reports only the active keymap
// name, not its position.
func parseHyprActiveLayout(data []byte) (ipc.KeyboardLayoutState, error) {
	var d struct {
		Keyboards []hyprKeyboardJSON `json:"keyboards"`
	}
	if err := json.Unmarshal(data, &d); err != nil {
		return ipc.KeyboardLayoutState{}, fmt.Errorf("parse devices: %w", err)
	}
	if len(d.Keyboards) == 0 {
		return ipc.KeyboardLayoutState{}, fmt.Errorf("no keyboards")
	}
	kb := d.Keyboards[0]
	for _, k := range d.Keyboards {
		if k.Main {
			kb = k
			break
		}
	}
	st := ipc.KeyboardLayoutState{Names: []string{}, Name: kb.ActiveKeymap}
	if kb.Layout != "" {
		st.Names = strings.Split(kb.Layout, ",")
	}
	return st, nil
}

// hyprKeyboardEntry is one `input` key of the full keyboard settings.
type hyprKeyboardEntry struct {
	key, value string
	str        bool // string value (quoted in Lua)
}

// hyprKeyboardEntries lists the input keys for s (already normalized and
// validated), shared by the live commands and the generated configs. Empty
// options are kept (they clear options); model and key repeat are set only
// when non-zero.
func hyprKeyboardEntries(s ipc.KeyboardSettings) []hyprKeyboardEntry {
	layouts, variants, options := s.Joined()
	e := []hyprKeyboardEntry{
		{"kb_layout", layouts, true},
		{"kb_variant", variants, true},
		{"kb_options", options, true},
	}
	if s.Model != "" {
		e = append(e, hyprKeyboardEntry{"kb_model", s.Model, true})
	}
	if s.RepeatRate > 0 {
		e = append(e, hyprKeyboardEntry{"repeat_rate", fmt.Sprint(s.RepeatRate), false})
	}
	if s.RepeatDelay > 0 {
		e = append(e, hyprKeyboardEntry{"repeat_delay", fmt.Sprint(s.RepeatDelay), false})
	}
	return e
}

// hyprKeyboardLua is the `hl.config({ input = { ... } })` call for s.
func hyprKeyboardLua(s ipc.KeyboardSettings) string {
	parts := make([]string, 0, 6)
	for _, e := range hyprKeyboardEntries(s) {
		if e.str {
			parts = append(parts, fmt.Sprintf("%s = %q", e.key, e.value))
		} else {
			parts = append(parts, e.key+" = "+e.value)
		}
	}
	return "hl.config({ input = { " + strings.Join(parts, ", ") + " } })"
}

// buildHyprKeyboardCmds builds the raw hyprctl requests for s (already
// normalized and validated). Tokens are xkb names; Lua values are %q-quoted.
// full=false emits only kb_layout and kb_variant, leaving options, model and
// key repeat untouched; full=true also sets them (empty options clear them).
func buildHyprKeyboardCmds(s ipc.KeyboardSettings, lua, full bool) []string {
	layouts, variants, _ := s.Joined()
	if !full {
		if lua {
			return []string{fmt.Sprintf("eval hl.config({ input = { kb_layout = %q, kb_variant = %q } })", layouts, variants)}
		}
		return []string{"keyword input:kb_layout " + layouts, "keyword input:kb_variant " + variants}
	}
	if lua {
		return []string{"eval " + hyprKeyboardLua(s)}
	}
	var cmds []string
	for _, e := range hyprKeyboardEntries(s) {
		cmds = append(cmds, "keyword input:"+e.key+" "+e.value)
	}
	return cmds
}

// ApplyKeyboard applies the full XKB settings at runtime.
func (h *Hyprland) ApplyKeyboard(s ipc.KeyboardSettings) error {
	return h.applyKeyboard(s, true)
}

func (h *Hyprland) applyKeyboard(s ipc.KeyboardSettings, full bool) error {
	if err := s.Validate(); err != nil {
		return err
	}
	s = s.Normalize()
	if len(s.Layouts) == 0 {
		return fmt.Errorf("no keyboard layouts")
	}
	for _, cmd := range buildHyprKeyboardCmds(s, h.supportsLuaDispatchers(), full) {
		if _, err := h.dispatch(cmd); err != nil {
			return err
		}
	}
	return nil
}

// ActiveLayout returns the main keyboard's active layout.
func (h *Hyprland) ActiveLayout() (ipc.KeyboardLayoutState, error) {
	resp, err := h.dispatch("j/devices")
	if err != nil {
		return ipc.KeyboardLayoutState{}, err
	}
	return parseHyprActiveLayout([]byte(resp))
}

// parseActiveLayoutEvent parses the socket2 payload of
// `activelayout>>KEYBOARDNAME,LAYOUTNAME`. The layout name may contain commas.
func parseActiveLayoutEvent(payload string) (map[string]interface{}, bool) {
	_, name, ok := strings.Cut(payload, ",")
	if !ok {
		return nil, false
	}
	return map[string]interface{}{"name": name}, true
}

// hyprKeyboardOptions are the `input:` options CurrentKeyboard reads.
var hyprKeyboardOptions = []string{"kb_layout", "kb_variant", "kb_options", "kb_model", "repeat_rate", "repeat_delay"}

// parseHyprOption reads a `j/getoption` reply: {"str": "us,ru"} or
// {"int": 25}. Hyprland reports an empty string as "[[EMPTY]]".
func parseHyprOption(data []byte) (str string, num int, err error) {
	var o struct {
		Str *string  `json:"str"`
		Int *float64 `json:"int"`
	}
	if err := json.Unmarshal(data, &o); err != nil {
		return "", 0, fmt.Errorf("parse getoption: %w", err)
	}
	if o.Str != nil && *o.Str != "[[EMPTY]]" {
		str = strings.TrimSpace(*o.Str)
	}
	if o.Int != nil {
		num = int(*o.Int)
	}
	return str, num, nil
}

// currentKeyboardFrom builds the settings from the getoption replies keyed
// by option name (see hyprKeyboardOptions).
func currentKeyboardFrom(replies map[string][]byte) (ipc.KeyboardSettings, error) {
	vals := map[string]string{}
	nums := map[string]int{}
	for _, opt := range hyprKeyboardOptions {
		raw, ok := replies[opt]
		if !ok {
			continue
		}
		s, n, err := parseHyprOption(raw)
		if err != nil {
			return ipc.KeyboardSettings{}, fmt.Errorf("%s: %w", opt, err)
		}
		vals[opt], nums[opt] = s, n
	}
	split := func(s string) []string {
		if s == "" {
			return nil
		}
		return strings.Split(s, ",")
	}
	k := ipc.KeyboardSettings{
		Layouts:     split(vals["kb_layout"]),
		Variants:    split(vals["kb_variant"]),
		Options:     split(vals["kb_options"]),
		Model:       vals["kb_model"],
		RepeatRate:  nums["repeat_rate"],
		RepeatDelay: nums["repeat_delay"],
	}
	return k.Normalize(), nil
}

// CurrentKeyboard reads the keyboard settings in effect (`getoption
// input:...`), whoever set them.
func (h *Hyprland) CurrentKeyboard() (ipc.KeyboardSettings, error) {
	replies := map[string][]byte{}
	for _, opt := range hyprKeyboardOptions {
		resp, err := h.dispatch("j/getoption input:" + opt)
		if err != nil {
			return ipc.KeyboardSettings{}, err
		}
		replies[opt] = []byte(resp)
	}
	return currentKeyboardFrom(replies)
}
