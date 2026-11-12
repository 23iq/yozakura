package exclusive

import (
	"os"
	"path/filepath"
	"testing"
)

// A data dir the entry's language cannot spell ('#' in hyprland.conf) makes
// exclusive mode refuse instead of writing an entry that loads nothing; the
// Lua entry quotes it and is written.
func TestWriteMinimalRefusesUnspellableDataDir(t *testing.T) {
	home := t.TempDir()
	hypr := filepath.Join(home, "hypr")
	o := Options{Home: home, DataDir: filepath.Join(home, "a#b", "yozakura")}
	if err := writeMinimal(o, hypr, confEntry, "/b/1"); err == nil {
		t.Fatal("hyprland.conf entry written with '#' in the data dir")
	}
	if _, err := os.Stat(filepath.Join(hypr, confEntry)); !os.IsNotExist(err) {
		t.Fatalf("conf entry exists after a refusal: %v", err)
	}
	if err := writeMinimal(o, hypr, luaEntry, "/b/1"); err != nil {
		t.Fatalf("lua entry: %v", err)
	}
}
