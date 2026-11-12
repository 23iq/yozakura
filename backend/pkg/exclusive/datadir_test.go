package exclusive

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

// A data dir outside ~/.local/share (XDG_DATA_HOME) holds the backups and
// is what the minimal entry loads.
func TestEnableUsesDataDir(t *testing.T) {
	home, hypr := luaHome(t)
	data := filepath.Join(t.TempDir(), "data", "yozakura")
	o := testOptions(t, home, newSystemd(), &recorder{})
	o.DataDir = data
	st, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(st.Backup, filepath.Join(data, "backups")+"/") {
		t.Fatalf("backup %s not under the data dir %s", st.Backup, data)
	}
	entry, _ := os.ReadFile(filepath.Join(hypr, "hyprland.lua"))
	if !strings.Contains(string(entry), brand.HyprLuaBlockFor(home, data)) ||
		!strings.Contains(string(entry), filepath.Join(data, "hyprland.lua")) || strings.Contains(string(entry), ".local/share") {
		t.Fatalf("entry does not load the data dir:\n%s", entry)
	}
	if _, err := os.Stat(filepath.Join(home, ".local/share/yozakura")); err == nil {
		t.Fatal("wrote into ~/.local/share")
	}
	if _, err := Restore(o, ""); err != nil {
		t.Fatal(err)
	}
	if Active(hypr) {
		t.Fatal("still active after restore")
	}
}

// A backup taken while the data dir was always ~/.local/share/<app> is
// still found once DataDir points elsewhere.
func TestRestoreFindsBackupInOldDataDir(t *testing.T) {
	home, hypr := luaHome(t)
	o := testOptions(t, home, newSystemd(), &recorder{})
	st, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	o.DataDir = filepath.Join(t.TempDir(), "yozakura")
	if got := GetStatus(o); got.Backup != st.Backup || !got.Active {
		t.Fatalf("status %+v, want backup %s", got, st.Backup)
	}
	if _, err := Restore(o, ""); err != nil {
		t.Fatal(err)
	}
	if Active(hypr) {
		t.Fatal("still active after restore")
	}
}
