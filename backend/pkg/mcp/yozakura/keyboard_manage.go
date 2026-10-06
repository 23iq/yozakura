package yozakura

import (
	"encoding/json"
	"fmt"

	"yozakura/backend/pkg/catalog"
)

// Yozakura never overrides the user's own compositor keyboard settings
// until the user changes the keyboard in Yozakura (keyboard.managed).
// Before that the shell renders and applies nothing; the first explicit
// edit (CLI, MCP, settings page, onboarding) initialises the keyboard
// domain from the settings in effect, sets keyboard.managed and only then
// applies the edit, so layouts like us,ru from the user's own config are
// never lost.

// CompositorKeyboard is the backend's keyboard.current reply: the settings
// in effect on the compositor, in the keyboard domain's shape.
type CompositorKeyboard struct {
	Available   bool             `json:"available"`
	Layouts     []KeyboardLayout `json:"layouts"`
	SwitchBind  string           `json:"switchBind"`
	Options     []string         `json:"options"`
	RepeatRate  int              `json:"repeatRate"`
	RepeatDelay int              `json:"repeatDelay"`
}

// KeyboardManaged reports keyboard.managed.
func KeyboardManaged(store *catalog.Store) (bool, error) {
	v, _, err := store.Get("keyboard.managed")
	if err != nil {
		return false, err
	}
	return v == true, nil
}

// CurrentKeyboard asks the daemon for the compositor's keyboard settings.
func CurrentKeyboard(c Caller) (CompositorKeyboard, error) {
	var cur CompositorKeyboard
	if c == nil {
		return cur, fmt.Errorf("the daemon is not available")
	}
	raw, err := c.Call("keyboard.current", nil)
	if err != nil {
		return cur, err
	}
	if err := json.Unmarshal(raw, &cur); err != nil {
		return cur, fmt.Errorf("parse keyboard.current: %w", err)
	}
	cur.Available = cur.Available && len(cur.Layouts) > 0
	return cur, nil
}

// ManageKeyboard prepares an explicit keyboard edit: when the keyboard is
// not managed yet it copies the compositor's current settings into the
// keyboard domain, then sets keyboard.managed. It fails (writing nothing)
// when the current settings cannot be read, so they are never replaced by
// the defaults; a compositor that cannot report them (niri, Mango) keeps
// the configured values. Values outside the catalog range are left as
// configured.
func ManageKeyboard(store *catalog.Store, c Caller) error {
	managed, err := KeyboardManaged(store)
	if err != nil || managed {
		return err
	}
	cur, err := CurrentKeyboard(c)
	if err != nil {
		return fmt.Errorf("cannot read the compositor's keyboard settings (%v); is the shell running?", err)
	}
	if cur.Available {
		if err := SaveLayouts(store, cur.Layouts); err != nil {
			return err
		}
		if ValidSwitchBind(cur.SwitchBind) {
			if _, err := store.Set("keyboard.switchBind", cur.SwitchBind, false); err != nil {
				return err
			}
		}
		opts := make([]any, 0, len(cur.Options))
		for _, o := range cur.Options {
			opts = append(opts, o)
		}
		if _, err := store.Set("keyboard.options", opts, false); err != nil {
			return err
		}
		for key, v := range map[string]int{"keyboard.repeatRate": cur.RepeatRate, "keyboard.repeatDelay": cur.RepeatDelay} {
			if v > 0 {
				_, _ = store.Set(key, float64(v), false) // out of range: keep the configured value
			}
		}
	}
	_, err = store.Set("keyboard.managed", true, false)
	return err
}
