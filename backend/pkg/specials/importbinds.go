package specials

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"yozakura/backend/pkg/fsutil"
)

// Hand-written special workspace binds in the user's Hyprland config
// (Lua or hyprland.conf syntax) are imported once into specials.json:
// ScanBinds finds them, Merge adds/updates the specials (idempotent: an
// existing special keeps its binds), CommentOut disables the source lines
// behind a marker (keeping a backup), so nothing fires twice.

// Found is one special named in the scanned files with its binds.
type Found struct {
	Name   string
	Toggle Combo
	Send   Combo
	// Lines are the source lines per file (1-based) that bind it.
	Lines map[string][]int
}

// Marker precedes the lines CommentOut disabled.
const Marker = "yozakura: special workspace binds moved to specials.json (see `yozakura special list`)"

var (
	luaToggle  = regexp.MustCompile(`^\s*hl\.bind\(\s*"([^"]+)"\s*,\s*hl\.dsp\.workspace\.toggle_special\(\s*"([^"]+)"\s*\)`)
	luaSend    = regexp.MustCompile(`^\s*hl\.bind\(\s*"([^"]+)"\s*,\s*hl\.dsp\.window\.move\(\s*\{[^}]*workspace\s*=\s*"special:([^"]+)"`)
	confToggle = regexp.MustCompile(`^\s*bind[a-z]*\s*=\s*([^,]*),\s*([^,]+),\s*togglespecialworkspace\s*,\s*([^,#\s]+)`)
	confSend   = regexp.MustCompile(`^\s*bind[a-z]*\s*=\s*([^,]*),\s*([^,]+),\s*movetoworkspace(?:silent)?\s*,\s*special:([^,#\s]+)`)
)

// DefaultFiles are the user's own Hyprland files: every *.lua and *.conf
// directly in <hypr>/custom (the place hand-written binds live).
func DefaultFiles(hyprDir string) []string {
	var out []string
	for _, pat := range []string{"*.lua", "*.conf"} {
		m, _ := filepath.Glob(filepath.Join(hyprDir, "custom", pat))
		out = append(out, m...)
	}
	sort.Strings(out)
	return out
}

// ScanBinds reads files and returns the specials they bind, in order of
// first appearance, plus warnings (unparsable combos).
func ScanBinds(files []string) ([]Found, []string, error) {
	var order []string
	byName := map[string]*Found{}
	var warnings []string
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, nil, err
		}
		for i, line := range strings.Split(string(data), "\n") {
			role, comboText, name := matchLine(line)
			if role == "" {
				continue
			}
			c, err := ParseCombo(comboText)
			if err != nil || c.Key == "" {
				warnings = append(warnings, fmt.Sprintf("%s:%d: cannot read the key combination %q; left as is", file, i+1, comboText))
				continue
			}
			f := byName[name]
			if f == nil {
				f = &Found{Name: name, Lines: map[string][]int{}}
				byName[name] = f
				order = append(order, name)
			}
			if role == "toggle" && f.Toggle.Key == "" {
				f.Toggle = c
			} else if role == "send" && f.Send.Key == "" {
				f.Send = c
			}
			f.Lines[file] = append(f.Lines[file], i+1)
		}
	}
	out := make([]Found, 0, len(order))
	for _, n := range order {
		out = append(out, *byName[n])
	}
	return out, warnings, nil
}

// matchLine returns the role ("toggle"/"send"), combo text and special
// name of a bind line; commented lines never match.
func matchLine(line string) (string, string, string) {
	t := strings.TrimSpace(line)
	if strings.HasPrefix(t, "--") || strings.HasPrefix(t, "#") {
		return "", "", ""
	}
	if m := luaToggle.FindStringSubmatch(line); m != nil {
		return "toggle", m[1], m[2]
	}
	if m := luaSend.FindStringSubmatch(line); m != nil {
		return "send", m[1], m[2]
	}
	if m := confToggle.FindStringSubmatch(line); m != nil {
		return "toggle", strings.TrimSpace(m[1]) + " " + strings.TrimSpace(m[2]), strings.TrimSpace(m[3])
	}
	if m := confSend.FindStringSubmatch(line); m != nil {
		return "send", strings.TrimSpace(m[1]) + " " + strings.TrimSpace(m[2]), strings.TrimSpace(m[3])
	}
	return "", "", ""
}

// knownApps suggests apps for well-known special names: the first
// installed desktop id wins; Fallback (match only, never launched) is
// used when none is installed.
var knownApps = map[string]struct {
	IDs      []string
	Fallback *App
}{
	"telegram": {IDs: []string{"org.telegram.desktop", "telegramdesktop", "org.telegram.desktop.desktop"}, Fallback: &App{ID: "org.telegram.desktop", Name: "Telegram", Icon: "org.telegram.desktop", Match: "org.telegram.desktop"}},
	"discord":  {IDs: []string{"discord", "vesktop", "dev.vencord.Vesktop", "com.discordapp.Discord", "webcord"}},
	"spotify":  {IDs: []string{"spotify", "com.spotify.Client", "spotify-launcher"}},
	"music":    {IDs: []string{"spotify", "com.spotify.Client"}},
	"obsidian": {IDs: []string{"obsidian", "md.obsidian.Obsidian"}},
	"notes":    {IDs: []string{"obsidian", "md.obsidian.Obsidian"}},
}

var knownIcons = map[string]string{
	"telegram": "telegram", "discord": "chatDots", "chat": "chatDots", "music": "musicNotes",
	"spotify": "spotify", "dev": "code", "code": "code", "notes": "notePencil", "obsidian": "notePencil",
	"terminal": "terminal", "term": "terminal", "games": "gamepad", "web": "globe", "browser": "globe",
}

// SuggestApps returns the apps a new special called name starts with.
func SuggestApps(dirs []string, name string) []App {
	key := strings.ToLower(strings.TrimSpace(name))
	if k, ok := knownApps[key]; ok {
		for _, id := range k.IDs {
			if e, ok := Lookup(dirs, id); ok {
				return []App{e.App()}
			}
		}
		if k.Fallback != nil {
			a := *k.Fallback
			a.IfRunning = "nothing"
			return []App{a}
		}
		return []App{}
	}
	if e, ok := FindByName(dirs, name); ok {
		return []App{e.App()}
	}
	return []App{}
}

// IconFor guesses an icon for a special name.
func IconFor(name string) string {
	if icon, ok := knownIcons[strings.ToLower(strings.TrimSpace(name))]; ok {
		return icon
	}
	return "stack"
}

// MergeReport says what Merge did.
type MergeReport struct {
	Added    []string `json:"added"`
	Updated  []string `json:"updated"`
	Kept     []string `json:"kept"`
	Warnings []string `json:"warnings,omitempty"`
}

// Merge adds a special per found name (with suggested apps) or fills the
// missing binds of an existing one. Running it again changes nothing.
func Merge(list []Special, found []Found, dirs []string) ([]Special, MergeReport) {
	var r MergeReport
	out := append([]Special{}, list...)
	for _, f := range found {
		if i, ok := Find(out, f.Name); ok {
			changed := false
			if out[i].Toggle.Empty() && !f.Toggle.Empty() {
				out[i].Toggle, changed = f.Toggle, true
			}
			if out[i].Send.Empty() && !f.Send.Empty() {
				out[i].Send, changed = f.Send, true
			}
			if changed {
				r.Updated = append(r.Updated, out[i].Name)
			} else {
				r.Kept = append(r.Kept, out[i].Name)
			}
			continue
		}
		it := Normalize(Special{
			ID:     NewID(out, f.Name),
			Name:   f.Name,
			Icon:   IconFor(f.Name),
			Accent: "primary",
			Toggle: f.Toggle,
			Send:   f.Send,
			Apps:   SuggestApps(dirs, f.Name),
		})
		if SanitizeName(f.Name) != f.Name {
			r.Warnings = append(r.Warnings, fmt.Sprintf("%q is now special:%s; windows still on special:%s need moving", f.Name, SanitizeName(f.Name), f.Name))
		}
		out = append(out, it)
		r.Added = append(r.Added, it.Name)
	}
	return out, r
}

// CommentOut disables the found bind lines in their files: each gets a
// comment prefix ("-- " Lua, "# " conf) and the first gets Marker above
// it. The original is kept as <file>.bak (or .bak.<unix time> when a
// .bak exists). Returns the backups written.
func CommentOut(found []Found) ([]string, error) {
	lines := map[string]map[int]bool{}
	for _, f := range found {
		for file, ls := range f.Lines {
			if lines[file] == nil {
				lines[file] = map[int]bool{}
			}
			for _, l := range ls {
				lines[file][l] = true
			}
		}
	}
	var files []string
	for f := range lines {
		files = append(files, f)
	}
	sort.Strings(files)
	var backups []string
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return backups, err
		}
		backup := file + ".bak"
		if _, err := os.Stat(backup); err == nil {
			backup = fmt.Sprintf("%s.bak.%d", file, time.Now().Unix())
		}
		if err := os.WriteFile(backup, data, 0o644); err != nil {
			return backups, err
		}
		backups = append(backups, backup)
		prefix := "# "
		if strings.HasSuffix(file, ".lua") {
			prefix = "-- "
		}
		src := strings.Split(string(data), "\n")
		var out []string
		marked := false
		for i, line := range src {
			if lines[file][i+1] {
				if !marked {
					out = append(out, prefix+Marker)
					marked = true
				}
				out = append(out, prefix+line)
				continue
			}
			out = append(out, line)
		}
		if err := fsutil.WriteFile(file, []byte(strings.Join(out, "\n")), 0o644); err != nil {
			return backups, err
		}
	}
	return backups, nil
}

// Conflicts lists the binds.json binds (enabled core and custom) that use
// the same combination as a special's toggle/send bind.
func Conflicts(bindsFile string, list []Special) ([]string, error) {
	data, err := os.ReadFile(bindsFile)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var doc map[string]any
	if err := json.Unmarshal(data, &doc); err != nil {
		return nil, fmt.Errorf("%s: %w", bindsFile, err)
	}
	disabled := map[string]bool{}
	if d, ok := doc["disabled"].([]any); ok {
		for _, p := range d {
			if s, ok := p.(string); ok {
				disabled[s] = true
			}
		}
	}
	taken := map[string][]string{}
	add := func(c Combo, who string) {
		if id := ComboID(c); id != "" {
			taken[id] = append(taken[id], who)
		}
	}
	var walk func(prefix string, v map[string]any)
	walk = func(prefix string, v map[string]any) {
		if _, ok := v["key"]; ok {
			if !disabled[prefix] {
				add(comboOf(v), "core bind "+prefix)
			}
			return
		}
		for k, child := range v {
			if m, ok := child.(map[string]any); ok {
				p := k
				if prefix != "" {
					p = prefix + "." + k
				}
				walk(p, m)
			}
		}
	}
	for root, v := range doc {
		if root == "custom" || root == "disabled" {
			continue
		}
		if m, ok := v.(map[string]any); ok {
			walk("", m)
		}
	}
	if custom, ok := doc["custom"].([]any); ok {
		for _, c := range custom {
			m, _ := c.(map[string]any)
			if m == nil || m["enabled"] == false {
				continue
			}
			name, _ := m["name"].(string)
			keys, _ := m["keys"].([]any)
			for _, k := range keys {
				if km, ok := k.(map[string]any); ok {
					add(comboOf(km), "custom bind \""+name+"\"")
				}
			}
		}
	}
	var out []string
	for _, it := range list {
		for _, b := range []struct {
			role string
			c    Combo
		}{{"toggle", it.Toggle}, {"send", it.Send}} {
			for _, who := range taken[ComboID(b.c)] {
				out = append(out, fmt.Sprintf("%s (%s %s) is also the %s", FormatCombo(b.c), it.Name, b.role, who))
			}
		}
	}
	sort.Strings(out)
	return out, nil
}

func comboOf(m map[string]any) Combo {
	c := Combo{}
	c.Key, _ = m["key"].(string)
	if mods, ok := m["modifiers"].([]any); ok {
		for _, x := range mods {
			if s, ok := x.(string); ok {
				c.Modifiers = append(c.Modifiers, s)
			}
		}
	}
	return c
}
