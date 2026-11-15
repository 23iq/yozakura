package convert

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

// The input is the file that was checked: hard-linked from the open
// descriptor; a FIFO (or a path swapped for one) fails at once instead of
// blocking a worker.
func TestPlaceInput(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "a%d.png")
	_ = os.WriteFile(src, []byte("data"), 0o644)
	dst := filepath.Join(dir, "in.png")
	if err := placeInput(context.Background(), src, dst, false); err != nil {
		t.Fatal(err)
	}
	var a, b syscall.Stat_t
	_ = syscall.Stat(src, &a)
	_ = syscall.Lstat(dst, &b)
	if a.Ino != b.Ino {
		t.Fatal("input not hard-linked")
	}
	fifo := filepath.Join(dir, "f.png")
	if err := syscall.Mkfifo(fifo, 0o600); err != nil {
		t.Skip(err)
	}
	done := make(chan error, 1)
	go func() { done <- placeInput(context.Background(), fifo, filepath.Join(dir, "in2.png"), false) }()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("a FIFO was placed")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("placing a FIFO blocked")
	}
}

// LibreOffice gets a pinned profile; ffmpeg reads only the local file and
// its duration is probed on the neutral name.
func TestPlanHardening(t *testing.T) {
	for _, to := range []string{"pdf"} {
		for _, from := range []string{"docx", "md"} {
			p := plan(t, from, to, QualityBalanced)
			reg := p.Files["/prof/user/registrymodifications.xcu"]
			// Writer keeps its UpdateLinks enum raw (sw/inc/linkenum.hxx:
			// NEVER = 0, AUTOMATIC = 2), whatever Writer.xcs says; Calc's
			// ScLkUpdMode has LM_NEVER = 1
			if strings.Contains(reg, `Office.Writer/Content/Update"><prop oor:name="Link" oor:op="fuse"><value>2<`) {
				t.Errorf("Writer set to update links automatically")
			}
			for _, w := range []string{`"MacroSecurityLevel" oor:op="fuse"><value>3`, `"DisableMacrosExecution" oor:op="fuse"><value>true`,
				`Office.Writer/Content/Update"><prop oor:name="Link" oor:op="fuse"><value>0<`, `Office.Calc/Content/Update"><prop oor:name="Link" oor:op="fuse"><value>1<`} {
				if !strings.Contains(reg, w) {
					t.Errorf("%s->%s: profile lacks %q", from, to, w)
				}
			}
		}
	}
	p := plan(t, "mkv", "mp4", QualityBalanced)
	if !strings.Contains(argv(p, 0), "-protocol_whitelist file -i in.mkv") {
		t.Errorf("ffmpeg argv %s", argv(p, 0))
	}
	var probed string
	work := t.TempDir()
	src := filepath.Join(t.TempDir(), "odd%d.mkv")
	_ = os.WriteFile(src, []byte("x"), 0o644)
	p = &Plan{Work: work, Src: src, Input: "in.mkv", Out: filepath.Join(work, "out"),
		probe: func(_ context.Context, path string) float64 { probed = path; return 3 }}
	_ = p.Run(context.Background(), nil)
	if probed != filepath.Join(work, "in.mkv") || p.Duration != 3 {
		t.Fatalf("probed %q, duration %v", probed, p.Duration)
	}
}

// Files are created once: a profile LibreOffice already rewrote is kept.
func TestPlanFilesAreWrittenOnce(t *testing.T) {
	work := t.TempDir()
	abs := filepath.Join(t.TempDir(), "p", "x.xcu")
	p := &Plan{Work: work, Files: map[string]string{"policy.xml": "a", abs: "b"}}
	if err := p.writeFiles(); err != nil {
		t.Fatal(err)
	}
	_ = os.WriteFile(abs, []byte("changed"), 0o600)
	if err := p.writeFiles(); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(abs); string(b) != "changed" {
		t.Fatal("rewrote an existing file")
	}
	if b, _ := os.ReadFile(filepath.Join(work, "policy.xml")); string(b) != "a" {
		t.Fatal("relative file")
	}
}
