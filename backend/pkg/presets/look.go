package presets

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
)

// LookKeys are the values a preset thumbnail (the settings preset studio's
// miniature of the shell) is drawn from, resolved against the defaults.
var LookKeys = []string{
	"bar.position", "bar.layout.style", "bar.frameEnabled", "bar.frameThickness", "bar.containBar", "bar.compact",
	"bar.panels",
	"notch.style", "notch.align", "notch.position", "notch.keepHidden",
	"dock.enabled", "dock.theme", "dock.position", "dock.height", "dock.iconSize",
	"theme.lightMode", "theme.oledMode", "theme.roundness", "theme.font", "theme.enableCorners",
	"theme.glass.enabled", "theme.glass.amount", "theme.animDuration",
	"compositor.gapsIn", "compositor.gapsOut", "compositor.borderSize", "compositor.rounding",
	"compositor.syncRoundness", "compositor.activeBorderColor", "compositor.inactiveBorderColor",
	"compositor.shadowEnabled",
	"desktop.depthClock", "desktop.depthClockStyle", "desktop.depthClockPosition",
	"workspaces.numeralStyle", "workspaces.shown",
	"lockscreen.position",
	"wallpaper.matugenScheme", "wallpaper.activeColorPreset",
}

// LookOf resolves LookKeys in a set of documents (missing = default).
func (m *Manager) LookOf(docs map[string]any) map[string]any {
	out := map[string]any{}
	defaults := map[string]any{}
	for _, key := range LookKeys {
		parts := strings.Split(key, ".")
		if v, ok := lookup(docs[parts[0]], parts[1:]); ok && v != nil {
			out[key] = v
			continue
		}
		if key == "wallpaper.matugenScheme" {
			out[key] = DefaultScheme
			continue
		}
		if key == "wallpaper."+colorPresetKey {
			out[key] = ""
			continue
		}
		if _, ok := defaults[parts[0]]; !ok {
			defaults[parts[0]] = m.Cat.DomainDefault(parts[0])
		}
		if v, ok := lookup(defaults[parts[0]], parts[1:]); ok {
			out[key] = v
		}
	}
	return out
}

func lookup(doc any, path []string) (any, bool) {
	for _, p := range path {
		m, ok := doc.(map[string]any)
		if !ok {
			return nil, false
		}
		doc, ok = m[p]
		if !ok {
			return nil, false
		}
	}
	return doc, true
}

// TagsOf derives the gallery tags of a look: bar style(s), theme mode
// (light/dark/oled), "frame" and non-top bar edges ("bar-left", ...).
// With bar.panels the styles and edges come from the panels.
func TagsOf(look map[string]any) []string {
	tags := []string{}
	styles, edges := panelTags(look["bar.panels"])
	if len(styles) == 0 {
		if s, _ := look["bar.layout.style"].(string); s != "" {
			styles = []string{s}
		}
		if p, _ := look["bar.position"].(string); p != "" && p != "top" {
			edges = []string{p}
		}
	}
	tags = append(tags, styles...)
	light, _ := look["theme.lightMode"].(bool)
	oled, _ := look["theme.oledMode"].(bool)
	switch {
	case light:
		tags = append(tags, "light")
	case oled:
		tags = append(tags, "oled")
	default:
		tags = append(tags, "dark")
	}
	if f, _ := look["bar.frameEnabled"].(bool); f {
		tags = append(tags, "frame")
	}
	for _, e := range edges {
		tags = append(tags, "bar-"+e)
	}
	return tags
}

// panelTags lists the distinct styles and non-top edges of enabled panels.
func panelTags(v any) (styles, edges []string) {
	list, _ := v.([]any)
	seen := map[string]bool{}
	for _, item := range list {
		p, _ := item.(map[string]any)
		if p == nil || p["enabled"] == false {
			continue
		}
		if s, _ := p["style"].(string); s != "" && !seen["s:"+s] {
			seen["s:"+s] = true
			styles = append(styles, s)
		}
		if e, _ := p["edge"].(string); e != "" && e != "top" && !seen["e:"+e] {
			seen["e:"+e] = true
			edges = append(edges, e)
		}
	}
	return styles, edges
}

// hashFiles fingerprints a preset's composed files (thumbnail cache key).
func hashFiles(files map[string][]byte) string {
	h := sha256.New()
	for _, d := range sortedKeys(files) {
		h.Write([]byte(d + "\x00"))
		h.Write(files[d])
		h.Write([]byte{0})
	}
	return hex.EncodeToString(h.Sum(nil))[:16]
}
