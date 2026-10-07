package presets

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/fsutil"
)

func writeWallpapers(t *testing.T, m *Manager, body string) {
	t.Helper()
	assert.NoError(t, os.MkdirAll(filepath.Dir(m.WallpaperFile), 0o755))
	assert.NoError(t, os.WriteFile(m.WallpaperFile, []byte(body), 0o644))
}

func readScheme(t *testing.T, m *Manager) map[string]any {
	t.Helper()
	data, err := os.ReadFile(m.WallpaperFile)
	assert.NoError(t, err)
	var v map[string]any
	assert.NoError(t, json.Unmarshal(data, &v))
	return v
}

func TestLooksTagsAndHash(t *testing.T) {
	m := newManager(t)
	list := m.WithLooks(m.List())
	byName := map[string]Preset{}
	for _, p := range list {
		byName[p.Name] = p
		assert.Len(t, p.Hash, 16, p.Name)
		assert.NotEmpty(t, p.Tags, p.Name)
		for _, k := range LookKeys {
			_, ok := p.Look[k]
			assert.True(t, ok, "%s look has %s", p.Name, k)
		}
	}
	for _, p := range list {
		assert.Equal(t, TagsOf(p.Look), p.Tags, p.Name)
	}
	assert.Equal(t, []string{"menubar", "dock", "light", "bar-bottom"}, TagsOf(map[string]any{
		"theme.lightMode": true, "bar.panels": []any{
			map[string]any{"style": "menubar", "edge": "top"},
			map[string]any{"style": "dock", "edge": "bottom"},
			map[string]any{"style": "full", "edge": "left", "enabled": false},
		}}), "every enabled panel style and edge")
	assert.Equal(t, []string{"classic", "oled", "bar-left"}, TagsOf(map[string]any{
		"bar.layout.style": "classic", "bar.position": "left", "theme.oledMode": true}), "without panels")
	assert.NotEqual(t, byName["Neon Tokyo"].Hash, byName["Sumi-e"].Hash)
}

func TestSchemeTravelsWithPresets(t *testing.T) {
	m := newManager(t)
	writeWallpapers(t, m, `{"currentWall": "/w/a.jpg", "matugenScheme": "scheme-fidelity", "activeColorPreset": "Nord"}`)
	writeLive(t, m, "theme", `{"roundness": 3}`)
	saved, err := m.Save("Mine", nil, false)
	assert.NoError(t, err)
	assert.Contains(t, saved.Domains, WallpaperDomain)
	data, _ := os.ReadFile(filepath.Join(saved.Path, "wallpaper.json"))
	assert.JSONEq(t, `{"matugenScheme": "scheme-fidelity", "activeColorPreset": "Nord"}`, string(data), "only the scheme and color preset, never the wallpaper")

	writeWallpapers(t, m, `{"currentWall": "/w/b.jpg", "matugenScheme": "scheme-neutral"}`)
	_, _, err = m.Apply("Mine")
	assert.NoError(t, err)
	w := readScheme(t, m)
	assert.Equal(t, "scheme-fidelity", w["matugenScheme"])
	assert.Equal(t, "/w/b.jpg", w["currentWall"], "the wallpaper stays")

	diffs, err := m.Compare("Mine", Current)
	assert.NoError(t, err)
	assert.Empty(t, diffs)
	file := filepath.Join(t.TempDir(), "b.json")
	_, err = m.Export("Mine", file)
	assert.NoError(t, err)
	imp, problems, err := m.Import(file, "Imported", false)
	assert.NoError(t, err)
	assert.Empty(t, problems)
	assert.Contains(t, imp.Domains, WallpaperDomain)
	assert.NotEmpty(t, validateWallpaper(map[string]any{"matugenScheme": "nope"}))
}

func TestRenameDeleteRestoreDuplicate(t *testing.T) {
	m := newManager(t)
	dup, err := m.Duplicate("Neon Tokyo", "")
	assert.NoError(t, err)
	assert.Equal(t, "Neon Tokyo copy", dup.Name)
	assert.False(t, dup.Official)
	assert.Equal(t, "User", dup.Author)
	assert.Contains(t, dup.Description, "Based on Neon Tokyo")
	diffs, err := m.Compare("Neon Tokyo", dup.Name)
	assert.NoError(t, err)
	assert.Empty(t, diffs)
	again, err := m.Duplicate("Neon Tokyo", "")
	assert.NoError(t, err)
	assert.Equal(t, "Neon Tokyo copy 2", again.Name)

	_, _, err = m.Apply(dup.Name)
	assert.NoError(t, err)
	renamed, err := m.Rename(dup.Name, "Neon Mine")
	assert.NoError(t, err)
	assert.Equal(t, "Neon Mine", m.Active(), "the active marker follows")
	assert.True(t, renamed.Active)
	_, err = m.Rename("Neon Mine", "Sumi-e")
	assert.ErrorContains(t, err, "built-in")
	_, err = m.Rename("Neon Mine", again.Name)
	assert.ErrorContains(t, err, "already exists")
	_, err = m.Rename("Sumi-e", "x")
	assert.ErrorContains(t, err, "read-only")

	_, err = m.Delete("Sumi-e")
	assert.ErrorContains(t, err, "read-only")
	tr, err := m.Delete("Neon Mine")
	assert.NoError(t, err)
	assert.Equal(t, "", m.Active())
	_, err = m.Find("Neon Mine")
	assert.Error(t, err)
	assert.Equal(t, "Neon Mine", m.Trash()[0].Name)
	back, err := m.Restore(tr.ID)
	assert.NoError(t, err)
	assert.Equal(t, "Neon Mine", back.Name)
	assert.Empty(t, m.Trash())
	_, err = m.Restore(tr.ID)
	assert.ErrorContains(t, err, "nothing to restore")

	desc := "my look"
	p, err := m.SetInfo("Neon Mine", &desc, nil)
	assert.NoError(t, err)
	assert.Equal(t, "my look", p.Description)
	assert.Equal(t, "User", p.Author)
}

func TestMixAndInspect(t *testing.T) {
	m := newManager(t)
	mixed, err := m.Mix("Mixed", map[string]string{
		"layout": "Kaze", "colors": "Neon Tokyo", "windows": "CRT", "desktop": "Sumi-e", "lockscreen": Defaults,
	}, "", false)
	assert.NoError(t, err)
	assert.Contains(t, mixed.Description, "layout: Kaze")
	look := m.WithLooks([]Preset{mixed})[0].Look
	assert.Contains(t, TagsOf(look), "bar-left", "layout from Kaze")
	assert.Equal(t, true, look["bar.frameEnabled"], "layout from Kaze")
	assert.Equal(t, true, look["theme.oledMode"], "colors from Neon Tokyo")
	assert.Equal(t, true, look["desktop.depthClock"], "desktop from Sumi-e")

	crt, _ := m.Documents("CRT")
	neon, _ := m.Documents("Neon Tokyo")
	docs, _ := m.Documents("Mixed")
	theme := docs["theme"].(map[string]any)
	assert.Equal(t, neon["theme"].(map[string]any)["roundness"], theme["roundness"])
	if rt, ok := crt["theme"].(map[string]any)["animDuration"]; ok {
		assert.Equal(t, rt, theme["animDuration"], "motion comes with windows")
	} else {
		assert.Equal(t, m.Cat.DomainDefault("theme")["animDuration"], theme["animDuration"])
	}
	assert.Equal(t, crt["compositor"], docs["compositor"])

	_, err = m.Mix("Bad", map[string]string{"nope": "CRT"}, "", false)
	assert.ErrorContains(t, err, "unknown aspect")
	_, err = m.Mix("Sumi-e", map[string]string{"layout": "CRT"}, "", false)
	assert.ErrorContains(t, err, "built-in")

	ins, err := m.Inspect("Mixed", "")
	assert.NoError(t, err)
	assert.Equal(t, Defaults, ins.Against)
	reports := map[string]AspectReport{}
	for _, r := range ins.Aspects {
		reports[r.ID] = r
	}
	assert.Contains(t, reports["layout"].SameAs, "Kaze")
	assert.Contains(t, reports["colors"].SameAs, "Neon Tokyo")
	assert.NotEmpty(t, reports["layout"].Changes)
	assert.Equal(t, "bar", reports["layout"].Category)
	for _, c := range reports["windows"].Changes {
		assert.Equal(t, "windows", AspectOf(c.Key), c.Key)
	}
	found := false
	for _, c := range reports["layout"].Changes {
		if c.Key == "bar.frameEnabled" {
			found = true
			assert.Equal(t, true, c.To)
			assert.Equal(t, false, c.From)
			assert.NotEmpty(t, c.Category, "jump target from the catalog")
		}
	}
	assert.True(t, found)
	assert.Equal(t, "windows", AspectOf("theme.animDuration"))
	assert.Equal(t, "colors", AspectOf("theme.roundness"))
	assert.Equal(t, "colors", AspectOf("wallpaper.matugenScheme"))
	assert.Equal(t, "other", AspectOf("voice.model"))

	vs, err := m.Inspect("Mixed", "Kaze")
	assert.NoError(t, err)
	for _, r := range vs.Aspects {
		if r.ID == "layout" {
			assert.Empty(t, r.Changes)
		}
	}
}

func TestTrySession(t *testing.T) {
	m := newManager(t)
	writeWallpapers(t, m, `{"matugenScheme": "scheme-content"}`)
	_, _, err := m.Apply("Yozakura")
	assert.NoError(t, err)
	before, _ := m.Documents(Current)

	s, _, err := m.Begin(TrySession, "Neon Tokyo")
	assert.NoError(t, err)
	assert.Equal(t, "Yozakura", s.PrevActive)
	assert.Equal(t, "Neon Tokyo", m.Active())
	_, _, err = m.Begin(EditSession, "Neon Tokyo")
	assert.ErrorContains(t, err, "in progress")
	_, err = m.End(TrySession, false, false)
	assert.NoError(t, err)
	after, _ := m.Documents(Current)
	assert.Empty(t, m.compareDocs(before, after, nil), "revert restores every file")
	assert.Equal(t, "Yozakura", m.Active())
	cur, _ := m.Session(TrySession)
	assert.Nil(t, cur)

	_, _, err = m.Begin(TrySession, "Neon Tokyo")
	assert.NoError(t, err)
	_, err = m.End(TrySession, true, false)
	assert.NoError(t, err)
	assert.Equal(t, "Neon Tokyo", m.Active())
	_, err = m.End(TrySession, true, false)
	assert.ErrorContains(t, err, "no preset try")
}

func TestEditSession(t *testing.T) {
	m := newManager(t)
	_, _, err := m.Apply("Yozakura")
	assert.NoError(t, err)
	_, _, err = m.Begin(EditSession, "Sumi-e")
	assert.ErrorContains(t, err, "read-only")
	_, err = m.Duplicate("Sumi-e", "Ink")
	assert.NoError(t, err)

	_, _, err = m.Begin(EditSession, "Ink")
	assert.NoError(t, err)
	_, err = m.Store.Set("theme.roundness", 7.0, false)
	assert.NoError(t, err)
	_, err = m.Delete("Ink")
	assert.ErrorContains(t, err, "being edited")
	_, err = m.Rename("Ink", "Ink 2")
	assert.NoError(t, err)
	s, _ := m.Session(EditSession)
	assert.Equal(t, "Ink 2", s.Preset, "the session follows a rename")

	_, err = m.End(EditSession, false, true)
	assert.NoError(t, err)
	docs, _ := m.Documents("Ink 2")
	assert.Equal(t, 7.0, docs["theme"].(map[string]any)["roundness"], "edits went into the preset")
	assert.Equal(t, "Yozakura", m.Active(), "the previous look is back")
	v, _, _ := m.Store.Get("theme.roundness")
	assert.NotEqual(t, 7.0, v)
}

func TestShadowedUserPreset(t *testing.T) {
	m := newManager(t)
	dst := filepath.Join(m.UserDir, "Sumi-e")
	assert.NoError(t, os.MkdirAll(dst, 0o755))
	assert.NoError(t, os.WriteFile(filepath.Join(dst, "theme.json"), []byte("{}"), 0o644))
	var shadowed *Preset
	for _, p := range m.List() {
		if !p.Official && p.Name == "Sumi-e" {
			shadowed = &p
		}
	}
	if assert.NotNil(t, shadowed) {
		assert.True(t, shadowed.Shadowed)
	}
	p, err := m.Rename("Sumi-e", "My Sumi-e")
	assert.NoError(t, err, "a shadowed user preset can be renamed")
	assert.False(t, p.Official)
	assert.False(t, p.Shadowed)
}

// The settings UI mirrors AspectOf in JS (PresetModel.aspectOf); its node
// test reads this fixture, so the two cannot drift apart.
func TestAspectsFixture(t *testing.T) {
	data, err := os.ReadFile(filepath.Join(repoRoot, "tests", "fixtures", "preset-aspects.json"))
	assert.NoError(t, err)
	want, _ := json.MarshalIndent(Aspects, "", "  ")
	assert.JSONEq(t, string(want), string(data), "run `yozakura preset aspects --json > tests/fixtures/preset-aspects.json`")
}

func TestSessionsAndApplyAreSerialised(t *testing.T) {
	m := newManager(t)
	unlock, err := fsutil.Lock(m.lockFile())
	assert.NoError(t, err)
	done := make(chan error, 1)
	go func() {
		_, _, err := m.Begin(TrySession, "Yozakura Night")
		done <- err
	}()
	select {
	case <-done:
		t.Fatal("a trial began while another preset operation held the lock")
	case <-time.After(100 * time.Millisecond):
	}
	unlock()
	assert.NoError(t, <-done)

	// Two trials racing: exactly one wins, the other sees it in progress.
	_, err = m.End(TrySession, false, false)
	assert.NoError(t, err)
	errs := make(chan error, 2)
	for i := 0; i < 2; i++ {
		go func() {
			_, _, err := m.Begin(TrySession, "Yozakura Night")
			errs <- err
		}()
	}
	e1, e2 := <-errs, <-errs
	assert.True(t, (e1 == nil) != (e2 == nil), "one trial wins: %v / %v", e1, e2)
}

func TestTrialRevertRestoresColorPreset(t *testing.T) {
	m := fixtureManager(t)
	writeTree(t, m.OfficialDir, map[string]string{"sets/Scheme/wallpaper.json": `{"matugenScheme": "scheme-neutral"}`})
	for target, during := range map[string]string{
		"Scheme": "", // a scheme alone drops the static color preset
		"Dusk":   "Plum",
	} {
		writeWallpapers(t, m, `{"currentWall": "/w/a.jpg", "matugenScheme": "scheme-fidelity", "activeColorPreset": "Nord"}`)
		_, _, err := m.Begin(TrySession, target)
		assert.NoError(t, err)
		assert.Equal(t, during, readScheme(t, m)["activeColorPreset"], target)
		_, err = m.End(TrySession, false, false)
		assert.NoError(t, err)
		got := readScheme(t, m)
		assert.Equal(t, "Nord", got["activeColorPreset"], "reverting brings the color preset back")
		assert.Equal(t, "scheme-fidelity", got["matugenScheme"])
		assert.Equal(t, "/w/a.jpg", got["currentWall"])
	}
}
