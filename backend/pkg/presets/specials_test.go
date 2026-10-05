package presets

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// Special workspaces are global like binds.json: saving, exporting,
// importing, mixing, trying and applying presets never carry or touch
// specials.json (catalog.LocalDomains).
func TestPresetsNeverTouchSpecials(t *testing.T) {
	m := newManager(t)
	live := `{"enabled": true, "workspaces": [{"id": "telegram", "name": "Telegram", "toggle": {"modifiers": ["SUPER"], "key": "S"}}]}` + "\n"
	file := m.Store.File("specials")
	must(t, assert.NoError(t, os.MkdirAll(filepath.Dir(file), 0o755)))
	must(t, assert.NoError(t, os.WriteFile(file, []byte(live), 0o644)))
	assert.True(t, Excluded["specials"])

	saved, err := m.Save("Mine", nil, false)
	must(t, assert.NoError(t, err))
	assert.NotContains(t, saved.Domains, "specials")
	assert.NoFileExists(t, filepath.Join(saved.Path, "specials.json"))

	// A preset directory that (by hand) holds a specials.json: ignored.
	must(t, assert.NoError(t, os.WriteFile(filepath.Join(saved.Path, "specials.json"), []byte(`{"workspaces": []}`), 0o644)))
	for _, name := range []string{"Mine", "Yozakura Night", "Neon Tokyo"} {
		_, _, err := m.Apply(name)
		must(t, assert.NoError(t, err))
		got, _ := os.ReadFile(file)
		assert.Equal(t, live, string(got), "applying %s changed specials.json", name)
	}

	bundle := filepath.Join(t.TempDir(), "look.json")
	_, err = m.Export("current", bundle)
	must(t, assert.NoError(t, err))
	b, err := ReadBundle(bundle)
	must(t, assert.NoError(t, err))
	assert.NotContains(t, b.DomainNames(), "specials")

	_, err = m.Mix("Blend", map[string]string{"layout": "Yozakura Night", "colors": "current"}, "", false)
	must(t, assert.NoError(t, err))
	_, _, err = m.Apply("Blend")
	must(t, assert.NoError(t, err))
	got, _ := os.ReadFile(file)
	assert.Equal(t, live, string(got))
}

// must stops the test when an assertion failed.
func must(t *testing.T, ok bool) {
	t.Helper()
	if !ok {
		t.FailNow()
	}
}
