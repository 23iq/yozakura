package termlook

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Greeting looks: fastfetch configs bundled in assets/terminal/fastfetch
// (presets.json lists them). Each <id>.jsonc is a plain fastfetch config
// whose colour names are mapped to the shell palette when the greeting is
// written, so it follows theme changes like the prompt does.

// FetchOwn is the preset that runs plain fastfetch with the user's own
// config (~/.config/fastfetch), which is never read or written here.
const FetchOwn = "own"

// Logo choices (terminal.fastfetchLogo).
const (
	LogoDistro = "distro" // fastfetch's own detection
	LogoSakura = "sakura" // the bundled text logo (logos/sakura.txt)
	LogoCustom = "custom" // terminal.fastfetchLogoPath
	LogoNone   = "none"
)

// FetchLogos lists the logo choices.
var FetchLogos = []string{LogoDistro, LogoSakura, LogoCustom, LogoNone}

// FetchPreset is one greeting look.
type FetchPreset struct {
	ID          string `json:"id"`
	Name        string `json:"name"`        // proper noun; "" for own (translated in the UI)
	Description string `json:"description"` // i18n key term.fetch.preset.<id>.desc
	Logo        bool   `json:"logo"`        // the logo choice applies
	Own         bool   `json:"own,omitempty"`
	// Config is the parsed <id>.jsonc (nil for own).
	Config map[string]any `json:"-"`
}

// LoadFetchPresets reads presets.json and the configs it names, in the
// listed order.
func LoadFetchPresets(dir string) ([]FetchPreset, error) {
	data, err := os.ReadFile(filepath.Join(dir, "presets.json"))
	if err != nil {
		return nil, err
	}
	var idx struct {
		Presets []FetchPreset `json:"presets"`
	}
	if err := json.Unmarshal(data, &idx); err != nil {
		return nil, fmt.Errorf("presets.json: %w", err)
	}
	seen := map[string]bool{}
	for i := range idx.Presets {
		p := &idx.Presets[i]
		if !idRe.MatchString(p.ID) || seen[p.ID] {
			return nil, fmt.Errorf("presets.json: invalid or duplicate id %q", p.ID)
		}
		seen[p.ID] = true
		if p.Description != "term.fetch.preset."+p.ID+".desc" {
			return nil, fmt.Errorf("presets.json: %s: description must be term.fetch.preset.%s.desc", p.ID, p.ID)
		}
		if p.Own != (p.ID == FetchOwn) {
			return nil, fmt.Errorf("presets.json: only %q is the user's own config", FetchOwn)
		}
		if p.Own {
			continue
		}
		b, err := os.ReadFile(filepath.Join(dir, p.ID+".jsonc"))
		if err != nil {
			return nil, err
		}
		if err := json.Unmarshal(b, &p.Config); err != nil {
			return nil, fmt.Errorf("%s.jsonc: %w", p.ID, err)
		}
		if _, ok := p.Config["modules"].([]any); !ok {
			return nil, fmt.Errorf("%s.jsonc: no modules", p.ID)
		}
	}
	if !seen[FetchOwn] {
		return nil, fmt.Errorf("presets.json: the %q preset is missing", FetchOwn)
	}
	return idx.Presets, nil
}

// FindFetchPreset returns the preset with id.
func FindFetchPreset(ps []FetchPreset, id string) (FetchPreset, bool) {
	for _, p := range ps {
		if p.ID == id {
			return p, true
		}
	}
	return FetchPreset{}, false
}

// fetchColorRoles maps the colour names presets use to palette roles.
var fetchColorRoles = map[string]string{
	"magenta": "primary", "blue": "secondary", "cyan": "tertiary", "yellow": "tertiary",
	"green": "success", "red": "error", "white": "onSurface", "light_black": "outline",
}

// fetchStyles are fastfetch's colour prefixes ("bold_magenta").
var fetchStyles = map[string]bool{"bold": true, "bright": true, "dim": true, "italic": true,
	"underline": true, "blink": true, "inverse": true, "hidden": true, "strike": true, "light": true}

// fetchColor maps a fastfetch colour spec to the palette: "bold_magenta" ->
// "bold_#rrggbb". Specs that name no mapped colour are returned unchanged.
func fetchColor(spec string, pal Palette) string {
	parts := strings.Split(spec, "_")
	for i := range parts {
		name := strings.Join(parts[i:], "_")
		role, ok := fetchColorRoles[name]
		if !ok && strings.HasPrefix(name, "light_") {
			role, ok = fetchColorRoles[strings.TrimPrefix(name, "light_")]
		}
		if !ok {
			if fetchStyles[parts[i]] {
				continue
			}
			return spec
		}
		hex := pal[role]
		if !hexRe.MatchString(hex) {
			return spec
		}
		prefix := ""
		for _, p := range parts[:i] {
			if p != "light" { // the mapped colour replaces the bright variant
				prefix += p + "_"
			}
		}
		return prefix + strings.ToLower(hex)
	}
	return spec
}

var formatColor = regexp.MustCompile(`\{#([a-z_]+)\}`)

// mapFetchColors walks a fastfetch config and maps every colour: values of
// keys named like colours (color objects, keyColor, outputColor) and the
// {#name} markers of format strings and keys.
func mapFetchColors(v any, key, parent string, pal Palette) any {
	switch t := v.(type) {
	case map[string]any:
		out := make(map[string]any, len(t))
		for k, val := range t {
			out[k] = mapFetchColors(val, k, key, pal)
		}
		return out
	case []any:
		out := make([]any, len(t))
		for i, val := range t {
			out[i] = mapFetchColors(val, "", key, pal)
		}
		return out
	case string:
		if isColorKey(key) || isColorKey(parent) {
			return fetchColor(t, pal)
		}
		return formatColor.ReplaceAllStringFunc(t, func(m string) string {
			name := m[2 : len(m)-1]
			if mapped := fetchColor(name, pal); mapped != name {
				return "{#" + mapped + "}"
			}
			return m
		})
	}
	return v
}

func isColorKey(k string) bool { return strings.Contains(strings.ToLower(k), "color") }

// FetchLogo is the logo part of a generated config.
type FetchLogo struct {
	Kind   string // distro | file | file-raw | kitty-direct | none
	Source string // file path (file kinds)
	Width  int    // kitty-direct: cells
	Height int
}

// RenderFetch returns the fastfetch config of preset p with the palette
// colours and logo. The logo object of the preset keeps its padding; its
// type and source come from logo.
func RenderFetch(p FetchPreset, pal Palette, logo FetchLogo) ([]byte, error) {
	if p.Own || p.Config == nil {
		return nil, fmt.Errorf("preset %q has no config", p.ID)
	}
	cfg, _ := mapFetchColors(p.Config, "", "", pal).(map[string]any)
	if p.Logo {
		obj, _ := cfg["logo"].(map[string]any)
		if obj == nil {
			obj = map[string]any{}
		}
		delete(obj, "type")
		delete(obj, "source")
		delete(obj, "color")
		delete(obj, "width")
		delete(obj, "height")
		switch logo.Kind {
		case "", LogoDistro:
		case LogoNone:
			obj = map[string]any{"type": "none"}
		case "file", "file-raw":
			obj["type"], obj["source"] = logo.Kind, logo.Source
			colors := map[string]any{}
			for i, role := range []string{"primary", "tertiary", "secondary", "onSurface", "outline"} {
				if hexRe.MatchString(pal[role]) { // no palette yet: the terminal's colours
					colors[fmt.Sprint(i+1)] = strings.ToLower(pal[role])
				}
			}
			obj["color"] = colors
		case "kitty-direct":
			// Width and height are both required: without them fastfetch
			// clears the screen and queries the cursor position.
			obj["type"], obj["source"] = logo.Kind, logo.Source
			obj["width"], obj["height"] = logo.Width, logo.Height
		default:
			return nil, fmt.Errorf("unknown logo kind %q", logo.Kind)
		}
		cfg["logo"] = obj
	}
	out, err := json.MarshalIndent(cfg, "", "    ")
	if err != nil {
		return nil, err
	}
	return append(out, '\n'), nil
}
