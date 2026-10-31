package presets

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func changedKeys(st Status) []string {
	out := []string{}
	for _, d := range st.Changes {
		out = append(out, d.Key)
	}
	return out
}

func TestStatusNoActivePreset(t *testing.T) {
	m := newManager(t)
	st, err := m.Status()
	assert.NoError(t, err)
	assert.Equal(t, "", st.Active)
	assert.Equal(t, 0, st.Changed)
	_, _, err = m.SaveCurrent()
	assert.Error(t, err)
}

func TestSaveCurrentUpdatesUserPresetAndUndo(t *testing.T) {
	m := newManager(t)
	seedNewerAndOld(t, m)
	mustApply(t, m, "Newer")
	st, err := m.Status()
	assert.NoError(t, err)
	assert.Equal(t, "Newer", st.Active)
	assert.True(t, st.Owned)
	assert.Equal(t, 0, st.Changed, "just applied: %v", changedKeys(st))

	setLive(t, m, "theme", "roundness", 7)
	st, _ = m.Status()
	assert.Equal(t, []string{"theme.roundness"}, changedKeys(st))

	p, undo, err := m.SaveCurrent()
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	assert.NotEmpty(t, undo)
	docs, _ := m.Documents(p.Name)
	assert.EqualValues(t, 7, docs["theme"].(map[string]any)["roundness"])
	st, _ = m.Status()
	assert.Equal(t, 0, st.Changed)
	// The saved value is the preset's now: an older snapshot resets it.
	assert.EqualValues(t, 7, m.readApplied().Values["theme"]["roundness"])

	_, err = m.UndoSave(undo)
	assert.NoError(t, err)
	docs, _ = m.Documents("Newer")
	assert.EqualValues(t, 3, docs["theme"].(map[string]any)["roundness"])
	st, _ = m.Status()
	assert.Equal(t, []string{"theme.roundness"}, changedKeys(st))
	_, err = m.UndoSave(undo)
	assert.Error(t, err, "a version is undone once")
}

func TestStatusOfficialSaveAsNew(t *testing.T) {
	m := newManager(t)
	mustApply(t, m, "Yozakura Night")
	st, err := m.Status()
	assert.NoError(t, err)
	assert.True(t, st.Official)
	assert.False(t, st.Owned)
	assert.Equal(t, 0, st.Changed, "official set applied: %v", changedKeys(st))
	setLive(t, m, "theme", "roundness", 13)
	st, _ = m.Status()
	assert.Contains(t, changedKeys(st), "theme.roundness")

	_, _, err = m.SaveCurrent()
	assert.ErrorContains(t, err, "read-only")
	p, err := m.SaveCurrentAs("Yozakura Night (my)")
	if !assert.NoError(t, err) {
		t.FailNow()
	}
	assert.Equal(t, p.Name, m.Active())
	st, _ = m.Status()
	assert.True(t, st.Owned)
	assert.Equal(t, 0, st.Changed, "%v", changedKeys(st))
	for _, d := range []string{"keyboard", "displays", "general", "ai"} {
		_, err := os.Stat(filepath.Join(p.Path, d+".json"))
		assert.True(t, os.IsNotExist(err), "%s saved into a preset", d)
	}
}

func TestPartialStatusAndSaveOnlyNamedKeys(t *testing.T) {
	m := newManager(t)
	writeUserPreset(t, m, "Mix", `{"author":"User","authorUrl":"","partial":true}`,
		map[string]string{"theme": `{"font":"Mix Sans"}`})
	mustApply(t, m, "Mix")
	setLive(t, m, "theme", "roundness", 11) // not named by the mix
	st, _ := m.Status()
	assert.Equal(t, 0, st.Changed, "%v", changedKeys(st))
	setLive(t, m, "theme", "font", "Mine Sans")
	st, _ = m.Status()
	assert.Equal(t, []string{"theme.font"}, changedKeys(st))
	_, _, err := m.SaveCurrent()
	assert.NoError(t, err)
	data, _ := os.ReadFile(filepath.Join(m.UserDir, "Mix", "theme.json"))
	assert.JSONEq(t, `{"font":"Mine Sans"}`, string(data))
}

func TestSaveCurrentRefusedDuringSession(t *testing.T) {
	m := newManager(t)
	seedNewerAndOld(t, m)
	mustApply(t, m, "Newer")
	_, _, err := m.Begin(TrySession, "Old")
	assert.NoError(t, err)
	st, _ := m.Status()
	assert.Equal(t, TrySession, st.Session)
	_, _, err = m.SaveCurrent()
	assert.ErrorContains(t, err, "in progress")
}
