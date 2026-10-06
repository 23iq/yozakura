package displays

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRestoreMovedUndoesMoveConflicts(t *testing.T) {
	home := t.TempDir()
	hypr := filepath.Join(home, ".config/hypr")
	data := filepath.Join(home, ".local/share/app")
	os.MkdirAll(hypr, 0o755)
	conf := filepath.Join(hypr, "monitors.conf")
	lua := filepath.Join(hypr, "m.lua")
	confSrc := "monitor = DP-1, 1920x1080@60, 0x0, 1\nbind = a, b\n"
	luaSrc := "  hl.monitor({ output = \"DP-2\", mode = \"1920x1080@60\", position = \"0x0\", scale = 1 })\n"
	os.WriteFile(conf, []byte(confSrc), 0o644)
	os.WriteFile(lua, []byte(luaSrc), 0o644)

	res, err := MoveConflicts(hypr, data, home)
	if err != nil || len(res.Moved) != 2 {
		t.Fatalf("move: %v %+v", err, res)
	}
	if b, _ := os.ReadFile(conf); !strings.Contains(string(b), ": moved monitor") {
		t.Fatalf("not moved: %s", b)
	}
	got, err := RestoreMoved(hypr, data, home)
	if err != nil || len(got) != 2 {
		t.Fatalf("restore: %v %+v", err, got)
	}
	if b, _ := os.ReadFile(conf); string(b) != confSrc {
		t.Fatalf("conf %q", b)
	}
	if b, _ := os.ReadFile(lua); string(b) != luaSrc {
		t.Fatalf("lua %q", b)
	}
	if again, _ := RestoreMoved(hypr, data, home); len(again) != 0 {
		t.Fatalf("not idempotent: %+v", again)
	}
}
