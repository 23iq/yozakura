package presets

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

// An official set applied after another one resets what the earlier set
// wrote and the new one does not name (Emaki's panorama wallpaper must not
// stick under Kotoba), unless the user changed it since.

func TestSetAfterSetResetsLeftovers(t *testing.T) {
	m := newManager(t)
	defs := m.Cat.DomainDefault("desktop")
	mustApply(t, m, "Emaki")
	assert.Equal(t, "panorama", liveDoc(t, m, "desktop")["wallpaperMode"])
	sum := mustApply(t, m, "Kotoba")
	doc := liveDoc(t, m, "desktop")
	assert.EqualValues(t, defs["wallpaperMode"], doc["wallpaperMode"])
	assert.EqualValues(t, defs["depthLayering"], doc["depthLayering"])
	assert.Contains(t, sum.Reset, "desktop.wallpaperMode")
	assert.Contains(t, sum.Reset, "desktop.depthLayering")
}

func TestSetAfterSetKeepsUserChange(t *testing.T) {
	m := newManager(t)
	mustApply(t, m, "Emaki")
	setLive(t, m, "desktop", "depthLayering", false)
	setLive(t, m, "desktop", "wallpaperMode", "tile")
	sum := mustApply(t, m, "Kotoba")
	doc := liveDoc(t, m, "desktop")
	assert.Equal(t, "tile", doc["wallpaperMode"], "the user's value survives")
	assert.Contains(t, sum.Kept, "desktop.wallpaperMode")
}

func TestPartialUserPresetAfterSetMerges(t *testing.T) {
	m := newManager(t)
	mustApply(t, m, "Emaki")
	writeUserPreset(t, m, "Fonts", `{"author":"User","authorUrl":"","partial":true}`,
		map[string]string{"theme": `{"font":"Other Sans"}`})
	mustApply(t, m, "Fonts")
	assert.Equal(t, "panorama", liveDoc(t, m, "desktop")["wallpaperMode"], "a partial preset only merges")
}
