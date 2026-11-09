// Package wallref resolves the wallpaper references the shell saves in
// <cache>/wallpapers.json (currentWall, perScreenWallpapers).
//
// The bundled example wallpapers are saved as "bundled:<relative path>"
// because their absolute location (a Nix store path, a mods generation)
// changes with every update. Older files hold an absolute path into some
// copy of the folder. Mirrors modules/widgets/dashboard/wallpapers/
// WallpaperRefs.js.
package wallref

import (
	"path/filepath"
	"strings"
)

// Prefix marks a bundled wallpaper id.
const Prefix = "bundled:"

// BundledRel is the bundled folder relative to the shell source.
const BundledRel = "assets/wallpapers_example"

const marker = "/" + BundledRel + "/"

// BundledDir is the bundled folder of the shell at shellSource ("" if unknown).
func BundledDir(shellSource string) string {
	if shellSource == "" {
		return ""
	}
	return filepath.Join(shellSource, BundledRel)
}

// Resolve turns a saved reference into an absolute path in bundledDir
// (bundled ids and old copies of the folder); other paths are returned
// as they are, as is everything when bundledDir is "".
func Resolve(stored, bundledDir string) string {
	if bundledDir == "" {
		return stored
	}
	rel := ""
	switch {
	case strings.HasPrefix(stored, Prefix):
		rel = strings.TrimPrefix(stored, Prefix)
	case strings.Contains(stored, marker):
		rel = stored[strings.LastIndex(stored, marker)+len(marker):]
	}
	if rel == "" {
		return stored
	}
	return filepath.Join(bundledDir, filepath.Clean("/" + rel)[1:])
}
