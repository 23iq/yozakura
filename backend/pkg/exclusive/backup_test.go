package exclusive

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCopyTreeKeepsModesAndLinks(t *testing.T) {
	src := filepath.Join(t.TempDir(), "src")
	write(t, filepath.Join(src, "ro/file.conf"), "x", 0o444)
	write(t, filepath.Join(src, "exec.sh"), "#!/bin/sh", 0o700)
	os.Symlink("/does/not/exist", filepath.Join(src, "dangling.conf"))
	os.Symlink("ro", filepath.Join(src, "dirlink"))
	os.Chmod(filepath.Join(src, "ro"), 0o555)
	t.Cleanup(func() { os.Chmod(filepath.Join(src, "ro"), 0o755) })
	dst := filepath.Join(t.TempDir(), "dst")
	if err := copyTree(src, dst); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(filepath.Join(dst, "ro"), 0o755) })
	sameTree(t, snapshot(t, src), snapshot(t, dst))
}

func TestBackupNamesDoNotCollide(t *testing.T) {
	home, _ := luaHome(t)
	o := testOptions(t, home, newSystemd(), &recorder{})
	o.Now = nil // real clock: two backups in the same second
	a, err := createBackup(o)
	if err != nil {
		t.Fatal(err)
	}
	b, err := createBackup(o)
	if err != nil {
		t.Fatal(err)
	}
	if a == b {
		t.Fatal("same dir")
	}
}

func TestLatestBackupSkipsInvalid(t *testing.T) {
	home, _ := luaHome(t)
	o := testOptions(t, home, newSystemd(), &recorder{})
	st, err := Enable(o)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(o.backupRoot(), "99999999-000000"), 0o755); err != nil {
		t.Fatal(err)
	}
	if dir, _, err := latestBackup(o); err != nil || dir != st.Backup {
		t.Fatalf("got %s %v, want %s", dir, err, st.Backup)
	}
}
