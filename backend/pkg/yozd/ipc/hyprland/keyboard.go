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

// buildHyprKeyboardCmds builds the raw hyprctl requests for s (already
// normalized and validated). Tokens are xkb names; Lua values are %q-quoted.
// full=false emits only kb_layout and kb_variant, leaving options, model and
// key repeat untouched; full=true also sets them (empty options clear them).
func buildHyprKeyboardCmds(s ipc.KeyboardSettings, lua, full bool) []string {
	layouts, variants, options := s.Joined()
	if !full {
		if lua {
			return []string{fmt.Sprintf("eval hl.config({ input = { kb_layout = %q, kb_variant = %q } })", layouts, variants)}
		}
		return []string{"keyword input:kb_layout " + layouts, "keyword input:kb_variant " + variants}
	}
	if lua {
		cmd := fmt.Sprintf("eval hl.config({ input = { kb_layout = %q, kb_variant = %q, kb_options = %q", layouts, variants, options)
		if s.Model != "" {
			cmd += fmt.Sprintf(", kb_model = %q", s.Model)
		}
		if s.RepeatRate > 0 {
			cmd += fmt.Sprintf(", repeat_rate = %d", s.RepeatRate)
		}
		if s.RepeatDelay > 0 {
			cmd += fmt.Sprintf(", repeat_delay = %d", s.RepeatDelay)
		}
		return []string{cmd + " } })"}
	}
	cmds := []string{
		"keyword input:kb_layout " + layouts,
		"keyword input:kb_variant " + variants,
		"keyword input:kb_options " + options,
	}
	if s.Model != "" {
		cmds = append(cmds, "keyword input:kb_model "+s.Model)
	}
	if s.RepeatRate > 0 {
		cmds = append(cmds, fmt.Sprintf("keyword input:repeat_rate %d", s.RepeatRate))
	}
	if s.RepeatDelay > 0 {
		cmds = append(cmds, fmt.Sprintf("keyword input:repeat_delay %d", s.RepeatDelay))
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
