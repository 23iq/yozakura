package presets

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// A new install starts from the default set: its composed files seed the
// missing config files, and the set and its parts are marked current.

// DefaultSet composes DefaultPreset from a built-in presets directory and
// returns its files and parts ("" parts for a legacy set).
func DefaultSet(officialDir string) (map[string][]byte, SetRef, error) {
	dir := filepath.Join(OfficialSetsDir(officialDir), DefaultPreset)
	files, err := Compose(officialDir, dir)
	if err != nil {
		return nil, SetRef{}, err
	}
	ref, _, err := ReadSetRef(dir)
	return files, resolveRef(officialDir, ref), err
}

// SeedNewInstall marks the set name and its parts current in a user
// preset dir and, when wallpapers.json does not exist yet, writes the
// set's palette generator settings (its wallpaper document) there.
func SeedNewInstall(userDir, wallpaperFile, name string, ref SetRef, files map[string][]byte) error {
	m := &Manager{UserDir: userDir, WallpaperFile: wallpaperFile}
	if err := m.setActive(name); err != nil {
		return err
	}
	if err := m.setCurrentParts(ref); err != nil {
		return err
	}
	data, ok := files[WallpaperDomain]
	if _, err := os.Stat(wallpaperFile); !ok || wallpaperFile == "" || err == nil {
		return nil
	}
	var doc any
	if err := json.Unmarshal(data, &doc); err != nil {
		return err
	}
	return m.applyWallpaper(doc)
}
