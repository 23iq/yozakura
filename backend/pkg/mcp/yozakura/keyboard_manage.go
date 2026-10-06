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
	kv, err := takeoverValues(store, c, replace)
	if err != nil || kv == nil {
		return err
	}
	_, err = store.SetAll(kv, false)
	return err
}

// takeoverValues are the writes that take the keyboard over (the
// compositor's current settings + managed=true); nil when it is managed.
// Nothing is written.
func takeoverValues(store *catalog.Store, c Caller, replace bool) ([]catalog.KV, error) {
	managed, err := KeyboardManaged(store)
	if err != nil || managed {
		return nil, err
	}
	cur, err := CurrentKeyboard(c)
	if err != nil {
		return nil, fmt.Errorf("cannot read the compositor's keyboard settings (%v); is the shell running?", err)
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
		for _, r := range []struct {
			key string
			v   int
		}{{"keyboard.repeatRate", cur.RepeatRate}, {"keyboard.repeatDelay", cur.RepeatDelay}} {
			if inRange(store, r.key, float64(r.v)) {
				kv = append(kv, catalog.KV{Key: r.key, Value: float64(r.v)})
			}
		}
	} else if !replace {
		return nil, ErrKeyboardUnreadable
	}
	return append(kv, catalog.KV{Key: "keyboard.managed", Value: true}), nil
}

// inRange reports whether v lies in the catalog range of key.
func inRange(store *catalog.Store, key string, v float64) bool {
	e, ok := store.Cat.Entry(key)
	if !ok {
		return false
	}
	return (e.Min == nil || v >= *e.Min) && (e.Max == nil || v <= *e.Max)
}

// KeyboardConfigSet performs a generic config write (`config set`,
// config_set, `config toggle`) of a keyboard key that reaches the
// compositor, or of keyboard.managed=true, while the keyboard is not
// managed yet: build gets the post-takeover value of the whole key (the
// compositor's layouts, not the defaults) and returns its new whole value,
// which is validated before the takeover and the write land together in
// one atomic write. handled is false for any other write (managed already,
// another key or domain, managed=false): the caller writes it as usual.
func KeyboardConfigSet(store *catalog.Store, c Caller, key string, build func(base any) (any, error), force, replace bool) (handled bool, changes []catalog.Change, err error) {
	handled, kv, _, err := planKeyboardConfigSet(store, c, key, build, force, replace)
	if !handled || err != nil {
		return handled, nil, err
	}
	changes, err = store.SetAll(kv, force)
	return true, changes, err
}

// KeyboardConfigPreview is KeyboardConfigSet without writing (--dry-run):
// old is the value the edit starts from (the compositor's while unmanaged),
// whole the value it would write. handled is false when KeyboardConfigSet
// would not handle the write.
func KeyboardConfigPreview(store *catalog.Store, c Caller, key string, build func(base any) (any, error), force, replace bool) (handled bool, old, whole any, err error) {
	handled, kv, old, err := planKeyboardConfigSet(store, c, key, build, force, replace)
	if !handled || err != nil {
		return handled, nil, nil, err
	}
	ref, _ := store.Cat.Lookup(key)
	for _, x := range kv {
		if x.Key == ref.Entry.Key {
			whole = x.Value
		}
	}
	return true, old, whole, nil
}

// planKeyboardConfigSet is the takeover + edit KeyboardConfigSet writes;
// base is the value build started from. Nothing is written.
func planKeyboardConfigSet(store *catalog.Store, c Caller, key string, build func(base any) (any, error), force, replace bool) (handled bool, kv []catalog.KV, base any, err error) {
	ref, err := store.Cat.Lookup(key)
	if err != nil || ref.Entry.Domain != "keyboard" {
		return false, nil, nil, nil // the write itself reports a bad key
	}
	name := strings.SplitN(strings.TrimPrefix(ref.Entry.Key, "keyboard."), ".", 2)[0]
	if !KeyboardTakeoverKeys[name] && name != "managed" {
		return false, nil, nil, nil
	}
	if managed, err := KeyboardManaged(store); err != nil || managed {
		return false, nil, nil, err
	}
	if name == "managed" {
		cur, _, err := store.Get(ref.Entry.Key)
		if err != nil {
			return false, nil, nil, err
		}
		if v, err := build(cur); err != nil || v != true {
			return false, nil, nil, err
		}
	}
	kv, err = takeoverValues(store, c, replace)
	if err != nil {
		return true, nil, nil, err
	}
	found := false
	for _, x := range kv {
		if x.Key == ref.Entry.Key {
			base, found = x.Value, true
		}
	}
	if !found {
		if base, _, err = store.Get(ref.Entry.Key); err != nil {
			return true, nil, nil, err
		}
	}
	whole, err := build(base)
	if err != nil {
		return true, nil, nil, err
	}
	if err := store.Check(ref.Entry.Key, whole, force); err != nil {
		return true, nil, nil, err
	}
	replaced := false
	for i := range kv {
		if kv[i].Key == ref.Entry.Key {
			kv[i].Value, replaced = whole, true
		}
	}
	if !replaced {
		kv = append(kv, catalog.KV{Key: ref.Entry.Key, Value: whole})
	}
	return true, kv, base, nil
}

// ItemAt is base (an array) with item at index: replaced, or appended at
// index == len.
func ItemAt(base any, index int, item any) (any, error) {
	arr, _ := base.([]any)
	arr = append([]any{}, arr...)
	switch {
	case index < len(arr):
		arr[index] = item
	case index == len(arr):
		arr = append(arr, item)
	default:
		return nil, fmt.Errorf("%d items; index %d is out of range", len(arr), index)
	}
	return arr, nil
}
