package termlook

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
)

// Roles are the palette roles a preset may reference. They follow
// Yozakura's Material roles (colors.json) so prompts follow the theme.
var Roles = []string{"primary", "onPrimary", "secondary", "onSecondary", "tertiary", "onTertiary",
	"surface", "surfaceHigh", "onSurface", "outline", "error", "onError", "success"}

// Palette maps a role to a "#rrggbb" color.
type Palette map[string]string

// roleSources lists the colors.json keys tried for each role, in order.
// colors.json names the "on" colors "over*"; plain Material "on*" names are
// accepted too. success is optional and falls back to tertiary.
var roleSources = map[string][]string{
	"primary":     {"primary"},
	"onPrimary":   {"overPrimary", "onPrimary"},
	"secondary":   {"secondary"},
	"onSecondary": {"overSecondary", "onSecondary"},
	"tertiary":    {"tertiary"},
	"onTertiary":  {"overTertiary", "onTertiary"},
	"surface":     {"surface"},
	"surfaceHigh": {"surfaceContainerHigh", "surfaceHigh"},
	"onSurface":   {"overSurface", "onSurface"},
	"outline":     {"outline"},
	"error":       {"error"},
	"onError":     {"overError", "onError"},
	"success":     {"green"},
}

var hexRe = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

// PaletteFromColorsJSON maps Yozakura's colors.json to the prompt roles.
func PaletteFromColorsJSON(b []byte) (Palette, error) {
	var raw map[string]any
	if err := json.Unmarshal(b, &raw); err != nil {
		return nil, fmt.Errorf("colors.json: %w", err)
	}
	pal := Palette{}
	for _, role := range Roles {
		for _, key := range roleSources[role] {
			s, ok := raw[key].(string)
			if !ok {
				continue
			}
			if !hexRe.MatchString(s) {
				return nil, fmt.Errorf("colors.json: %s=%q is not #rrggbb", key, s)
			}
			pal[role] = strings.ToLower(s)
			break
		}
	}
	if pal["success"] == "" && pal["tertiary"] != "" {
		pal["success"] = pal["tertiary"]
	}
	for _, role := range Roles {
		if pal[role] == "" {
			return nil, fmt.Errorf("colors.json: no color for role %s (tried %s)", role,
				strings.Join(roleSources[role], ", "))
		}
	}
	return pal, nil
}

// paletteKey is the name a role gets inside an engine palette. Starship
// lower-cases style tokens, so camelCase names would not resolve there.
func paletteKey(role string) string {
	var b strings.Builder
	for _, r := range role {
		if r >= 'A' && r <= 'Z' {
			b.WriteByte('_')
			r += 'a' - 'A'
		}
		b.WriteRune(r)
	}
	return b.String()
}
