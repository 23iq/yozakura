package main

import (
	"crypto/md5"
	"encoding/hex"
	"os"
	"path/filepath"
	"strings"
)

// Extra wallpaper folders (Config.desktop.wallpaperFolders) are passed to
// `yozakura thumbs` after the fallback path. Their thumbnails live under
// <thumbDir>/_extra/<md5(root)[:12]>/<relative path>.jpg, the layout
// modules/widgets/dashboard/wallpapers/WallpaperFolders.js reads. The root
// is hashed exactly as given (the shell passes normalized absolute paths).

func extraFolderKey(root string) string {
	sum := md5.Sum([]byte(root))
	return hex.EncodeToString(sum[:])[:12]
}

// mediaUnder lists media files below root, skipping hidden directories
// (same rules as the primary folder scan).
func mediaUnder(root string) []string {
	files := []string{}
	visited := map[devIno]bool{}
	walkFollowSymlinks(root, visited, func(path string, fi os.FileInfo) {
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return
		}
		parts := strings.Split(rel, string(filepath.Separator))
		for _, part := range parts[:len(parts)-1] {
			if strings.HasPrefix(part, ".") {
				return
			}
		}
		ext := strings.ToLower(filepath.Ext(path))
		if mediaVideoExts[ext] || mediaImageExts[ext] {
			files = append(files, path)
		}
	})
	return files
}

// extraThumbJobs returns [file, thumb] pairs for every media file in the
// extra roots. Roots equal to the primary folder or missing are skipped.
func extraThumbJobs(roots []string, primary, thumbDir string) [][2]string {
	out := [][2]string{}
	seen := map[string]bool{}
	for _, root := range roots {
		abs, err := filepath.Abs(expandTilde(root))
		if err != nil || abs == primary || seen[abs] {
			continue
		}
		seen[abs] = true
		if st, err := os.Stat(abs); err != nil || !st.IsDir() {
			continue
		}
		base := filepath.Join(thumbDir, "_extra", extraFolderKey(root))
		for _, f := range mediaUnder(abs) {
			rel, err := filepath.Rel(abs, f)
			if err != nil {
				continue
			}
			out = append(out, [2]string{f, filepath.Join(base, rel+".jpg")})
		}
	}
	return out
}
