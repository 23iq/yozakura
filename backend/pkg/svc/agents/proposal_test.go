package agents

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestProposedEditPreviewsWritesAndEdits(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "a.txt")
	if err := os.WriteFile(f, []byte("one\ntwo\nthree\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	path, diff := proposedEdit("Edit", map[string]any{"file_path": f, "old_string": "two", "new_string": "2"}, dir)
	if path != "a.txt" || !strings.Contains(diff, "-two") || !strings.Contains(diff, "+2") {
		t.Fatalf("edit preview: %q %q", path, diff)
	}
	_, diff = proposedEdit("Write", map[string]any{"file_path": filepath.Join(dir, "new.txt"), "content": "hi\n"}, dir)
	if !strings.Contains(diff, "+hi") {
		t.Fatalf("write preview: %q", diff)
	}
	_, diff = proposedEdit("MultiEdit", map[string]any{"file_path": f, "edits": []any{
		map[string]any{"old_string": "one", "new_string": "1"},
		map[string]any{"old_string": "three", "new_string": "3"},
	}}, dir)
	if !strings.Contains(diff, "+1") || !strings.Contains(diff, "+3") {
		t.Fatalf("multiedit preview: %q", diff)
	}
	if _, diff = proposedEdit("Edit", map[string]any{"file_path": f, "old_string": "missing", "new_string": "x"}, dir); diff != "" {
		t.Fatalf("unknown old_string must not produce a diff: %q", diff)
	}
	if p, d := proposedEdit("Bash", map[string]any{"command": "ls"}, dir); p != "" || d != "" {
		t.Fatal("non-edit tools have no preview")
	}
}
