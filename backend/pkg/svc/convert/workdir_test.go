package convert

import (
	"os"
	"path/filepath"
	"testing"
)

// A hidden work dir that cannot be removed keeps its record (a later
// start sweeps it); one removed drops it.
func TestHiddenWorkDirRecordOutlivesAFailedRemove(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root removes anything")
	}
	s, _ := newTest(t, &fakeClip{})
	out := t.TempDir()
	w, release, err := s.hiddenWorkDir(out)
	if err != nil {
		t.Fatal(err)
	}
	_ = os.WriteFile(filepath.Join(w, "out.png"), []byte("x"), 0o600)
	_ = os.Chmod(w, 0o500) // its file cannot be unlinked
	release()
	records, _ := os.ReadDir(s.outsideRoot())
	_ = os.Chmod(w, 0o700)
	if len(records) != 1 {
		t.Fatalf("record dropped with the dir still there: %v", records)
	}
	release()
	records, _ = os.ReadDir(s.outsideRoot())
	if _, err := os.Stat(w); err == nil || len(records) != 0 {
		t.Fatalf("dir %v, records %v", err, records)
	}
}
