package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/paths"
)

func call(t *testing.T, h func(json.RawMessage) (any, error), params any) error {
	t.Helper()
	raw, _ := json.Marshal(params)
	_, err := h(raw)
	return err
}

// A file that does not parse is left alone: writing only the patched key
// back would wipe every other setting in it.
func TestPatchAndStateSetRefuseCorruptFile(t *testing.T) {
	dir := t.TempDir()
	s := NewService(&paths.Paths{ConfigDir: dir, StateDir: dir})
	corrupt := []byte("{\n  \"position\": \"top\",\n  \"size\": 32,\n") // truncated
	for _, f := range []string{s.fileFor("bar"), s.paths.StatesFile()} {
		if err := os.MkdirAll(filepath.Dir(f), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(f, corrupt, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := call(t, s.patch, map[string]any{"domain": "bar", "key_path": []string{"size"}, "value": 40}); err == nil {
		t.Fatal("config.patch on a corrupt file must fail")
	}
	if err := call(t, s.stateSet, map[string]any{"key": "k", "value": 1}); err == nil {
		t.Fatal("config.stateSet on a corrupt file must fail")
	}
	for _, f := range []string{s.fileFor("bar"), s.paths.StatesFile()} {
		if got, _ := os.ReadFile(f); string(got) != string(corrupt) {
			t.Fatalf("%s rewritten:\n%s", f, got)
		}
	}

	// not an object: same
	if err := os.WriteFile(s.fileFor("bar"), []byte(`["a"]`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := call(t, s.patch, map[string]any{"domain": "bar", "key_path": []string{"size"}, "value": 40}); err == nil {
		t.Fatal("a non-object file must not be replaced")
	}
}

func TestPatchAndStateSetCreateAndMerge(t *testing.T) {
	dir := t.TempDir()
	s := NewService(&paths.Paths{ConfigDir: dir, StateDir: dir})
	// missing file: created
	if err := call(t, s.patch, map[string]any{"domain": "bar", "key_path": []string{"layout", "style"}, "value": "pill"}); err != nil {
		t.Fatal(err)
	}
	if err := call(t, s.patch, map[string]any{"domain": "bar", "key_path": []string{"size"}, "value": 40}); err != nil {
		t.Fatal(err)
	}
	var bar map[string]any
	data, _ := os.ReadFile(s.fileFor("bar"))
	if err := json.Unmarshal(data, &bar); err != nil || bar["size"] != float64(40) || bar["layout"].(map[string]any)["style"] != "pill" {
		t.Fatalf("bar = %s (%v)", data, err)
	}

	// empty and null files hold nothing to lose: written
	for _, content := range []string{"", "  \n", "null"} {
		if err := os.WriteFile(s.paths.StatesFile(), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := call(t, s.stateSet, map[string]any{"key": "k", "value": 1}); err != nil {
			t.Fatalf("%q: %v", content, err)
		}
		if got := readStates(t, s); got["k"] != float64(1) {
			t.Fatalf("%q: states = %v", content, got)
		}
	}
	writeStates(t, s, map[string]any{"keep": true})
	if err := call(t, s.stateSet, map[string]any{"key": "k", "value": 2}); err != nil {
		t.Fatal(err)
	}
	if got := readStates(t, s); got["keep"] != true || got["k"] != float64(2) {
		t.Fatalf("states = %v", got)
	}
}
