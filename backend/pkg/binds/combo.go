// Package binds is the bind advisor: it reads the keybind action catalog
// (assets/schema/bind-actions.json, generated from config/KeybindActions.js
// and config/CoreBinds.js), the user's binds.json and the compositor's own
// binds (through yozd), and answers search / list / check / suggest. It
// edits binds.json only (set / remove, with an undo token), never the
// compositor config: the shell watches binds.json and regenerates the
// compositor binds from it. Used by `yozakura binds` and the MCP binds_*
// tools.
package binds

import (
	"fmt"
	"strings"
	"unicode/utf8"
)

// Combo is a key combination as stored in binds.json.
// Field order matches the shell's binds.json ("key" before "modifiers").
type Combo struct {
	Key       string   `json:"key"`
	Modifiers []string `json:"modifiers"`
}

var modOrder = []string{"SUPER", "CTRL", "ALT", "SHIFT"}

var modAliases = map[string]string{
	"SUPER": "SUPER", "MOD4": "SUPER", "WIN": "SUPER", "LOGO": "SUPER", "META": "SUPER", "MOD": "SUPER", "$MAINMOD": "SUPER",
	"CTRL": "CTRL", "CONTROL": "CTRL", "CTL": "CTRL",
	"ALT": "ALT", "MOD1": "ALT",
	"SHIFT": "SHIFT",
}

// keyAliases mirrors modules/keybinds/KeyNames.js KEY_ALIASES (lower-case
// spelling -> canonical lower-case name).
var keyAliases = map[string]string{
	"enter": "return", "kp_enter": "return",
	"esc": "escape",
	".":   "period", ",": "comma", "/": "slash", ";": "semicolon", "'": "apostrophe",
	"[": "bracketleft", "]": "bracketright", "\\": "backslash", "-": "minus", "=": "equal", "`": "grave",
	" ":   "space",
	"del": "delete", "ins": "insert",
	"prior": "page_up", "pgup": "page_up", "pageup": "page_up",
	"next": "page_down", "pgdn": "page_down", "pagedown": "page_down",
	"super_r": "super_l", "super": "super_l",
	"sysrq": "print",
}

// storedKeys is how a canonical key is written to binds.json when the user
// typed a symbol ("." -> "PERIOD"), matching the shell's own defaults.
var storedKeys = map[string]string{
	"period": "PERIOD", "comma": "COMMA", "slash": "SLASH", "semicolon": "SEMICOLON", "apostrophe": "APOSTROPHE",
	"bracketleft": "BRACKETLEFT", "bracketright": "BRACKETRIGHT", "backslash": "BACKSLASH", "minus": "MINUS",
	"equal": "EQUAL", "grave": "GRAVE", "space": "SPACE", "return": "RETURN", "escape": "ESCAPE", "tab": "TAB",
	"super_l": "Super_L", "delete": "Delete", "print": "Print",
}

// NormalizeMod returns the canonical modifier name ("" if unknown).
func NormalizeMod(m string) string {
	return modAliases[strings.ToUpper(strings.TrimSpace(m))]
}

// NormalizeKey returns the canonical (lower-case) key name.
func NormalizeKey(key string) string {
	k := key
	if k != " " {
		k = strings.TrimSpace(k)
	}
	lower := strings.ToLower(k)
	if a, ok := keyAliases[lower]; ok {
		return a
	}
	return lower
}

// NormalizeMods de-duplicates and orders modifiers (SUPER CTRL ALT SHIFT).
func NormalizeMods(mods []string) []string {
	seen := map[string]bool{}
	for _, m := range mods {
		if n := NormalizeMod(m); n != "" {
			seen[n] = true
		}
	}
	out := []string{}
	for _, m := range modOrder {
		if seen[m] {
			out = append(out, m)
		}
	}
	return out
}

// ID is the identity of a combo for conflict detection (KeyNames.comboId):
// "SUPER+SHIFT|s"; "" for an empty key. A lone Super press is SUPER+Super_L
// with or without the modifier.
func (c Combo) ID() string {
	k := NormalizeKey(c.Key)
	if k == "" {
		return ""
	}
	mods := c.Modifiers
	if k == "super_l" {
		mods = append(append([]string{}, mods...), "SUPER")
	}
	return strings.Join(NormalizeMods(mods), "+") + "|" + k
}

// String prints the combo for people and models: "SUPER+SHIFT+S".
func (c Combo) String() string {
	k := NormalizeKey(c.Key)
	if k == "" {
		return ""
	}
	mods := NormalizeMods(c.Modifiers)
	if k == "super_l" {
		return "SUPER"
	}
	return strings.Join(append(mods, displayKey(k, c.Key)), "+")
}

func displayKey(k, orig string) string {
	if utf8.RuneCountInString(k) == 1 {
		return strings.ToUpper(k)
	}
	if s, ok := storedKeys[k]; ok {
		return strings.ToUpper(s)
	}
	return strings.TrimSpace(orig) // e.g. XF86AudioRaiseVolume, mouse:272
}

// Stored is the combo as written to binds.json (ordered modifiers, letters
// upper-case, symbols by name).
func (c Combo) Stored() Combo {
	k := NormalizeKey(c.Key)
	key := strings.TrimSpace(c.Key)
	switch {
	case utf8.RuneCountInString(k) == 1:
		key = strings.ToUpper(k)
	case storedKeys[k] != "":
		key = storedKeys[k]
	}
	mods := c.Modifiers
	if k == "super_l" {
		mods = append(append([]string{}, mods...), "SUPER")
	}
	return Combo{Modifiers: NormalizeMods(mods), Key: key}
}

// ParseCombo reads "SUPER+SHIFT+S", "super + shift + s", "Mod4 S",
// "SUPER SHIFT, S", "Super+." or "SUPER" (a lone Super press).
func ParseCombo(s string) (Combo, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return Combo{}, fmt.Errorf("empty key combination")
	}
	// A trailing "+" is the plus key ("SUPER++"), any other separator
	// splits.
	plusKey := strings.HasSuffix(s, "++") || s == "+"
	if plusKey {
		s = strings.TrimSuffix(strings.TrimSuffix(s, "+"), "+")
	}
	parts := strings.FieldsFunc(s, func(r rune) bool { return r == '+' || r == ',' || r == ' ' || r == '\t' })
	if plusKey {
		parts = append(parts, "plus")
	}
	if len(parts) == 0 {
		return Combo{}, fmt.Errorf("invalid key combination %q", s)
	}
	mods := []string{}
	last := len(parts) - 1
	for i, p := range parts {
		if m := NormalizeMod(p); m != "" && i < last {
			mods = append(mods, m)
			continue
		}
		if i < last {
			return Combo{}, fmt.Errorf("unknown modifier %q in %q (use SUPER, CTRL, ALT, SHIFT)", p, s)
		}
	}
	key := parts[last]
	// "SUPER" alone: the launcher-style lone Super press.
	if m := NormalizeMod(key); m != "" {
		if m != "SUPER" || len(mods) > 0 {
			return Combo{}, fmt.Errorf("%q has no key, only modifiers", s)
		}
		key = "Super_L"
	}
	return Combo{Modifiers: NormalizeMods(mods), Key: key}.Stored(), nil
}
