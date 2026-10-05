package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestExtraFolderKeyMatchesQmlMd5(t *testing.T) {
	// Qt.md5("/home/u/Pictures/Walls") in QML; keep both sides in sync.
	if got := extraFolderKey("/home/u/Pictures/Walls"); got != "3061c730b7cc" {
		t.Fatalf("extraFolderKey = %s", got)
	}
}

func TestExtraThumbJobs(t *testing.T) {
	dir := t.TempDir()
	primary := filepath.Join(dir, "primary")
	extra := filepath.Join(dir, "extra")
	for _, p := range []string{
		filepath.Join(primary, "a.jpg"),
		filepath.Join(extra, "b.png"),
		filepath.Join(extra, "sub", "c.mp4"),
		filepath.Join(extra, ".hidden", "d.jpg"),
		filepath.Join(extra, "notes.txt"),
	} {
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	thumbs := filepath.Join(dir, "thumbs")
	jobs := extraThumbJobs([]string{extra, primary, extra, filepath.Join(dir, "missing")}, primary, thumbs)
	if len(jobs) != 2 {
		t.Fatalf("expected 2 jobs, got %v", jobs)
	}
	base := filepath.Join(thumbs, "_extra", extraFolderKey(extra))
	want := map[string]string{
		filepath.Join(extra, "b.png"):        filepath.Join(base, "b.png.jpg"),
		filepath.Join(extra, "sub", "c.mp4"): filepath.Join(base, "sub", "c.mp4.jpg"),
	}
	for _, j := range jobs {
		if want[j[0]] != j[1] {
			t.Fatalf("job %v, want thumb %s", j, want[j[0]])
		}
	}
}
