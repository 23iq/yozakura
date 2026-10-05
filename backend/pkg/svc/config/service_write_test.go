package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAtomicWriteKeepsSymlink(t *testing.T) {
	dir := t.TempDir()
	real := filepath.Join(dir, "dotfiles", "states.json")
	if err := os.MkdirAll(filepath.Dir(real), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(real, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(dir, "states.json")
	if err := os.Symlink(real, link); err != nil {
		t.Fatal(err)
	}
	if err := atomicWrite(link, []byte(`{"a":1}`)); err != nil {
		t.Fatal(err)
	}
	if st, _ := os.Lstat(link); st.Mode()&os.ModeSymlink == 0 {
		t.Fatal("a symlinked file must stay a symlink")
	}
	if data, _ := os.ReadFile(real); string(data) != `{"a":1}` {
		t.Fatalf("target not written: %s", data)
	}
}
