package yozakura

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"

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

// ErrKeyboardUnreadable: the compositor cannot report its keyboard
// settings, so taking over replaces them; the caller must confirm (replace).
var ErrKeyboardUnreadable = errors.New("the compositor's keyboard settings cannot be read; changing them here replaces them (run again with --replace, MCP: replace=true)")

// KeyboardTakeoverKeys are the keyboard keys that reach the compositor
// (showIndicator is the shell's own).
var KeyboardTakeoverKeys = map[string]bool{
	"layouts": true, "switchBind": true, "options": true, "repeatRate": true, "repeatDelay": true,
}

// ManageKeyboard prepares an explicit keyboard edit: when the keyboard is
// not managed yet it copies the compositor's current settings into the
// keyboard domain and sets keyboard.managed, in one atomic write. It fails
// (writing nothing) when the daemon cannot be asked, so the user's settings
// are never replaced by the defaults; when the compositor cannot report
// them it fails with ErrKeyboardUnreadable unless replace is set (then the
// configured values are taken). A repeat value outside the catalog range
// keeps the configured one.
func ManageKeyboard(store *catalog.Store, c Caller, replace bool) error {
	managed, err := KeyboardManaged(store)
	if err != nil || managed {
		return err
	}
	cur, err := CurrentKeyboard(c)
	if err != nil {
		return fmt.Errorf("cannot read the compositor's keyboard settings (%v); is the shell running?", err)
	}
	var kv []catalog.KV
	if cur.Available {
		layouts := make([]any, 0, len(cur.Layouts))
		for _, l := range cur.Layouts {
			layouts = append(layouts, map[string]any{"layout": l.Layout, "variant": l.Variant})
		}
		opts := make([]any, 0, len(cur.Options))
		for _, o := range cur.Options {
			opts = append(opts, o)
		}
		kv = append(kv, catalog.KV{Key: "keyboard.layouts", Value: layouts}, catalog.KV{Key: "keyboard.options", Value: opts})
		if ValidSwitchBind(cur.SwitchBind) {
			kv = append(kv, catalog.KV{Key: "keyboard.switchBind", Value: cur.SwitchBind})
		}
		for key, v := range map[string]int{"keyboard.repeatRate": cur.RepeatRate, "keyboard.repeatDelay": cur.RepeatDelay} {
			if inRange(store, key, float64(v)) {
				kv = append(kv, catalog.KV{Key: key, Value: float64(v)})
			}
		}
	} else if !replace {
		return ErrKeyboardUnreadable
	}
	kv = append(kv, catalog.KV{Key: "keyboard.managed", Value: true})
	_, err = store.SetAll(kv)
	return err
}

// inRange reports whether v lies in the catalog range of key.
func inRange(store *catalog.Store, key string, v float64) bool {
	e, ok := store.Cat.Entry(key)
	if !ok {
		return false
	}
	return (e.Min == nil || v >= *e.Min) && (e.Max == nil || v <= *e.Max)
}

// PrepareConfigSet runs before a generic config write (`config set`,
// config_set, `config toggle`): a keyboard key that reaches the compositor,
// or keyboard.managed=true, first takes the keyboard over (ManageKeyboard).
// The value is validated before, so a failing command never flips managed.
func PrepareConfigSet(store *catalog.Store, c Caller, key string, value any, force, replace bool) error {
	ref, err := store.Cat.Lookup(key)
	if err != nil || ref.Entry.Domain != "keyboard" {
		return nil // the write itself reports a bad key
	}
	name := strings.SplitN(strings.TrimPrefix(ref.Entry.Key, "keyboard."), ".", 2)[0]
	if !KeyboardTakeoverKeys[name] && !(name == "managed" && value == true) {
		return nil
	}
	if err := store.Check(key, value, force); err != nil {
		return err
	}
	return ManageKeyboard(store, c, replace)
}
