package termlook

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Samples: what a greeting look prints, for the preview while fastfetch is
// not installed. assets/terminal/fastfetch/samples/<id>.ans is real
// fastfetch output (tools/render/fetchsample.go) of SampleConfig with
// SamplePalette: fixed, neutral values (user@yozakura, no details of the
// machine it was made on) in marker colours that FetchSample swaps for the
// current palette.

// sampleValues is the default key and the text of each module in a sample.
var sampleValues = map[string][2]string{
	"os": {"OS", "Arch Linux"}, "host": {"Host", "Framework Laptop 13"}, "kernel": {"Kernel", "6.12.8-arch1-1"},
	"uptime": {"Uptime", "3h 12m"}, "packages": {"Packages", "1024 (pacman)"}, "shell": {"Shell", "fish 4.0.2"},
	"display": {"Display", "2256x1504 @ 60 Hz"}, "de": {"DE", "Hyprland"}, "wm": {"WM", "Hyprland (Wayland)"},
	"theme": {"Theme", "adw-gtk3-dark"}, "icons": {"Icons", "Papirus-Dark"}, "font": {"Font", "Inter (11pt)"},
	"cursor": {"Cursor", "Bibata-Modern-Ice (24px)"}, "terminal": {"Terminal", "kitty 0.39.1"},
	"terminalfont": {"Terminal Font", "JetBrains Mono (11pt)"}, "cpu": {"CPU", "AMD Ryzen 7 7840U (16) @ 5.13 GHz"},
	"gpu": {"GPU", "AMD Radeon 780M"}, "memory": {"Memory", "6.21 GiB / 30.6 GiB (20%)"},
	"swap": {"Swap", "0 B / 8.00 GiB (0%)"}, "disk": {"Disk (/)", "212.4 GiB / 931.5 GiB (23%) - btrfs"},
	"battery": {"Battery", "87% [Discharging]"}, "locale": {"Locale", "en_US.UTF-8"},
}

// sampleVars are the format variables of a sample per module; a variable
// not listed prints the module's sample text.
var sampleVars = map[string]map[string]string{
	"os":       {"name": "Arch Linux", "pretty-name": "Arch Linux", "kernel-release": "6.12.8-arch1-1"},
	"kernel":   {"release": "6.12.8-arch1-1"},
	"uptime":   {"days": "", "hours": "3", "minutes": "12"},
	"shell":    {"pretty-name": "fish", "process-name": "fish", "version": "4.0.2"},
	"wm":       {"pretty-name": "Hyprland", "process-name": "Hyprland"},
	"terminal": {"pretty-name": "kitty", "process-name": "kitty", "version": "0.39.1"},
	"cpu":      {"name": "AMD Ryzen 7 7840U"},
	"memory":   {"used": "6.21 GiB", "total": "30.6 GiB", "percentage": "20%"},
}

var (
	sampleCond = regexp.MustCompile(`\{\?([a-z][a-z0-9-]*)\}(.*?)\{\?\}`)
	sampleVar  = regexp.MustCompile(`\{([a-z][a-z0-9-]*)\}`)
)

// sampleFormat fills a module's format with sample variables ({?x}...{?}
// blocks only when x is not empty); colour markers stay.
func sampleFormat(typ, format string) string {
	vars := sampleVars[typ]
	value := func(name string) string {
		if v, ok := vars[name]; ok {
			return v
		}
		return sampleValues[typ][1]
	}
	format = sampleCond.ReplaceAllStringFunc(format, func(m string) string {
		sub := sampleCond.FindStringSubmatch(m)
		if value(sub[1]) == "" {
			return ""
		}
		return sub[2]
	})
	return sampleVar.ReplaceAllStringFunc(format, func(m string) string { return value(m[1 : len(m)-1]) })
}

// sampleTitle builds the title of a sample from its format: the user and
// host fields become the sample names in the title colour.
func sampleTitle(format, color string) string {
	if format == "" {
		format = "{user-name-colored}{at-symbol-colored}{host-name-colored}"
	}
	c := "{#" + color + "}"
	return strings.NewReplacer("{user-name-colored}", c+"user", "{host-name-colored}", c+"yozakura",
		"{at-symbol-colored}", "{#}@", "{user-name}", "user", "{host-name}", "yozakura").Replace(format)
}

// SampleConfig is preset p with every module printing its sample value.
func SampleConfig(p FetchPreset) (FetchPreset, error) {
	if p.Own || p.Config == nil {
		return p, fmt.Errorf("preset %q has no config", p.ID)
	}
	cfg := deepCopy(p.Config).(map[string]any)
	title := "bold_magenta"
	if d, ok := cfg["display"].(map[string]any); ok {
		if c, ok := d["color"].(map[string]any); ok {
			if t, ok := c["title"].(string); ok {
				title = t
			}
		}
	}
	// Every module becomes a custom one with its key and sample text: the
	// sample never depends on what fastfetch detects where it is made.
	mods, _ := cfg["modules"].([]any)
	for i, m := range mods {
		obj, ok := m.(map[string]any)
		if !ok {
			name, _ := m.(string)
			obj = map[string]any{"type": name}
		}
		typ, _ := obj["type"].(string)
		switch {
		case typ == "title":
			format, _ := obj["format"].(string)
			mods[i] = map[string]any{"type": "custom", "format": sampleTitle(format, title)}
		case typ == "custom" || typ == "break" || typ == "separator":
		case sampleValues[typ][0] != "":
			key, ok := obj["key"].(string)
			if !ok {
				key = sampleValues[typ][0]
			}
			text := sampleValues[typ][1]
			if f, ok := obj["format"].(string); ok {
				text = sampleFormat(typ, f)
			}
			out := map[string]any{"type": "custom", "key": key, "format": text}
			if kc, ok := obj["keyColor"]; ok {
				out["keyColor"] = kc
			}
			mods[i] = out
		default:
			return p, fmt.Errorf("preset %s: no sample value for module %q", p.ID, typ)
		}
	}
	p.Config = cfg
	return p, nil
}

func deepCopy(v any) any {
	switch t := v.(type) {
	case map[string]any:
		out := make(map[string]any, len(t))
		for k, val := range t {
			out[k] = deepCopy(val)
		}
		return out
	case []any:
		out := make([]any, len(t))
		for i, val := range t {
			out[i] = deepCopy(val)
		}
		return out
	}
	return v
}

// SamplePalette gives every role a marker colour (#fe00NN, NN the role's
// index) that no logo or theme uses.
func SamplePalette() Palette {
	pal := Palette{}
	for i, r := range Roles {
		pal[r] = fmt.Sprintf("#fe00%02x", i+1)
	}
	return pal
}

// FetchSample renders the bundled sample of preset id (the sakura sample for
// the user's own look) in the palette.
func FetchSample(dir, id string, pal Palette, table [16]string) ([][]Span, error) {
	if id == FetchOwn {
		id = "sakura"
	}
	if !idRe.MatchString(id) {
		return nil, fmt.Errorf("invalid preset id %q", id)
	}
	data, err := os.ReadFile(filepath.Join(dir, "samples", id+".ans"))
	if err != nil {
		return nil, err
	}
	// without a palette the roles fall back to the terminal's colours
	ansi := map[string]int{"primary": 5, "secondary": 4, "tertiary": 6, "success": 2, "error": 1,
		"onSurface": 15, "outline": 8}
	swap := map[string]string{}
	for role, marker := range SamplePalette() {
		if c := pal[role]; hexRe.MatchString(c) {
			swap[marker] = strings.ToLower(c)
		} else if i, ok := ansi[role]; ok {
			swap[marker] = table[i]
		} else {
			swap[marker] = ""
		}
	}
	lines := RenderScreen(string(data), table)
	for _, line := range lines {
		for i := range line {
			if c, ok := swap[line[i].FG]; ok {
				line[i].FG = c
			}
			if c, ok := swap[line[i].BG]; ok {
				line[i].BG = c
			}
		}
	}
	return lines, nil
}
