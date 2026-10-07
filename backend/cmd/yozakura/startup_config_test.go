package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"

	"yozakura/backend/pkg/paths"
)

func writeFiles(t *testing.T, root string, files map[string]string) {
	t.Helper()
	for rel, body := range files {
		p := filepath.Join(root, rel)
		assert.NoError(t, os.MkdirAll(filepath.Dir(p), 0o755))
		assert.NoError(t, os.WriteFile(p, []byte(body), 0o644))
	}
}

func TestSeedConfigNewAndExistingInstall(t *testing.T) {
	official := t.TempDir()
	writeFiles(t, official, map[string]string{
		"layouts/Yozakura/bar.json":      `{"position": "top"}`,
		"styles/Sakura/theme.json":       `{"roundness": 12}`,
		"palettes/Plum/theme.json":       `{"lightMode": false}`,
		"palettes/Plum/wallpaper.json":   `{"matugenScheme": "scheme-content", "activeColorPreset": "Plum"}`,
		"sets/Yozakura/set.json":         `{"layout": "Yozakura", "style": "Sakura", "palette": "Plum"}`,
		"sets/Yozakura/notch.json":       `{"style": "island"}`,
		"sets/Yozakura Night/theme.json": `{}`,
	})
	dir := t.TempDir()
	p := &paths.Paths{ConfigDir: filepath.Join(dir, "cfg"), CacheDir: filepath.Join(dir, "cache")}

	assert.NoError(t, seedConfig(p, official))
	theme, err := os.ReadFile(p.Config("theme"))
	assert.NoError(t, err)
	assert.JSONEq(t, `{"roundness": 12, "lightMode": false}`, string(theme), "composed from the parts")
	_, err = os.Stat(p.Config("notch"))
	assert.NoError(t, err)
	marker, _ := os.ReadFile(filepath.Join(p.ConfigDir, "presets", "active_preset"))
	assert.Equal(t, "Yozakura\n", string(marker))
	parts, _ := os.ReadFile(filepath.Join(p.ConfigDir, "presets", "active_parts.json"))
	assert.JSONEq(t, `{"layout": "Yozakura", "style": "Sakura", "palette": "Plum"}`, string(parts))
	wall, _ := os.ReadFile(filepath.Join(p.CacheDir, "wallpapers.json"))
	assert.JSONEq(t, `{"matugenScheme": "scheme-content", "activeColorPreset": "Plum"}`, string(wall))
	general, _ := os.ReadFile(p.Config("general"))
	assert.JSONEq(t, `{"newLookOffered": true}`, string(general), "a new install is not offered the new look")

	// An existing install: nothing is seeded or marked.
	dir2 := t.TempDir()
	p2 := &paths.Paths{ConfigDir: filepath.Join(dir2, "cfg"), CacheDir: filepath.Join(dir2, "cache")}
	writeFiles(t, p2.ConfigDir, map[string]string{"config/theme.json": `{"roundness": 2}`})
	assert.NoError(t, seedConfig(p2, official))
	_, err = os.Stat(p2.Config("general"))
	assert.True(t, os.IsNotExist(err), "an existing install still gets the offer")
	_, err = os.Stat(p2.Config("bar"))
	assert.True(t, os.IsNotExist(err))
	_, err = os.Stat(filepath.Join(p2.ConfigDir, "presets", "active_preset"))
	assert.True(t, os.IsNotExist(err))
}
