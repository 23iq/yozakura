package niri

import (
	"encoding/json"
	"fmt"

	"yozakura/backend/pkg/yozd/ipc"
)

type niriKeyboardLayouts struct {
	Names      []string `json:"names"`
	CurrentIdx int      `json:"current_idx"`
}

func (l niriKeyboardLayouts) state() ipc.KeyboardLayoutState {
	st := ipc.KeyboardLayoutState{Names: l.Names, Index: l.CurrentIdx}
	if st.Names == nil {
		st.Names = []string{}
	}
	if l.CurrentIdx >= 0 && l.CurrentIdx < len(l.Names) {
		st.Name = l.Names[l.CurrentIdx]
	}
	return st
}

// parseNiriKeyboardLayouts converts a `KeyboardLayouts` reply payload.
func parseNiriKeyboardLayouts(data []byte) (ipc.KeyboardLayoutState, error) {
	var l niriKeyboardLayouts
	if err := json.Unmarshal(data, &l); err != nil {
		return ipc.KeyboardLayoutState{}, fmt.Errorf("parse keyboard layouts: %w", err)
	}
	return l.state(), nil
}

// keyboardEventPayload maps KeyboardLayoutsChanged / KeyboardLayoutSwitched to
// the EventKeyboardLayout payload. Switched events carry only the index, so
// the name comes from the names cached by the last Changed event or request.
func (n *Niri) keyboardEventPayload(name string, data json.RawMessage) (map[string]interface{}, bool) {
	var idx int
	switch name {
	case "KeyboardLayoutsChanged":
		var d struct {
			Layouts niriKeyboardLayouts `json:"keyboard_layouts"`
		}
		if err := json.Unmarshal(data, &d); err != nil {
			return nil, false
		}
		n.kbMu.Lock()
		n.kbNames = d.Layouts.Names
		n.kbMu.Unlock()
		idx = d.Layouts.CurrentIdx
	case "KeyboardLayoutSwitched":
		var d struct {
			Idx int `json:"idx"`
		}
		if err := json.Unmarshal(data, &d); err != nil {
			return nil, false
		}
		idx = d.Idx
	default:
		return nil, false
	}
	p := map[string]interface{}{"index": idx}
	n.kbMu.Lock()
	if idx >= 0 && idx < len(n.kbNames) {
		p["name"] = n.kbNames[idx]
	}
	n.kbMu.Unlock()
	return p, true
}

// ApplyKeyboard: niri applies xkb settings from its config file, which the
// backend rewrites and niri reloads.
func (n *Niri) ApplyKeyboard(ipc.KeyboardSettings) error { return ipc.ErrNotSupported }

// ActiveLayout returns the current keyboard layout.
func (n *Niri) ActiveLayout() (ipc.KeyboardLayoutState, error) {
	raw, err := n.requestRaw("KeyboardLayouts")
	if err != nil {
		return ipc.KeyboardLayoutState{}, err
	}
	variant, err := unwrapVariant(raw, "KeyboardLayouts")
	if err != nil {
		return ipc.KeyboardLayoutState{}, err
	}
	st, err := parseNiriKeyboardLayouts(variant)
	if err == nil {
		n.kbMu.Lock()
		n.kbNames = st.Names
		n.kbMu.Unlock()
	}
	return st, err
}
