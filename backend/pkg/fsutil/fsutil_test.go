package fsutil

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestWriteFileKeepsSymlink(t *testing.T) {
	dir := t.TempDir()
	real := filepath.Join(dir, "dotfiles", "bar.json")
	assert.NoError(t, os.MkdirAll(filepath.Dir(real), 0o755))
	assert.NoError(t, os.WriteFile(real, []byte("old"), 0o600))
	link := filepath.Join(dir, "config", "bar.json")
	assert.NoError(t, os.MkdirAll(filepath.Dir(link), 0o755))
	assert.NoError(t, os.Symlink(real, link))

	assert.NoError(t, WriteFile(link, []byte("new"), 0o644))

	st, err := os.Lstat(link)
	assert.NoError(t, err)
	assert.True(t, st.Mode()&os.ModeSymlink != 0, "the symlink stays a symlink")
	got, _ := os.ReadFile(real)
	assert.Equal(t, "new", string(got), "the real target is written")
	rst, _ := os.Stat(real)
	assert.Equal(t, os.FileMode(0o600), rst.Mode().Perm(), "an existing file keeps its mode")
	left, _ := filepath.Glob(filepath.Join(dir, "*", ".*"))
	assert.Empty(t, left, "no temp files left behind")
}

func TestWriteFileDanglingAndRelativeSymlink(t *testing.T) {
	dir := t.TempDir()
	assert.NoError(t, os.MkdirAll(filepath.Join(dir, "real"), 0o755))
	link := filepath.Join(dir, "link.json")
	assert.NoError(t, os.Symlink("real/new.json", link))
	assert.NoError(t, WriteFile(link, []byte("x"), 0o644))
	got, err := os.ReadFile(filepath.Join(dir, "real", "new.json"))
	assert.NoError(t, err)
	assert.Equal(t, "x", string(got))
	st, _ := os.Lstat(link)
	assert.True(t, st.Mode()&os.ModeSymlink != 0)
}

func TestWriteFileNew(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "a", "b.json")
	assert.NoError(t, WriteFile(p, []byte("1"), 0o640))
	st, err := os.Stat(p)
	assert.NoError(t, err)
	assert.Equal(t, os.FileMode(0o640), st.Mode().Perm())
}

func TestLockExcludes(t *testing.T) {
	p := filepath.Join(t.TempDir(), "x.lock")
	unlock, err := Lock(p)
	assert.NoError(t, err)
	got := make(chan struct{})
	go func() {
		u, err := Lock(p)
		assert.NoError(t, err)
		close(got)
		u()
	}()
	select {
	case <-got:
		t.Fatal("second lock acquired while the first is held")
	case <-time.After(100 * time.Millisecond):
	}
	unlock()
	select {
	case <-got:
	case <-time.After(2 * time.Second):
		t.Fatal("second lock never acquired")
	}
}
