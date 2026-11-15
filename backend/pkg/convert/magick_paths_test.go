package convert

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ImageMagick's own SVG renderer runs under a path policy matched against
// resolved paths: a work dir reached through a symlink (a symlinked cache,
// /home -> /var/home) still converts, and the input is never a symlink.
func TestMSVGUnderASymlinkedWorkDir(t *testing.T) {
	real := t.TempDir()
	link := filepath.Join(t.TempDir(), "cache")
	if err := os.Symlink(real, link); err != nil {
		t.Fatal(err)
	}
	work := filepath.Join(link, "w")
	if err := os.Mkdir(work, 0o700); err != nil {
		t.Fatal(err)
	}
	pol := magickPolicy("svg", "png", "MSVG", work)
	if !strings.Contains(pol, `pattern="`+work+`/*"`) || !strings.Contains(pol, `pattern="`+filepath.Join(real, "w")+`/*"`) {
		t.Fatalf("policy lacks the resolved work dir:\n%s", pol)
	}
	need(t, EngineMagick)
	src := filepath.Join(t.TempDir(), "x.svg")
	_ = os.WriteFile(src, []byte(`<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"><rect width="4" height="4" fill="red"/></svg>`), 0o644)
	tools := NewTools(map[Engine]string{EngineMagick: realTools.Prog(EngineMagick)}, nil) // no RSVG listed: MSVG
	p, err := BuildPlan(Request{Src: src, From: "svg", To: "png"}, tools, work, PlanOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if err := p.Run(context.Background(), nil); err != nil {
		t.Fatalf("MSVG under a symlinked work dir: %v", err)
	}
	if st, err := os.Lstat(filepath.Join(work, p.Input)); err != nil || st.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("input is a symlink: %v", err)
	}
}

// copyOnly never leaves a symlink, even when a hard link is impossible.
func TestPlaceInputCopyOnly(t *testing.T) {
	// a hard link to a file in /proc fails (another filesystem): the
	// fallback is a copy with copyOnly, a symlink without
	src := "/proc/self/cmdline"
	if _, err := os.Stat(src); err != nil {
		t.Skip("no /proc")
	}
	dir := t.TempDir()
	if err := placeInput(context.Background(), src, filepath.Join(dir, "a"), true); err != nil {
		t.Fatal(err)
	}
	if st, _ := os.Lstat(filepath.Join(dir, "a")); st.Mode()&os.ModeSymlink != 0 {
		t.Fatal("copyOnly made a symlink")
	}
	if err := placeInput(context.Background(), src, filepath.Join(dir, "b"), false); err != nil {
		t.Fatal(err)
	}
	if st, _ := os.Lstat(filepath.Join(dir, "b")); st.Mode()&os.ModeSymlink == 0 {
		t.Fatal("expected the symlink fallback")
	}
}
