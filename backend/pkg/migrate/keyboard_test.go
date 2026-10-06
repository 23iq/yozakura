package migrate

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/paths"
)

func TestLegacyKeyboardManaged(t *testing.T) {
	pure := `{"layouts":[{"layout":"us","variant":""}],"switchBind":"alt_shift","options":[],"repeatRate":25,"repeatDelay":600,"showIndicator":false}`
	user := `{"layouts":[{"layout":"us","variant":""},{"layout":"ru","variant":""}],"switchBind":"alt_shift","options":[],"repeatRate":111,"repeatDelay":175}`
	for src, want := range map[string]bool{
		pure:                            false,
		`{"layouts":[{"layout":"us"}]}`: false,
		`{}`:                            false,
		user:                            true,
		`{"repeatRate":30}`:             true,
		`{"options":["caps:escape"]}`:   true,
		`{"switchBind":"caps"}`:         true,
	} {
		var doc map[string]any
		if err := json.Unmarshal([]byte(src), &doc); err != nil {
			t.Fatal(err)
		}
		if got := LegacyKeyboardManaged(doc); got != want {
			t.Errorf("%s: got %v, want %v", src, got, want)
		}
	}
}

func TestEnsureKeyboardManaged(t *testing.T) {
	p := paths.Paths{ConfigDir: t.TempDir()}
	file := p.Config("keyboard")
	if changed, err := EnsureKeyboardManaged(p); err != nil || changed {
		t.Fatalf("fresh install: %v %v", changed, err)
	}
	if _, err := os.Stat(file); err == nil {
		t.Fatal("must not create keyboard.json")
	}
	os.MkdirAll(filepath.Dir(file), 0o755)
	read := func() map[string]any {
		var m map[string]any
		b, _ := os.ReadFile(file)
		json.Unmarshal(b, &m)
		return m
	}
	os.WriteFile(file, []byte(`{"layouts":[{"layout":"us","variant":""},{"layout":"ru","variant":""}],"repeatRate":111,"repeatDelay":175}`), 0o644)
	if changed, err := EnsureKeyboardManaged(p); err != nil || !changed {
		t.Fatalf("user file: %v %v", changed, err)
	}
	if m := read(); m["managed"] != true || m["repeatRate"] != float64(111) {
		t.Fatalf("user file must become managed, values kept: %v", m)
	}
	os.WriteFile(file, []byte(`{"layouts":[{"layout":"us","variant":""}],"repeatRate":25,"repeatDelay":600}`), 0o644)
	EnsureKeyboardManaged(p)
	if m := read(); m["managed"] != false {
		t.Fatalf("pure defaults must stay unmanaged: %v", m)
	}
	os.WriteFile(file, []byte(`{"managed":false,"repeatRate":111}`), 0o644)
	if changed, _ := EnsureKeyboardManaged(p); changed {
		t.Fatal("an explicit value must be kept")
	}
}
