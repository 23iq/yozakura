// Package specials manages the special workspaces (Hyprland scratchpads)
// of config domain "specials": the model, safe Hyprland names (mirroring
// modules/specials/Specials.js, parity fixture
// tests/fixtures/special-names.json), edits through the validated catalog
// store, installed desktop entries for app suggestions and the one-time
// import of hand-written binds (ImportBinds). The CLI (`yozakura special`)
// and the MCP tools both use it. Specials are global like binds.json:
// catalog.LocalDomains keeps presets away from them.
package specials

import (
	"encoding/json"
	"fmt"
	"regexp"
	"slices"
	"strings"
	"unicode/utf8"

	"yozakura/backend/pkg/catalog"
)

// Key is the catalog key of the list.
const Key = "specials.workspaces"

// MaxName mirrors Specials.MAX_NAME.
const MaxName = 32

// Combo is a key combination ({modifiers, key}, binds.json shape).
type Combo struct {
	Modifiers []string `json:"modifiers"`
	Key       string   `json:"key"`
}

// Empty reports a combo without a key.
func (c Combo) Empty() bool { return c.Key == "" }

// App is one app of a special.
type App struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Icon      string `json:"icon"`
	Match     string `json:"match"`
	Command   string `json:"command"`
	IfRunning string `json:"ifRunning"`
	Rule      bool   `json:"rule"`
}

// Special is one item of specials.workspaces.
type Special struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Icon    string `json:"icon"`
	Accent  string `json:"accent"`
	Toggle  Combo  `json:"toggle"`
	Send    Combo  `json:"send"`
	Preload bool   `json:"preload"`
	Apps    []App  `json:"apps"`
}

// unsafeRe mirrors Specials.UNSAFE.
var unsafeRe = regexp.MustCompile("[\\s\\p{Z}\ufeff,:;\\[\\]\"'`\\\\/$|&(){}<>*?#!=%@^~+]+")

// SanitizeName turns a display name into a Hyprland-safe special name.
func SanitizeName(name string) string {
	s := strings.TrimSpace(name)
	s = unsafeRe.ReplaceAllString(s, "-")
	s = regexp.MustCompile(`-+`).ReplaceAllString(s, "-")
	s = strings.Trim(s, "-.")
	if utf8.RuneCountInString(s) > MaxName {
		s = strings.TrimRight(string([]rune(s)[:MaxName]), "-.")
	}
	return s
}

// HyprNames maps every id to its unique Hyprland name (list order).
func HyprNames(list []Special) map[string]string {
	out := map[string]string{}
	used := map[string]bool{}
	for i, it := range list {
		base := SanitizeName(it.Name)
		if base == "" {
			base = fmt.Sprintf("special-%d", i+1)
		}
		name := base
		for n := 2; used[strings.ToLower(name)]; n++ {
			name = fmt.Sprintf("%s-%d", base, n)
		}
		used[strings.ToLower(name)] = true
		id := it.ID
		if id == "" {
			id = fmt.Sprintf("#%d", i)
		}
		out[id] = name
	}
	return out
}

func slug(name string) string {
	s := strings.ToLower(SanitizeName(name))
	s = regexp.MustCompile(`[^a-z0-9_-]+`).ReplaceAllString(s, "")
	if s == "" {
		return "special"
	}
	return s
}

// NewID returns an id for name not used in list.
func NewID(list []Special, name string) string {
	ids := map[string]bool{}
	for _, it := range list {
		ids[it.ID] = true
	}
	base := slug(name)
	id := base
	for n := 2; ids[id]; n++ {
		id = fmt.Sprintf("%s-%d", base, n)
	}
	return id
}

// Find resolves an id, display name or Hyprland name (case-insensitive).
func Find(list []Special, ref string) (int, bool) {
	ref = strings.TrimPrefix(ref, "special:")
	names := HyprNames(list)
	for i, it := range list {
		if it.ID == ref {
			return i, true
		}
	}
	for i, it := range list {
		if strings.EqualFold(it.Name, ref) || strings.EqualFold(names[it.ID], ref) {
			return i, true
		}
	}
	return -1, false
}

// Normalize fills defaults the shell would (icon, accent, ifRunning).
func Normalize(it Special) Special {
	if it.Icon == "" {
		it.Icon = "stack"
	}
	if it.Accent == "" {
		it.Accent = "primary"
	}
	if it.Toggle.Modifiers == nil {
		it.Toggle.Modifiers = []string{}
	}
	if it.Send.Modifiers == nil {
		it.Send.Modifiers = []string{}
	}
	if it.Apps == nil {
		it.Apps = []App{}
	}
	for i := range it.Apps {
		if it.Apps[i].IfRunning != "move" {
			it.Apps[i].IfRunning = "nothing"
		}
		if it.Apps[i].Match == "" {
			it.Apps[i].Match = it.Apps[i].ID
		}
		if it.Apps[i].Name == "" {
			it.Apps[i].Name = it.Apps[i].Match
		}
	}
	return it
}

// Accents mirrors Specials.ACCENTS (palette roles, never hex).
var Accents = []string{"primary", "secondary", "tertiary", "error", "red", "yellow", "green", "cyan", "blue", "magenta"}

// Problems mirrors Specials.problems (empty or clashing names) and checks
// accents and ifRunning values.
func Problems(list []Special) []string {
	var out []string
	seen := map[string]string{}
	for _, it := range list {
		if it.Accent != "" && !slices.Contains(Accents, it.Accent) {
			out = append(out, fmt.Sprintf("%s: accent %q is not one of %s", it.ID, it.Accent, strings.Join(Accents, ", ")))
		}
		for _, a := range it.Apps {
			if a.IfRunning != "" && a.IfRunning != "nothing" && a.IfRunning != "move" {
				out = append(out, fmt.Sprintf("%s: ifRunning %q must be nothing or move", it.ID, a.IfRunning))
			}
		}
		n := strings.ToLower(SanitizeName(it.Name))
		switch {
		case n == "":
			out = append(out, fmt.Sprintf("%s: empty name", it.ID))
		case seen[n] != "":
			out = append(out, fmt.Sprintf("%s: same Hyprland name as %s", it.ID, seen[n]))
		default:
			seen[n] = it.ID
		}
	}
	return out
}

// Store reads and writes specials.workspaces through the catalog store
// (validated, atomic, hot-reloaded by the shell).
type Store struct {
	Config *catalog.Store
}

// Load returns the configured specials.
func (s Store) Load() ([]Special, error) {
	v, _, err := s.Config.Get(Key)
	if err != nil {
		return nil, err
	}
	data, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	var list []Special
	if err := json.Unmarshal(data, &list); err != nil {
		return nil, fmt.Errorf("%s: %w", Key, err)
	}
	for i := range list {
		list[i] = Normalize(list[i])
	}
	return list, nil
}

// Save validates and writes the list.
func (s Store) Save(list []Special) error {
	if p := Problems(list); len(p) > 0 {
		return fmt.Errorf("invalid special workspaces: %s", strings.Join(p, "; "))
	}
	if list == nil {
		list = []Special{}
	}
	data, err := json.Marshal(list)
	if err != nil {
		return err
	}
	var v any
	if err := json.Unmarshal(data, &v); err != nil {
		return err
	}
	_, err = s.Config.Set(Key, v, false)
	return err
}

// Add appends a special named name (unique) and returns it.
func Add(list []Special, name, icon, accent string) ([]Special, Special, error) {
	if SanitizeName(name) == "" {
		return list, Special{}, fmt.Errorf("invalid name %q", name)
	}
	if _, ok := Find(list, SanitizeName(name)); ok {
		return list, Special{}, fmt.Errorf("a special workspace named %q already exists", name)
	}
	it := Normalize(Special{ID: NewID(list, name), Name: strings.TrimSpace(name), Icon: icon, Accent: accent})
	return append(list, it), it, nil
}

// ParseCombo reads "SUPER+ALT+S" / "SUPER + ALT + S" / "SUPER ALT, S".
func ParseCombo(s string) (Combo, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return Combo{Modifiers: []string{}}, nil
	}
	parts := strings.FieldsFunc(s, func(r rune) bool { return r == '+' || r == ',' || r == ' ' || r == '\t' })
	if len(parts) == 0 {
		return Combo{}, fmt.Errorf("invalid key combination %q", s)
	}
	key := parts[len(parts)-1]
	mods := []string{}
	for _, m := range parts[:len(parts)-1] {
		mod, ok := normalizeMod(m)
		if !ok {
			return Combo{}, fmt.Errorf("unknown modifier %q in %q", m, s)
		}
		mods = append(mods, mod)
	}
	if utf8.RuneCountInString(key) == 1 {
		key = strings.ToUpper(key)
	}
	return Combo{Modifiers: mods, Key: key}, nil
}

func normalizeMod(m string) (string, bool) {
	switch strings.ToUpper(strings.TrimSpace(m)) {
	case "SUPER", "WIN", "MOD4", "LOGO", "META":
		return "SUPER", true
	case "ALT", "MOD1":
		return "ALT", true
	case "CTRL", "CONTROL":
		return "CTRL", true
	case "SHIFT":
		return "SHIFT", true
	}
	return "", false
}

// ComboID is a canonical form for comparisons ("ALT+SUPER+S").
func ComboID(c Combo) string {
	if c.Key == "" {
		return ""
	}
	seen := map[string]bool{}
	for _, m := range c.Modifiers {
		if n, ok := normalizeMod(m); ok {
			seen[n] = true
		}
	}
	var mods []string
	for _, m := range []string{"ALT", "CTRL", "SHIFT", "SUPER"} {
		if seen[m] {
			mods = append(mods, m)
		}
	}
	return strings.Join(append(mods, strings.ToUpper(c.Key)), "+")
}

// FormatCombo prints a combo as "SUPER+ALT+S".
func FormatCombo(c Combo) string {
	if c.Key == "" {
		return ""
	}
	return strings.Join(append(append([]string{}, c.Modifiers...), c.Key), "+")
}
