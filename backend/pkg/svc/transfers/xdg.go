package transfers

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// DownloadDir resolves XDG_DOWNLOAD_DIR (user-dirs.dirs), falling back to
// ~/Downloads.
func DownloadDir(override string) string {
	if override != "" {
		return override
	}
	if v := os.Getenv("XDG_DOWNLOAD_DIR"); v != "" {
		return v
	}
	home, _ := os.UserHomeDir()
	cfg := os.Getenv("XDG_CONFIG_HOME")
	if cfg == "" {
		cfg = filepath.Join(home, ".config")
	}
	if f, err := os.Open(filepath.Join(cfg, "user-dirs.dirs")); err == nil {
		defer f.Close()
		sc := bufio.NewScanner(f)
		for sc.Scan() {
			line := strings.TrimSpace(sc.Text())
			if v, ok := strings.CutPrefix(line, "XDG_DOWNLOAD_DIR="); ok {
				v = strings.Trim(v, `"`)
				return strings.ReplaceAll(v, "$HOME", home)
			}
		}
	}
	return filepath.Join(home, "Downloads")
}
