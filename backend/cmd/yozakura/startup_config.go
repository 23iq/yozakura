package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"yozakura/backend/pkg/daemon"
	"yozakura/backend/pkg/migrate"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/presets"
)

// shiftDefaults moves values stored at an old default to the new one,
// once (the theme overhaul's default shift).
func shiftDefaults() {
	if _, err := migrate.EnsureDefaultsShift(*paths.New()); err != nil {
		fmt.Fprintf(os.Stderr, "Warning: default shift migration: %v\n", err)
	}
}

// officialPresetDir is the shell's built-in presets directory.
func officialPresetDir() string {
	return filepath.Join(shellDir(), "assets", "presets")
}

// ensureConfigFiles seeds a new install from the default set and marks
// it (and its parts) current; an existing install is left alone.
func ensureConfigFiles() {
	p := paths.New()
	if err := seedConfig(p, officialPresetDir()); err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to ensure config: %v\n", err)
	}
}

func seedConfig(p *paths.Paths, official string) error {
	files, ref, setErr := presets.DefaultSet(official)
	files = offeredLook(files)
	fresh, err := daemon.EnsureConfigFiles(p, files)
	if err != nil || !fresh {
		return err
	}
	if setErr != nil {
		return fmt.Errorf("default preset: %w", setErr)
	}
	return presets.SeedNewInstall(filepath.Join(p.ConfigDir, "presets"), filepath.Join(p.CacheDir, "wallpapers.json"),
		presets.DefaultPreset, ref, files)
}

// offeredLook marks the "Try the new look" card answered in the seeded
// general.json: a new install already starts from the default set.
func offeredLook(files map[string][]byte) map[string][]byte {
	if files == nil {
		files = map[string][]byte{}
	}
	general := map[string]any{}
	if data, ok := files["general"]; ok {
		_ = json.Unmarshal(data, &general)
	}
	general["newLookOffered"] = true
	data, _ := json.MarshalIndent(general, "", "  ")
	files["general"] = append(data, '\n')
	return files
}
