package term

import (
	"os"
	"path/filepath"
	"testing"
)

func TestListedShell(t *testing.T) {
	dir := t.TempDir()
	sys := filepath.Join(dir, "fish")
	if err := os.WriteFile(sys, nil, 0o755); err != nil {
		t.Fatal(err)
	}
	shells := "# comment\n/bin/sh\n" + sys + "\n/missing/fish\n"
	if got := listedShell(sys, shells); got != sys {
		t.Errorf("listed PATH fish: got %q", got)
	}
	if got := listedShell("/home/u/.local/bin/fish", shells); got != sys {
		t.Errorf("unlisted PATH fish should give the listed one: got %q", got)
	}
	if got := listedShell("/home/u/.local/bin/fish", "/bin/sh\n"); got != "/home/u/.local/bin/fish" {
		t.Errorf("no listed fish keeps the PATH one: got %q", got)
	}
}
