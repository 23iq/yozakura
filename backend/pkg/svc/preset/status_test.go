package preset

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/presets"
)

func trackerManager(t *testing.T) *presets.Manager {
	t.Helper()
	cat, err := catalog.Load("../../../..")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	dir := t.TempDir()
	return &presets.Manager{
		Cat:         cat,
		Store:       &catalog.Store{Cat: cat, File: func(d string) string { return filepath.Join(dir, "config", d+".json") }},
		UserDir:     filepath.Join(dir, "presets"),
		OfficialDir: filepath.Join("../../../..", "assets", "presets"),
		StateDir:    filepath.Join(dir, "state"),
		DataDir:     filepath.Join(dir, "data"),
	}
}

func writeLive(t *testing.T, m *presets.Manager, domain, doc string) {
	t.Helper()
	assert.NoError(t, os.MkdirAll(filepath.Dir(m.Store.File(domain)), 0o755))
	assert.NoError(t, os.WriteFile(m.Store.File(domain), []byte(doc), 0o644))
}

func userPreset(t *testing.T, m *presets.Manager, name, theme string) {
	t.Helper()
	dir := filepath.Join(m.UserDir, name)
	assert.NoError(t, os.MkdirAll(dir, 0o755))
	assert.NoError(t, os.WriteFile(filepath.Join(dir, "theme.json"), []byte(theme), 0o644))
	assert.NoError(t, os.WriteFile(filepath.Join(dir, "info.json"), []byte(`{"author":"User"}`), 0o644))
}

func TestTrackerPushesOnlyChanges(t *testing.T) {
	m := trackerManager(t)
	userPreset(t, m, "Mine", `{"font":"Mine Sans","roundness":3}`)
	_, _, err := m.Apply("Mine")
	assert.NoError(t, err)
	var pushed []presets.Status
	tr := &tracker{manager: func() (*presets.Manager, error) { return m, nil },
		send: func(d any) { pushed = append(pushed, d.(presets.Status)) }, saveWait: time.Hour}
	st := tr.refresh()
	assert.Equal(t, "Mine", st.Active)
	tr.refresh()
	assert.Len(t, pushed, 1, "an unchanged status is not pushed again")
	writeLive(t, m, "theme", `{"font":"Mine Sans","roundness":9}`)
	tr.refresh()
	if assert.Len(t, pushed, 2) {
		assert.Equal(t, 1, pushed[1].Changed)
	}
}

func TestAutoSaveOnlyWhenOptedInAndOwned(t *testing.T) {
	m := trackerManager(t)
	userPreset(t, m, "Mine", `{"font":"Mine Sans","roundness":3}`)
	_, _, err := m.Apply("Mine")
	assert.NoError(t, err)
	tr := &tracker{manager: func() (*presets.Manager, error) { return m, nil }, saveWait: time.Millisecond}
	writeLive(t, m, "theme", `{"font":"Mine Sans","roundness":9}`)
	assert.False(t, tr.wantsAutoSave(tr.status()), "off by default")

	writeLive(t, m, "general", `{"autoSavePreset":true}`)
	assert.True(t, tr.wantsAutoSave(tr.status()))
	tr.saveNow()
	st := tr.status()
	assert.Equal(t, 0, st.Changed, "saved into the user preset")

	// Never into a built-in preset.
	_, _, err = m.Apply("Yozakura Night")
	assert.NoError(t, err)
	writeLive(t, m, "general", `{"autoSavePreset":true}`)
	var theme map[string]any
	data, _ := os.ReadFile(m.Store.File("theme"))
	assert.NoError(t, json.Unmarshal(data, &theme))
	theme["roundness"] = 21
	data, _ = json.Marshal(theme)
	writeLive(t, m, "theme", string(data))
	st = tr.status()
	assert.True(t, st.Official)
	assert.Greater(t, st.Changed, 0)
	assert.False(t, tr.wantsAutoSave(st))
}
