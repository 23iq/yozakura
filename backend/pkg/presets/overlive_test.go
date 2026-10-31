package presets

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// Applying a partial source (an official set, a mix, a part) never resets
// the settings it does not name.

func seedLive(t *testing.T, m *Manager, domain, doc string) {
	t.Helper()
	if !assert.NoError(t, os.MkdirAll(filepath.Dir(m.Store.File(domain)), 0o755)) {
		t.FailNow()
	}
	if !assert.NoError(t, os.WriteFile(m.Store.File(domain), []byte(doc), 0o644)) {
		t.FailNow()
	}
}

func liveDoc(t *testing.T, m *Manager, domain string) map[string]any {
	t.Helper()
	data, err := os.ReadFile(m.Store.File(domain))
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	var doc map[string]any
	if !assert.NoError(t, json.Unmarshal(data, &doc)) {
		t.FailNow()
	}
	return doc
}

func TestApplyOfficialSetKeepsDesktopWidgets(t *testing.T) {
	m := newManager(t)
	seedLive(t, m, "desktop", `{"widgets":[{"id":"n","type":"note","x":0,"y":0,"w":0.2,"h":0.2,"options":{"text":"mine"}}],"widgetGrid":12,"widgetsEnabled":false}`)
	_, _, err := m.Apply("Yozakura Night")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	doc := liveDoc(t, m, "desktop")
	assert.Len(t, doc["widgets"], 1, "widgets survive")
	assert.EqualValues(t, 12, doc["widgetGrid"])
	assert.Equal(t, false, doc["widgetsEnabled"])
}

func TestDesktopWidgetsNeverTravel(t *testing.T) {
	m := newManager(t)
	seedLive(t, m, "desktop", `{"enabled":true,"widgets":[{"id":"n","type":"note","options":{"text":"secret note"}}]}`)
	p, err := m.Save("Mine", []string{"desktop"}, false)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	data, err := os.ReadFile(filepath.Join(p.Path, "desktop.json"))
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	assert.NotContains(t, string(data), "secret note")
	assert.NotContains(t, string(data), "widgets")
}

func TestMixWindowsOnlyKeepsTheme(t *testing.T) {
	m := newManager(t)
	seedLive(t, m, "theme", `{"font":"Mine Sans","roundness":9,"animDuration":111}`)
	_, err := m.Mix("Motion", map[string]string{"windows": "Yozakura Night"}, "", false)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	_, _, err = m.Apply("Motion")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	doc := liveDoc(t, m, "theme")
	assert.Equal(t, "Mine Sans", doc["font"])
	assert.EqualValues(t, 9, doc["roundness"])
	assert.NotEqual(t, 111, doc["animDuration"], "the windows aspect applied")
}

func TestMixColorsOnlyLeavesMotion(t *testing.T) {
	m := newManager(t)
	_, err := m.Mix("Tints", map[string]string{"colors": "Yozakura Night"}, "", false)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	docs, err := m.Documents("Tints")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	theme, _ := docs["theme"].(map[string]any)
	assert.NotContains(t, theme, "animDuration")
	assert.NotContains(t, theme, "paletteTransitionDuration")
}

func TestPaletteKeepsLightMode(t *testing.T) {
	m := newManager(t)
	seedLive(t, m, "theme", `{"lightMode":true,"oledMode":false,"roundness":4}`)
	_, _, err := m.ApplyPart(PartPalette, "Plum")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	doc := liveDoc(t, m, "theme")
	assert.Equal(t, true, doc["lightMode"], "a palette follows the user's mode")
	assert.EqualValues(t, 4, doc["roundness"])
}

func TestPalettesPinNoMode(t *testing.T) {
	entries, err := os.ReadDir(filepath.Join(repoRoot, "assets", "presets", "palettes"))
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	for _, e := range entries {
		data, err := os.ReadFile(filepath.Join(repoRoot, "assets", "presets", "palettes", e.Name(), "theme.json"))
		if err != nil {
			continue
		}
		var doc map[string]any
		if !assert.NoError(t, json.Unmarshal(data, &doc)) {
			t.FailNow()
		}
		for _, k := range paletteModeKeys {
			assert.NotContains(t, doc, k, "palette %s pins theme.%s", e.Name(), k)
		}
	}
}

func TestComposeDropsPaletteModes(t *testing.T) {
	root := t.TempDir()
	put := func(rel, body string) {
		if !assert.NoError(t, os.MkdirAll(filepath.Dir(filepath.Join(root, rel)), 0o755)) {
			t.FailNow()
		}
		if !assert.NoError(t, os.WriteFile(filepath.Join(root, rel), []byte(body), 0o644)) {
			t.FailNow()
		}
	}
	put("palettes/P/theme.json", `{"lightMode":true,"oledMode":true,"roundness":2}`)
	put("sets/S/set.json", `{"palette":"P"}`)
	files, err := Compose(root, filepath.Join(root, "sets", "S"))
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	assert.JSONEq(t, `{"roundness":2}`, string(files["theme"]))
}

func TestEditSessionSavesEditsOutsidePresetDomains(t *testing.T) {
	m := newManager(t)
	seedLive(t, m, "desktop", `{"depthClock":false}`)
	seedLive(t, m, "theme", `{"roundness":5}`)
	_, err := m.Save("Mine", []string{"theme"}, false)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	_, _, err = m.Begin(EditSession, "Mine")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	seedLive(t, m, "desktop", `{"depthClock":true}`)
	_, err = m.End(EditSession, true, true)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	docs, err := m.Documents("Mine")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	desktop, _ := docs["desktop"].(map[string]any)
	assert.Equal(t, true, desktop["depthClock"], "the desktop edit was stored")
}

// writeUserPreset writes a user preset by hand, as an older version left it.
func writeUserPreset(t *testing.T, m *Manager, name, infoJSON string, files map[string]string) {
	t.Helper()
	dir := filepath.Join(m.UserDir, name)
	if !assert.NoError(t, os.MkdirAll(dir, 0o755)) {
		t.FailNow()
	}
	files["info"] = infoJSON
	for d, body := range files {
		if !assert.NoError(t, os.WriteFile(filepath.Join(dir, d+".json"), []byte(body), 0o644)) {
			t.FailNow()
		}
	}
}

// Mixes (flagged, or legacy ones recognised by their description) and
// copies of official sets keep applying over the live config.
func TestApplyPartialUserPresetKeepsLive(t *testing.T) {
	for _, inf := range []string{
		`{"author":"User","authorUrl":"","partial":true}`,
		`{"author":"User","authorUrl":"","description":"Mixed from colors: Kaze"}`,
	} {
		m := newManager(t)
		seedLive(t, m, "theme", `{"font":"Mine Sans","roundness":9}`)
		writeUserPreset(t, m, "Mix", inf, map[string]string{"theme": `{"font":"Mix Sans"}`})
		_, _, err := m.Apply("Mix")
		if !assert.NoError(t, err) {
			t.FailNow()
		}
		doc := liveDoc(t, m, "theme")
		assert.Equal(t, "Mix Sans", doc["font"], inf)
		assert.EqualValues(t, 9, doc["roundness"], inf)
	}
}

func TestDuplicateOfficialStaysPartial(t *testing.T) {
	m := newManager(t)
	p, err := m.Duplicate("Yozakura Night", "Night copy")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	inf, _ := readInfo(p.Path)
	assert.True(t, inf.Partial)
	_, err = m.Mix("Tints", map[string]string{"colors": "Yozakura Night"}, "", false)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	tints, _ := m.Find("Tints")
	inf, _ = readInfo(tints.Path)
	assert.True(t, inf.Partial)
}
