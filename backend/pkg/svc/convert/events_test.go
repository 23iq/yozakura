package convert

import (
	"bytes"
	"context"
	"image"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	conv "yozakura/backend/pkg/convert"
	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/proc"
)

// A slow detection of the engines never stalls the service: only the very
// first Tools waits, a refresh runs in the background.
func TestToolsDetectionNeverHoldsTheService(t *testing.T) {
	block := make(chan struct{})
	defer close(block)
	calls := 0
	s := New(Options{Detect: func() *conv.Tools {
		calls++
		if calls > 1 {
			<-block
		}
		return conv.NewTools(nil, nil)
	}, CacheDir: t.TempDir(), Home: t.TempDir(), Clipboard: &fakeClip{}})
	if s.Tools() == nil {
		t.Fatal("no tools")
	}
	s.tools.mu.Lock()
	s.tools.at = time.Now().Add(-2 * toolsTTL)
	s.tools.mu.Unlock()
	done := make(chan struct{})
	go func() {
		defer close(done)
		_ = s.Tools() // starts a refresh that blocks
		_ = s.Tools()
		_ = s.Jobs()
		dir := t.TempDir()
		if _, err := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "a.json"), Target: "yaml"}}}); err != nil {
			t.Error(err)
		}
		waitDone(t, s)
	}()
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		t.Fatal("a refresh of the engines blocked the service")
	}
}

// A subscriber whose buffer was full when a job finished still gets its
// final state.
func TestFinalStateSurvivesAFullBuffer(t *testing.T) {
	s, _ := newTest(t, &fakeClip{})
	sub := ipc.NewSubscriber(1)
	s.subscribe(sub)
	dir := t.TempDir()
	jobs, err := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "a.json"), Target: "yaml"},
		{Path: jsonFile(t, dir, "b.json"), Target: "yaml"}}})
	if err != nil {
		t.Fatal(err)
	}
	waitDone(t, s)
	final := map[string]string{}
	deadline := time.After(5 * time.Second)
	for final[jobs[0].ID] != StateDone || final[jobs[1].ID] != StateDone {
		select {
		case ev := <-sub.Events:
			j := ev.Data.(Job)
			final[j.ID] = j.State
		case <-deadline:
			t.Fatalf("final states never arrived: %v", final)
		}
	}
	sub.Stop()
}

// A target is any name of a format; a relative output folder is made
// absolute before any tool runs.
func TestStartNormalizesTargetAndOutDir(t *testing.T) {
	s, _ := newTest(t, &fakeClip{})
	dir := t.TempDir()
	_ = os.Mkdir(filepath.Join(dir, "out"), 0o755)
	t.Chdir(dir)
	jobs, err := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "a.json"), Target: "YML"}}, OutDir: "out"})
	if err != nil {
		t.Fatal(err)
	}
	if jobs[0].To != "yaml" {
		t.Fatalf("target %q", jobs[0].To)
	}
	j := waitDone(t, s)[0]
	if j.State != StateDone || j.Output != filepath.Join(dir, "out", "a.yaml") {
		t.Fatalf("%+v", j)
	}
}

// A hidden work dir a dead process left in an output folder is removed by
// the next start; a record naming anything else is only forgotten.
func TestHiddenWorkDirsOfDeadProcessesAreSwept(t *testing.T) {
	cache := t.TempDir()
	out := t.TempDir()
	left := filepath.Join(out, hiddenPrefix()+"999999-abc")
	other := filepath.Join(out, "keep")
	_ = os.MkdirAll(left, 0o700)
	_ = os.MkdirAll(other, 0o700)
	_ = os.MkdirAll(filepath.Join(cache, "outside"), 0o700)
	_ = os.WriteFile(filepath.Join(cache, "outside", "999999-1"), []byte(left), 0o600)
	_ = os.WriteFile(filepath.Join(cache, "outside", "999999-2"), []byte(other), 0o600)
	New(Options{Detect: func() *conv.Tools { return conv.NewTools(nil, nil) }, CacheDir: cache, Home: t.TempDir(), Clipboard: &fakeClip{}})
	if _, err := os.Stat(left); err == nil {
		t.Fatal("hidden work dir not swept")
	}
	if _, err := os.Stat(other); err != nil {
		t.Fatal("a record removed a folder that is not a work dir")
	}
	if entries, _ := os.ReadDir(filepath.Join(cache, "outside")); len(entries) != 0 {
		t.Fatalf("records left: %v", entries)
	}
}

// docx -> md keeps the document's images in a folder next to the result.
func TestTextResultShipsItsMedia(t *testing.T) {
	pandoc, err := exec.LookPath("pandoc")
	if err != nil {
		t.Skip("pandoc not installed")
	}
	dir := t.TempDir()
	pic := filepath.Join(dir, "pic.png")
	var b bytes.Buffer
	_ = png.Encode(&b, image.NewRGBA(image.Rect(0, 0, 2, 2)))
	_ = os.WriteFile(pic, b.Bytes(), 0o644)
	md := filepath.Join(dir, "src.md")
	_ = os.WriteFile(md, []byte("# t\n\n![pic](pic.png)\n"), 0o644)
	docx := filepath.Join(dir, "report.docx")
	if _, err := proc.Run(context.Background(), pandoc, "--resource-path", dir, "-o", docx, md); err != nil {
		t.Fatal(err)
	}
	s := New(Options{Detect: func() *conv.Tools { return conv.DetectTools(nil) }, CacheDir: t.TempDir(), Home: t.TempDir(), Clipboard: &fakeClip{}})
	if _, err := s.Start(StartParams{Items: []Item{{Path: docx, Target: "md"}}}); err != nil {
		t.Fatal(err)
	}
	j := waitDone(t, s)[0]
	if j.State != StateDone {
		t.Fatalf("%+v", j)
	}
	text, _ := os.ReadFile(j.Output)
	var shipped []string
	_ = filepath.WalkDir(filepath.Join(dir, "report_media"), func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			rel, _ := filepath.Rel(dir, p)
			shipped = append(shipped, rel)
		}
		return nil
	})
	if len(shipped) != 1 || !strings.Contains(string(text), shipped[0]) {
		t.Fatalf("media %v, text %q", shipped, text)
	}
	// json -> yaml reserves no media folder
	if _, err := os.Stat(filepath.Join(dir, "src_media")); err == nil {
		t.Fatal("unexpected media folder")
	}
}
