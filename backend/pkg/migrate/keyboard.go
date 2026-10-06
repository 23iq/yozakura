package migrate

import (
	"encoding/json"
	"os"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
)

// keyboard.json from before keyboard.managed (mirrors
// config/KeyboardMigration.js): the shell used to create it with the pure
// defaults below and push them over the user's own compositor settings, so
// such a file stays unmanaged; a file that differs was chosen by the user
// and stays managed.

// legacyKeyboardDefaults are the keyboard defaults the shell wrote before
// keyboard.managed existed (frozen: later default changes do not matter).
var legacyKeyboardDefaults = map[string]any{
	"layouts":     []any{map[string]any{"layout": "us", "variant": ""}},
	"switchBind":  "alt_shift",
	"options":     []any{},
	"repeatRate":  float64(25),
	"repeatDelay": float64(600),
}

// LegacyKeyboardManaged is the managed value for a keyboard document
// without the key: true when any compositor key differs from the legacy
// defaults (a missing key counts as the default).
func LegacyKeyboardManaged(doc map[string]any) bool {
	for k, def := range legacyKeyboardDefaults {
		v, ok := doc[k]
		if !ok {
			continue
		}
		if k == "layouts" {
			v = normLayouts(v)
		}
		a, _ := json.Marshal(v)
		b, _ := json.Marshal(def)
		if string(a) != string(b) {
			return true
		}
	}
	return false
}

func normLayouts(v any) any {
	list, ok := v.([]any)
	if !ok {
		return v
	}
	out := make([]any, 0, len(list))
	for _, x := range list {
		m, _ := x.(map[string]any)
		l, _ := m["layout"].(string)
		vr, _ := m["variant"].(string)
		out = append(out, map[string]any{"layout": l, "variant": vr})
	}
	return out
}

// EnsureKeyboardManaged runs on every start before the shell: a
// keyboard.json without keyboard.managed gets the value of
// LegacyKeyboardManaged. A missing or unreadable file is left alone.
func EnsureKeyboardManaged(p paths.Paths) (bool, error) {
	if p.ConfigDir == "" {
		return false, nil
	}
	path := p.Config("keyboard")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	v, err := catalog.DecodeOrdered(data)
	if err != nil {
		return false, nil // malformed: the shell backs it up
	}
	doc, ok := v.(*catalog.Object)
	if !ok {
		return false, nil
	}
	if _, has := doc.Get("managed"); has {
		return false, nil
	}
	plain, _ := catalog.Plain(doc).(map[string]any)
	doc.Set("managed", LegacyKeyboardManaged(plain))
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return false, err
	}
	return true, fsutil.WriteFile(path, out, 0o644)
}
