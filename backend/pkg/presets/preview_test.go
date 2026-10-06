package presets

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPreviewChainsAndReverts(t *testing.T) {
	m := newManager(t)
	writeWallpapers(t, m, `{"matugenScheme": "scheme-content"}`)
	_, _, err := m.Apply("Yozakura Default")
	assert.NoError(t, err)
	before, _ := m.Documents(Current)

	_, err = m.Preview("Neon Tokyo")
	assert.NoError(t, err)
	assert.Equal(t, "Neon Tokyo", m.Active())
	// A second hover previews on top: the backup stays the original look.
	s, err := m.Preview("Yozakura Night")
	assert.NoError(t, err)
	assert.Equal(t, "Yozakura Default", s.PrevActive)
	assert.Equal(t, "Yozakura Night", s.Preset)

	_, _, err = m.Begin(TrySession, "Neon Tokyo")
	assert.ErrorContains(t, err, "in progress")

	reverted, err := m.Revert()
	assert.NoError(t, err)
	assert.True(t, reverted)
	after, _ := m.Documents(Current)
	assert.Empty(t, m.compareDocs(before, after, nil), "revert restores every file")
	assert.Equal(t, "Yozakura Default", m.Active())

	// Nothing to revert is not an error (Esc without a hover).
	reverted, err = m.Revert()
	assert.NoError(t, err)
	assert.False(t, reverted)
}

func TestApplyDuringPreviewKeeps(t *testing.T) {
	m := newManager(t)
	_, _, err := m.Apply("Yozakura Default")
	assert.NoError(t, err)
	_, err = m.Preview("Neon Tokyo")
	assert.NoError(t, err)

	_, _, err = m.Apply("Neon Tokyo")
	assert.NoError(t, err)
	s, _ := m.Session(PreviewSession)
	assert.Nil(t, s, "a real apply ends the preview")
	assert.Equal(t, "Neon Tokyo", m.Active())
	reverted, err := m.Revert()
	assert.NoError(t, err)
	assert.False(t, reverted)
	assert.Equal(t, "Neon Tokyo", m.Active())
}

func TestPreviewRefusedDuringTrial(t *testing.T) {
	m := newManager(t)
	_, _, err := m.Begin(TrySession, "Neon Tokyo")
	assert.NoError(t, err)
	_, err = m.Preview("Yozakura Night")
	assert.ErrorContains(t, err, "in progress")
	_, err = m.Preview("No Such Preset")
	assert.Error(t, err)
}
