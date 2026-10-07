package presets

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// writeTree writes files (path relative to root -> content).
func writeTree(t *testing.T, root string, files map[string]string) {
	t.Helper()
	for rel, body := range files {
		p := filepath.Join(root, rel)
		assert.NoError(t, os.MkdirAll(filepath.Dir(p), 0o755))
		assert.NoError(t, os.WriteFile(p, []byte(body), 0o644))
	}
}

// fixtureManager is a manager over a built-in dir with sets and parts:
// set "Dusk" = layout Top + style Soft + palette Plum (+ a bar override),
// set "Old" is a legacy self-contained set.
func fixtureManager(t *testing.T) *Manager {
	t.Helper()
	m := newManager(t)
	m.OfficialDir = filepath.Join(t.TempDir(), "presets")
	writeTree(t, m.OfficialDir, map[string]string{
		"layouts/Top/info.json":         `{"description": "Bar on top"}`,
		"layouts/Top/bar.json":          `{"position": "top", "compact": true}`,
		"layouts/Top/notch.json":        `{"style": "island"}`,
		"layouts/Side/bar.json":         `{"position": "left"}`,
		"styles/Soft/theme.json":        `{"roundness": 12, "glass": {"enabled": true, "amount": 0.4}}`,
		"styles/Soft/compositor.json":   `{"gapsIn": 6}`,
		"styles/Hard/theme.json":        `{"roundness": 0}`,
		"palettes/Plum/wallpaper.json":  `{"matugenScheme": "scheme-content", "activeColorPreset": "Plum"}`,
		"palettes/Plum/theme.json":      `{"lightMode": false, "oledMode": false}`,
		"palettes/Paper/wallpaper.json": `{"matugenScheme": "scheme-neutral", "activeColorPreset": "Paper"}`,
		"palettes/Paper/theme.json":     `{"lightMode": true}`,
		"sets/Dusk/info.json":           `{"author": "Yozakura", "description": "Dusk"}`,
		"sets/Dusk/set.json":            `{"layout": "top", "style": "Soft", "palette": "Plum"}`,
		"sets/Dusk/bar.json":            `{"compact": false}`,
		"sets/Dusk/theme.json":          `{"glass": {"amount": 0.7}}`,
		"sets/Old/theme.json":           `{"roundness": 3}`,
		"layouts/README.json":           `{}`,
	})
	return m
}

func decodeMap(t *testing.T, data []byte) map[string]any {
	t.Helper()
	var v map[string]any
	assert.NoError(t, json.Unmarshal(data, &v))
	return v
}

func TestComposeOrderAndDeepMerge(t *testing.T) {
	m := fixtureManager(t)
	files, err := Compose(m.OfficialDir, filepath.Join(m.OfficialDir, "sets", "Dusk"))
	assert.NoError(t, err)
	assert.Equal(t, []string{"bar", "compositor", "notch", "theme", "wallpaper"}, sortedKeys(files))
	assert.Equal(t, map[string]any{"position": "top", "compact": false}, decodeMap(t, files["bar"]), "set overrides win")
	theme := decodeMap(t, files["theme"])
	assert.Equal(t, map[string]any{"enabled": true, "amount": 0.7}, theme["glass"], "objects merge recursively")
	assert.Equal(t, 12.0, theme["roundness"])
	assert.Equal(t, false, theme["lightMode"], "the palette adds its keys")
	assert.Equal(t, `{"style": "island"}`, string(files["notch"]), "single-source files stay byte for byte")

	legacy, err := Compose(m.OfficialDir, filepath.Join(m.OfficialDir, "sets", "Old"))
	assert.NoError(t, err)
	assert.Equal(t, map[string][]byte{"theme": []byte(`{"roundness": 3}`)}, legacy)

	writeTree(t, m.OfficialDir, map[string]string{"sets/Broken/set.json": `{"layout": "Nope"}`})
	_, err = Compose(m.OfficialDir, filepath.Join(m.OfficialDir, "sets", "Broken"))
	assert.ErrorContains(t, err, `no layout "Nope"`)

	merged, err := MergeJSON([]byte(`{"a": [1, 2], "b": {"c": 1, "d": 2}}`), []byte(`{"a": [3], "b": {"d": 5}}`))
	assert.NoError(t, err)
	assert.JSONEq(t, `{"a": [3], "b": {"c": 1, "d": 5}}`, string(merged), "arrays replace")
}

// Every built-in set composes (its parts exist) and the default is one.
func TestBuiltinSetsCompose(t *testing.T) {
	m := newManager(t)
	entries, err := os.ReadDir(m.officialSets())
	assert.NoError(t, err)
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		files, err := Compose(m.OfficialDir, filepath.Join(m.officialSets(), e.Name()))
		assert.NoError(t, err, e.Name())
		assert.NotEmpty(t, files, e.Name())
	}
	_, err = m.Find(DefaultPreset)
	assert.NoError(t, err)
}

func TestSetsListApplyAndMarkers(t *testing.T) {
	m := fixtureManager(t)
	list := m.List()
	names := []string{}
	for _, p := range list {
		names = append(names, p.Name)
	}
	assert.Equal(t, []string{"Dusk", "Old"}, names, "sets/ only (Broken has no parts here)")
	dusk, err := m.Find("dusk")
	assert.NoError(t, err)
	assert.Equal(t, []string{"Top", "Soft", "Plum"}, []string{dusk.Layout, dusk.Style, dusk.Palette}, "part names resolved")
	assert.Contains(t, dusk.Domains, "notch")
	assert.NotContains(t, dusk.Domains, "set")
	assert.NotEmpty(t, dusk.Hash)

	_, problems, err := m.Apply("Dusk")
	assert.NoError(t, err)
	assert.Empty(t, problems)
	assert.Equal(t, SetRef{Layout: "Top", Style: "Soft", Palette: "Plum"}, m.CurrentParts(), "markers come from set.json")
	w := readScheme(t, m)
	assert.Equal(t, "scheme-content", w["matugenScheme"])
	assert.Equal(t, "Plum", w["activeColorPreset"], "the palette's static color preset is set after the scheme")
	bar, _ := os.ReadFile(m.Store.File("bar"))
	assert.Equal(t, false, decodeMap(t, bar)["compact"])

	_, _, err = m.Apply("Old")
	assert.NoError(t, err)
	assert.Equal(t, SetRef{}, m.CurrentParts(), "a legacy set clears the markers")
	_, err = os.Stat(m.PartsFile())
	assert.True(t, os.IsNotExist(err))
}

func TestLegacyOfficialFallback(t *testing.T) {
	m := newManager(t)
	m.OfficialDir = t.TempDir()
	writeTree(t, m.OfficialDir, map[string]string{
		"Yozakura Default/theme.json": `{"roundness": 4}`,
		"Night/bar.json":              `{"position": "bottom"}`,
	})
	list := m.List()
	assert.Len(t, list, 2)
	assert.True(t, list[0].Official)
	assert.Equal(t, "", list[0].Layout, "legacy sets name no parts")
	_, _, err := m.Apply("Night")
	assert.NoError(t, err)
	assert.Equal(t, "Night", m.Active())

	// A marker naming the former default resolves to the new one.
	writeTree(t, m.OfficialDir, map[string]string{"sets/Yozakura/theme.json": `{"roundness": 9}`})
	assert.NoError(t, os.WriteFile(m.ActiveFile(), []byte("Yozakura Default\n"), 0o644))
	assert.Equal(t, DefaultPreset, m.Active())
	assert.Equal(t, "Yozakura", DefaultPreset)
}

func TestPartsListApplyPreviewRevert(t *testing.T) {
	m := fixtureManager(t)
	writeLive(t, m, "theme", `{"roundness": 5, "font": "Mono", "lightMode": true}`)
	writeLive(t, m, "bar", `{"position": "bottom", "compact": false}`)
	writeWallpapers(t, m, `{"currentWall": "/w/a.jpg", "matugenScheme": "scheme-fidelity", "activeColorPreset": "Nord"}`)

	r, err := m.AllParts()
	assert.NoError(t, err)
	assert.Len(t, r.Layouts, 2)
	assert.Len(t, r.Styles, 2)
	assert.Len(t, r.Palettes, 2)
	top := r.Layouts[1]
	assert.Equal(t, "Top", top.Name)
	assert.Equal(t, "Bar on top", top.Description)
	assert.Equal(t, []string{"bar", "notch"}, top.Domains)
	assert.Equal(t, "top", top.Look["bar.position"], "the look is the live config with the part merged in")
	assert.Equal(t, 5.0, top.Look["theme.roundness"])
	assert.Equal(t, "Plum", r.Palettes[1].Look["wallpaper.activeColorPreset"])
	_, err = m.Parts("nope")
	assert.ErrorContains(t, err, "unknown part kind")

	// Applying a style only touches the style's keys.
	_, _, err = m.ApplyPart(PartStyle, "soft")
	assert.NoError(t, err)
	theme, _ := os.ReadFile(m.Store.File("theme"))
	got := decodeMap(t, theme)
	assert.Equal(t, 12.0, got["roundness"])
	assert.Equal(t, "Mono", got["font"], "keys the part does not set stay")
	assert.Equal(t, true, got["lightMode"])
	bar, _ := os.ReadFile(m.Store.File("bar"))
	assert.Equal(t, `{"position": "bottom", "compact": false}`, string(bar), "other domains untouched")
	assert.Equal(t, "Soft", m.CurrentParts().Style)
	assert.Equal(t, "Nord", readScheme(t, m)["activeColorPreset"])

	// Preview a palette, then revert: everything comes back.
	s, err := m.PreviewPart(PartPalette, "Paper")
	assert.NoError(t, err)
	assert.Equal(t, PartPalette, s.Part)
	assert.Equal(t, "Paper", readScheme(t, m)["activeColorPreset"])
	assert.Equal(t, "Paper", m.CurrentParts().Palette)
	_, err = m.PreviewPart(PartLayout, "Side")
	assert.NoError(t, err, "parts chain in one preview")
	reverted, err := m.Revert()
	assert.NoError(t, err)
	assert.True(t, reverted)
	w := readScheme(t, m)
	assert.Equal(t, "Nord", w["activeColorPreset"])
	assert.Equal(t, "scheme-fidelity", w["matugenScheme"])
	assert.Equal(t, SetRef{Style: "Soft"}, m.CurrentParts())
	bar, _ = os.ReadFile(m.Store.File("bar"))
	assert.Equal(t, "bottom", decodeMap(t, bar)["position"])
	theme, _ = os.ReadFile(m.Store.File("theme"))
	assert.Equal(t, true, decodeMap(t, theme)["lightMode"])

	// Applying a part the active set does not name leaves no set active.
	_, _, err = m.Apply("Dusk")
	assert.NoError(t, err)
	_, _, err = m.ApplyPart(PartStyle, "Soft")
	assert.NoError(t, err)
	assert.Equal(t, "Dusk", m.Active(), "same part: the set still describes the look")
	_, _, err = m.ApplyPart(PartStyle, "Hard")
	assert.NoError(t, err)
	assert.Equal(t, "", m.Active())
}

func TestSaveWritesSetWhenPartsKnown(t *testing.T) {
	m := fixtureManager(t)
	_, _, err := m.Apply("Dusk")
	assert.NoError(t, err)
	p, err := m.Save("Mine", nil, false)
	assert.NoError(t, err)
	ref, ok, err := ReadSetRef(p.Path)
	assert.NoError(t, err)
	assert.True(t, ok)
	assert.Equal(t, SetRef{Layout: "Top", Style: "Soft", Palette: "Plum"}, ref)
	assert.Equal(t, "Soft", p.Style)
	diffs, err := m.Compare("Mine", Current)
	assert.NoError(t, err)
	assert.Empty(t, diffs, "the composed set is the live look")

	only, err := m.Save("Only theme", []string{"theme"}, false)
	assert.NoError(t, err)
	_, ok, _ = ReadSetRef(only.Path)
	assert.False(t, ok, "a partial save is self-contained")

	dup, err := m.Duplicate("Dusk", "")
	assert.NoError(t, err)
	assert.Equal(t, "Dusk copy", dup.Name)
	assert.Equal(t, "Plum", dup.Palette, "a duplicate keeps naming its parts")

	_, _, err = m.Apply("Old")
	assert.NoError(t, err)
	p, err = m.Save("Flat", nil, false)
	assert.NoError(t, err)
	_, ok, _ = ReadSetRef(p.Path)
	assert.False(t, ok, "unknown parts: no set.json")
}

func TestExportImportComposedSet(t *testing.T) {
	m := fixtureManager(t)
	file := filepath.Join(t.TempDir(), "dusk.json")
	b, err := m.Export("Dusk", file)
	assert.NoError(t, err)
	assert.Equal(t, []string{"bar", "compositor", "notch", "theme", "wallpaper"}, b.DomainNames())
	imp, problems, err := m.Import(file, "Dusk 2", false)
	assert.NoError(t, err)
	assert.Empty(t, problems)
	diffs, err := m.Compare("Dusk", imp.Name)
	assert.NoError(t, err)
	assert.Empty(t, diffs)
}
