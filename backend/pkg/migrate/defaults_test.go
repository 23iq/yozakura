package migrate

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/paths"
)

func shiftPaths(t *testing.T) paths.Paths {
	dir := t.TempDir()
	p := paths.Paths{ConfigDir: filepath.Join(dir, "config"), DataDir: filepath.Join(dir, "data")}
	assert.NoError(t, os.MkdirAll(filepath.Join(p.ConfigDir, "config"), 0o755))
	return p
}

func TestDefaultsShiftRewritesOnlyOldDefaults(t *testing.T) {
	p := shiftPaths(t)
	theme := `{"roundness": 4, "shape": {"corners": "round", "popupCorners": ""}, "signatures": {"brushHighlight": false, "petals": true}}`
	assert.NoError(t, os.WriteFile(p.Config("theme"), []byte(theme), 0o644))
	assert.NoError(t, os.WriteFile(p.Config("compositor"), []byte(`{"motionProfile": "snappy"}`), 0o644))

	changed, err := EnsureDefaultsShift(p)
	assert.NoError(t, err)
	assert.Equal(t, []string{"theme.shape.popupCorners", "theme.signatures.brushHighlight"}, changed)
	got, _ := os.ReadFile(p.Config("theme"))
	assert.JSONEq(t, `{"roundness": 4, "shape": {"corners": "round", "popupCorners": "cut"}, "signatures": {"brushHighlight": true, "petals": true}}`, string(got))
	comp, _ := os.ReadFile(p.Config("compositor"))
	assert.Equal(t, `{"motionProfile": "snappy"}`, string(comp), "a value the user chose is kept, the file untouched")

	// It runs once: a later old-default value is the user's choice.
	assert.NoError(t, os.WriteFile(p.Config("compositor"), []byte(`{"motionProfile": "smooth"}`), 0o644))
	changed, err = EnsureDefaultsShift(p)
	assert.NoError(t, err)
	assert.Empty(t, changed)
	comp, _ = os.ReadFile(p.Config("compositor"))
	assert.Equal(t, `{"motionProfile": "smooth"}`, string(comp))
}

func TestDefaultsShiftMotionAndMissingFiles(t *testing.T) {
	p := shiftPaths(t)
	assert.NoError(t, os.WriteFile(p.Config("compositor"), []byte(`{"gapsIn": 4, "motionProfile": "smooth"}`), 0o644))
	changed, err := EnsureDefaultsShift(p)
	assert.NoError(t, err)
	assert.Equal(t, []string{"compositor.motionProfile"}, changed)
	comp, _ := os.ReadFile(p.Config("compositor"))
	assert.JSONEq(t, `{"gapsIn": 4, "motionProfile": "sakura"}`, string(comp))
	_, err = os.Stat(p.Config("theme"))
	assert.True(t, os.IsNotExist(err), "a missing file is not created")
	_, err = os.Stat(filepath.Join(p.DataDir, DefaultsShiftMarker))
	assert.NoError(t, err, "recorded")
}

func TestDefaultsShiftSkipsMalformed(t *testing.T) {
	p := shiftPaths(t)
	assert.NoError(t, os.WriteFile(p.Config("theme"), []byte(`{not json`), 0o644))
	changed, err := EnsureDefaultsShift(p)
	assert.NoError(t, err)
	assert.Empty(t, changed)
	got, _ := os.ReadFile(p.Config("theme"))
	assert.Equal(t, `{not json`, string(got))
}

func TestDefaultsShiftEmptyGridsBecomeDefaultGrids(t *testing.T) {
	p := shiftPaths(t)
	assert.NoError(t, os.WriteFile(p.Config("bar"), []byte(`{"moduleOptions": {"clock": {"panel": {"cells": []}}}}`), 0o644))
	assert.NoError(t, os.WriteFile(p.Config("layout"), []byte(`{"dashboard": {"grid": {"cols": 4, "cells": [{"widget": "player", "x": 0, "y": 0, "w": 1, "h": 1}]}}}`), 0o644))

	changed, err := EnsureDefaultsShift(p)
	assert.NoError(t, err)
	assert.Equal(t, []string{"bar.moduleOptions.clock.panel.cells"}, changed)
	bar, _ := os.ReadFile(p.Config("bar"))
	assert.Contains(t, string(bar), `"widget": "weather"`)
	assert.Contains(t, string(bar), `"widget": "worldClocks"`)
	layout, _ := os.ReadFile(p.Config("layout"))
	assert.NotContains(t, string(layout), "quickControls", "a placed grid is the user's")
}
