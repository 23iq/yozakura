package migrate

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/paths"
)

func TestEnsureNotchStyle(t *testing.T) {
	p := paths.Paths{ConfigDir: t.TempDir()}
	file := p.Config("notch")
	if changed, err := EnsureNotchStyle(p); err != nil || changed {
		t.Fatalf("fresh install: %v %v", changed, err)
	}
	if _, err := os.Stat(file); err == nil {
		t.Fatal("must not create notch.json")
	}
	os.MkdirAll(filepath.Dir(file), 0o755)
	read := func() map[string]any {
		var m map[string]any
		b, _ := os.ReadFile(file)
		json.Unmarshal(b, &m)
		return m
	}
	cases := []struct{ in, style string }{
		{`{"theme":"island","position":"bottom"}`, "island"},
		{`{"theme":"default"}`, "attached"},
		{`{"theme":"island","style":"attached"}`, "island"},
		{`{"theme":"default","style":"pill"}`, "pill"},
		{`{"theme":"island","style":"pill"}`, "pill"},
	}
	for _, c := range cases {
		os.WriteFile(file, []byte(c.in), 0o644)
		if changed, err := EnsureNotchStyle(p); err != nil || !changed {
			t.Fatalf("%s: %v %v", c.in, changed, err)
		}
		m := read()
		if m["style"] != c.style {
			t.Fatalf("%s: style %v, want %s", c.in, m["style"], c.style)
		}
		if _, has := m["theme"]; has {
			t.Fatalf("%s: theme must be removed: %v", c.in, m)
		}
	}
	if m := read(); len(m) != 1 {
		t.Fatalf("other keys must be kept as they are: %v", m)
	}
	os.WriteFile(file, []byte(`{"style":"island","position":"bottom"}`), 0o644)
	if changed, _ := EnsureNotchStyle(p); changed {
		t.Fatal("already migrated: no write")
	}
	if m := read(); m["position"] != "bottom" {
		t.Fatalf("values kept: %v", m)
	}
}
