package main

import (
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
