package yozakura

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/presets"
)

func TestPresetExportImportRoundTrip(t *testing.T) {
	d, _, _ := newDeps(t)
	assert.False(t, callTool(t, d, "config_set", `{"key":"theme.roundness","value":7}`).IsError)
	assert.False(t, callTool(t, d, "preset_save", `{"name":"Mine"}`).IsError)

	file := filepath.Join(t.TempDir(), "mine.json")
	args, _ := json.Marshal(map[string]any{"name": "Mine", "file": file})
	res := callTool(t, d, "preset_export", string(args))
	assert.False(t, res.IsError, res.Text())
	assert.Contains(t, res.Text(), `"theme"`)

	args, _ = json.Marshal(map[string]any{"file": file, "name": "Shared"})
	res = callTool(t, d, "preset_import", string(args))
	assert.False(t, res.IsError, res.Text())
	assert.Contains(t, res.Text(), `"imported": "Shared"`)
	res = callTool(t, d, "preset_diff", `{"a":"Mine","b":"Shared"}`)
	assert.Contains(t, res.Text(), `"count": 0`)
	assert.True(t, callTool(t, d, "preset_import", string(args)).IsError, "exists without force")
}

func TestPresetImportRejectsInvalidBundle(t *testing.T) {
	d, _, _ := newDeps(t)
	file := filepath.Join(t.TempDir(), "bad.json")
	bundle := map[string]any{"format": presets.BundleFormat, "version": 1, "name": "Bad",
		"domains": map[string]any{"theme": map[string]any{"roundness": "very"}, "bar": map[string]any{}}}
	data, _ := json.Marshal(bundle)
	assert.NoError(t, os.WriteFile(file, data, 0o644))
	args, _ := json.Marshal(map[string]any{"file": file})
	res := callTool(t, d, "preset_import", string(args))
	assert.True(t, res.IsError)
	_, err := os.Stat(filepath.Join(d.PresetsDir, "Bad"))
	assert.True(t, os.IsNotExist(err), "a failed import changes nothing")

	bundle["domains"] = map[string]any{"nope": map[string]any{}}
	data, _ = json.Marshal(bundle)
	assert.NoError(t, os.WriteFile(file, data, 0o644))
	assert.True(t, callTool(t, d, "preset_import", string(args)).IsError, "unknown domain")
}

func TestPresetPartsTools(t *testing.T) {
	d, _, _ := newDeps(t)
	res := callTool(t, d, "preset_parts", `{}`)
	assert.False(t, res.IsError, res.Text())
	for _, k := range []string{`"layouts"`, `"styles"`, `"palettes"`, `"current"`} {
		assert.Contains(t, res.Text(), k)
	}
	assert.True(t, callTool(t, d, "preset_apply_part", `{"kind":"palette","name":"No Such Palette"}`).IsError)
}
