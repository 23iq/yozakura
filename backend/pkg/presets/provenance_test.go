package presets

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// Provenance: applying a whole snapshot resets a key it predates only when
// the live value is still the one an earlier preset wrote; anything the
// user changed (or anything of unknown origin) is kept.

const userInfo = `{"author":"User","authorUrl":""}`

func seedNewerAndOld(t *testing.T, m *Manager) {
	t.Helper()
	writeUserPreset(t, m, "Newer", userInfo,
		map[string]string{"theme": `{"font":"Newer Sans","roundness":3,"language":"glass"}`})
	writeUserPreset(t, m, "Old", userInfo, map[string]string{"theme": `{"font":"Old Sans"}`})
}

func mustApply(t *testing.T, m *Manager, name string) ApplySummary {
	t.Helper()
	_, sum, _, err := m.ApplyReport(name)
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	return sum
}

// setLive changes one first-level key of a live domain file by hand.
func setLive(t *testing.T, m *Manager, domain, key string, v any) {
	t.Helper()
	doc := liveDoc(t, m, domain)
	doc[key] = v
	data, _ := json.Marshal(doc)
	seedLive(t, m, domain, string(data))
}

func TestApplyOldSnapshotAfterNewerRestoresLook(t *testing.T) {
	m := newManager(t)
	defs := m.Cat.DomainDefault("theme")
	seedNewerAndOld(t, m)
	mustApply(t, m, "Newer")
	sum := mustApply(t, m, "Old")
	doc := liveDoc(t, m, "theme")
	assert.Equal(t, "Old Sans", doc["font"])
	assert.EqualValues(t, defs["roundness"], doc["roundness"])
	assert.EqualValues(t, defs["language"], doc["language"])
	assert.Contains(t, sum.Set, "theme.font")
	assert.ElementsMatch(t, []string{"theme.roundness", "theme.language"}, sum.Reset)
	assert.Empty(t, sum.Kept)
}

func TestApplyKeepsUserModifiedKey(t *testing.T) {
	m := newManager(t)
	defs := m.Cat.DomainDefault("theme")
	seedNewerAndOld(t, m)
	mustApply(t, m, "Newer")
	setLive(t, m, "theme", "roundness", 7) // changed by hand after Newer
	sum := mustApply(t, m, "Old")
	doc := liveDoc(t, m, "theme")
	assert.EqualValues(t, 7, doc["roundness"], "the user's value survives")
	assert.EqualValues(t, defs["language"], doc["language"], "untouched leftovers reset")
	assert.Equal(t, []string{"theme.roundness"}, sum.Kept)
	// The kept value stays the user's: a later snapshot keeps it too.
	writeUserPreset(t, m, "Oldest", userInfo, map[string]string{"theme": `{"font":"Oldest Sans"}`})
	mustApply(t, m, "Oldest")
	assert.EqualValues(t, 7, liveDoc(t, m, "theme")["roundness"])
}

func TestApplyWithoutRecordKeepsLive(t *testing.T) {
	m := newManager(t)
	seedLive(t, m, "theme", `{"font":"Newer Sans","roundness":3,"language":"glass"}`)
	writeUserPreset(t, m, "Old", userInfo, map[string]string{"theme": `{"font":"Old Sans"}`})
	sum := mustApply(t, m, "Old")
	doc := liveDoc(t, m, "theme")
	assert.Equal(t, "Old Sans", doc["font"])
	assert.EqualValues(t, 3, doc["roundness"], "unknown provenance is never reset")
	assert.Equal(t, "glass", doc["language"])
	assert.ElementsMatch(t, []string{"theme.roundness", "theme.language"}, sum.Kept)
	assert.Empty(t, sum.Reset)
}

func TestApplyPartialAfterNewerMerges(t *testing.T) {
	m := newManager(t)
	seedNewerAndOld(t, m)
	writeUserPreset(t, m, "Mix", `{"author":"User","authorUrl":"","partial":true}`,
		map[string]string{"theme": `{"font":"Mix Sans"}`})
	mustApply(t, m, "Newer")
	sum := mustApply(t, m, "Mix")
	doc := liveDoc(t, m, "theme")
	assert.Equal(t, "Mix Sans", doc["font"])
	assert.EqualValues(t, 3, doc["roundness"], "a mix keeps what it does not name")
	assert.Equal(t, []string{"theme.font"}, sum.Set)
	assert.Empty(t, sum.Reset)
	// Newer's untouched leftovers are still known as preset values.
	sum = mustApply(t, m, "Old")
	assert.ElementsMatch(t, []string{"theme.roundness", "theme.language"}, sum.Reset)
}

func TestApplyNeverWritesSystemDomains(t *testing.T) {
	m := newManager(t)
	keyboard := `{"layouts":"us,de"}`
	seedLive(t, m, "keyboard", keyboard)
	seedLive(t, m, "displays", `{"x":1}`)
	writeUserPreset(t, m, "Sneaky", userInfo, map[string]string{
		"theme":    `{"font":"Sneaky Sans"}`,
		"keyboard": `{"layouts":"fr"}`,
		"displays": `{"x":2}`,
		"general":  `{"onboardingDone":false}`,
	})
	mustApply(t, m, "Sneaky")
	data, _ := os.ReadFile(m.Store.File("keyboard"))
	assert.JSONEq(t, keyboard, string(data))
	data, _ = os.ReadFile(m.Store.File("displays"))
	assert.JSONEq(t, `{"x":1}`, string(data))
	_, err := os.Stat(m.Store.File("general"))
	assert.True(t, os.IsNotExist(err), "general is never written")
	rec := m.readApplied()
	if assert.NotNil(t, rec) {
		for d := range rec.Values {
			assert.False(t, Excluded[d], "record holds system domain %s", d)
		}
	}
	// Saving never captures them either.
	p, err := m.Save("Snap", nil, false)
	if assert.NoError(t, err) {
		for _, d := range []string{"keyboard", "displays", "general"} {
			_, err := os.Stat(filepath.Join(p.Path, d+".json"))
			assert.True(t, os.IsNotExist(err), "%s saved into a preset", d)
		}
	}
}

func TestSessionRevertRestoresRecord(t *testing.T) {
	m := newManager(t)
	seedNewerAndOld(t, m)
	mustApply(t, m, "Newer")
	_, _, err := m.Begin(TrySession, "Old")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	assert.Equal(t, "Old", m.readApplied().Preset)
	_, err = m.End(TrySession, false, false)
	assert.NoError(t, err)
	rec := m.readApplied()
	if assert.NotNil(t, rec) {
		assert.Equal(t, "Newer", rec.Preset)
		assert.EqualValues(t, 3, rec.Values["theme"]["roundness"])
	}
}
