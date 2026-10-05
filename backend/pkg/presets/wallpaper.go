package presets

import (
	"encoding/json"
	"fmt"
	"os"

	"yozakura/backend/pkg/catalog"
)

// WallpaperDomain is the preset file (wallpaper.json) holding the palette
// generator settings the shell keeps in <cache>/wallpapers.json. Only
// WallpaperKeys are carried: the wallpaper itself stays the user's.
const WallpaperDomain = "wallpaper"

// WallpaperKeys are the wallpapers.json keys a preset carries.
var WallpaperKeys = []string{"matugenScheme"}

// DefaultScheme is the shell's matugen scheme when none is set.
const DefaultScheme = "scheme-tonal-spot"

// MatugenSchemes are the schemes the shell can generate a palette with.
var MatugenSchemes = []string{
	"scheme-content",
	"scheme-expressive",
	"scheme-fidelity",
	"scheme-fruit-salad",
	"scheme-monochrome",
	"scheme-neutral",
	"scheme-rainbow",
	"scheme-tonal-spot",
}

func validateWallpaper(doc any) []catalog.Problem {
	m, ok := doc.(map[string]any)
	if !ok {
		return []catalog.Problem{{Key: WallpaperDomain, Message: "must be an object"}}
	}
	var out []catalog.Problem
	for k, v := range m {
		if k != "matugenScheme" {
			out = append(out, catalog.Problem{Key: WallpaperDomain + "." + k, Message: "not carried by presets; ignored"})
			continue
		}
		s, _ := v.(string)
		if !contains(MatugenSchemes, s) {
			out = append(out, catalog.Problem{Key: "wallpaper.matugenScheme", Message: fmt.Sprintf("must be one of %v", MatugenSchemes)})
		}
	}
	return out
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

// readWallpapers reads <cache>/wallpapers.json as an ordered object.
func (m *Manager) readWallpapers() (*catalog.Object, error) {
	data, err := os.ReadFile(m.WallpaperFile)
	if os.IsNotExist(err) {
		return catalog.NewObject(), nil
	}
	if err != nil {
		return nil, err
	}
	v, err := catalog.DecodeOrdered(data)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", m.WallpaperFile, err)
	}
	o, ok := v.(*catalog.Object)
	if !ok {
		return nil, fmt.Errorf("%s: not an object", m.WallpaperFile)
	}
	return o, nil
}

// currentWallpaper is the live wallpaper.json document, nil when unknown.
func (m *Manager) currentWallpaper() []byte {
	if m.WallpaperFile == "" {
		return nil
	}
	o, err := m.readWallpapers()
	if err != nil {
		return nil
	}
	out := map[string]any{}
	for _, k := range WallpaperKeys {
		if v, ok := o.Get(k); ok {
			out[k] = catalog.Plain(v)
		}
	}
	if s, _ := out["matugenScheme"].(string); s == "" {
		out["matugenScheme"] = DefaultScheme
	}
	data, _ := json.MarshalIndent(out, "", "  ")
	return append(data, '\n')
}

// applyWallpaper merges a preset's wallpaper.json into the live
// wallpapers.json; a valid scheme also drops an active static color preset
// (like choosing a scheme in the settings). The shell watches the file.
func (m *Manager) applyWallpaper(doc any) error {
	if m.WallpaperFile == "" {
		return nil
	}
	src, _ := doc.(map[string]any)
	scheme, _ := src["matugenScheme"].(string)
	if !contains(MatugenSchemes, scheme) {
		return nil
	}
	o, err := m.readWallpapers()
	if err != nil {
		return err
	}
	if cur, _ := o.Get("matugenScheme"); cur == scheme {
		return nil
	}
	o.Set("matugenScheme", scheme)
	o.Set("activeColorPreset", "")
	data, err := json.MarshalIndent(o, "", "    ")
	if err != nil {
		return err
	}
	return writeAtomic(m.WallpaperFile, append(data, '\n'))
}

// colorPreset is the live static color preset ("" when none or unknown).
func (m *Manager) colorPreset() string {
	if m.WallpaperFile == "" {
		return ""
	}
	o, err := m.readWallpapers()
	if err != nil {
		return ""
	}
	v, _ := o.Get("activeColorPreset")
	name, _ := v.(string)
	return name
}

// restoreColorPreset makes a static color preset active again (after a
// reverted session whose scheme dropped it); "" leaves the file alone.
func (m *Manager) restoreColorPreset(name string) error {
	if m.WallpaperFile == "" || name == "" || m.colorPreset() == name {
		return nil
	}
	o, err := m.readWallpapers()
	if err != nil {
		return err
	}
	o.Set("activeColorPreset", name)
	data, err := json.MarshalIndent(o, "", "    ")
	if err != nil {
		return err
	}
	return writeAtomic(m.WallpaperFile, append(data, '\n'))
}
