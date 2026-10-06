package exclusive

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// A failed tree restore must not stop the units and the import coming back.
func TestRollbackContinuesWhenTreeRestoreFails(t *testing.T) {
	home, _ := luaHome(t)
	sd, rec := newSystemd(), &recorder{}
	o := testOptions(t, home, sd, rec)
	sd.onDisable = func(string) {
		for _, b := range backups(t, home) {
			_ = os.RemoveAll(filepath.Join(home, ".local/share/yozakura/backups", b, "hypr"))
		}
	}
	o.Reload = func() error { return errors.New("config errors: x") }
	_, err := Enable(o)
	if err == nil || !strings.Contains(err.Error(), "restoring the backup failed") {
		t.Fatalf("want restore failure in the error, got %v", err)
	}
	if !sd.enabled["waybar.service"] || !reflect.DeepEqual(sd.started, []string{"waybar.service"}) {
		t.Fatalf("units not re-enabled: %v %v", sd.enabled, sd.started)
	}
	if len(rec.unimports) != 1 {
		t.Fatalf("import not reverted: %v", rec.unimports)
	}
}

// Manifests that only carry disabledUnits (older ones) still restore them.
func TestRestoreLegacyManifestUnits(t *testing.T) {
	home, _ := luaHome(t)
	sd, rec := newSystemd(), &recorder{}
	o := testOptions(t, home, sd, rec)
	if _, err := Enable(o); err != nil {
		t.Fatal(err)
	}
	dir := filepath.Join(home, ".local/share/yozakura/backups", backups(t, home)[0])
	data, _ := os.ReadFile(filepath.Join(dir, "manifest.json"))
	var m map[string]any
	_ = json.Unmarshal(data, &m)
	delete(m, "units")
	data, _ = json.Marshal(m)
	_ = os.WriteFile(filepath.Join(dir, "manifest.json"), data, 0o600)
	sd.started, sd.enabled["waybar.service"] = nil, false
	if _, err := Restore(o, ""); err != nil {
		t.Fatal(err)
	}
	if !sd.enabled["waybar.service"] {
		t.Fatal("legacy disabledUnits not re-enabled")
	}
}

func TestPreviewListsWhatWillHappen(t *testing.T) {
	home, _ := luaHome(t)
	o := testOptions(t, home, newSystemd(), &recorder{})
	p, err := Preview(o)
	if err != nil {
		t.Fatal(err)
	}
	if p.Entry != "hyprland.lua" || p.UserFile != "user.lua" || p.AlreadyDone {
		t.Fatalf("%+v", p)
	}
	if !reflect.DeepEqual(p.Units, []string{"waybar.service", "quickshell-foo.service"}) {
		t.Fatalf("units %v", p.Units)
	}
	if len(p.Monitors) != 1 || !strings.HasPrefix(p.Monitors[0], "DP-1 2560x1440@165") || p.Keyboard != "us,ru" {
		t.Fatalf("%+v", p)
	}
	if _, err := os.Stat(filepath.Join(home, ".local/share/yozakura/backups")); err == nil {
		t.Fatal("preview must not create anything")
	}
}
