package convert

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	conv "yozakura/backend/pkg/convert"
)

type fakeClip struct {
	types   []string
	data    map[string][]byte
	written map[string][]byte
}

func (f *fakeClip) Types() ([]string, error) { return f.types, nil }
func (f *fakeClip) Read(m string) ([]byte, error) {
	return f.data[m], nil
}
func (f *fakeClip) Write(m string, d []byte) error {
	if f.written == nil {
		f.written = map[string][]byte{}
	}
	f.written[m] = d
	return nil
}

// native engines only: data formats and common images need no tool
func newTest(t *testing.T, clip Clipboard) (*Service, string) {
	t.Helper()
	home := t.TempDir()
	s := New(Options{
		Detect:    func() *conv.Tools { return conv.NewTools(nil, nil) },
		CacheDir:  filepath.Join(t.TempDir(), "convert"),
		Home:      home,
		Clipboard: clip,
	})
	return s, home
}

func waitDone(t *testing.T, s *Service) []Job {
	t.Helper()
	deadline := time.Now().Add(20 * time.Second)
	for time.Now().Before(deadline) {
		jobs := s.Jobs()
		done := true
		for _, j := range jobs {
			if !j.finished() {
				done = false
			}
		}
		if done {
			return jobs
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatal("jobs did not finish")
	return nil
}

func TestProbe(t *testing.T) {
	dir := t.TempDir()
	js := filepath.Join(dir, "a.json")
	_ = os.WriteFile(js, []byte(`{"a":1}`), 0o644)
	f := Probe(js, conv.NewTools(nil, nil))
	if f.Kind != conv.KindData || f.Format != "json" || f.Default != "yaml" || f.Size != 7 || len(f.Targets) == 0 {
		t.Fatalf("%+v", f)
	}
	if Probe(filepath.Join(dir, "missing.png"), nil).Error != "not found" || Probe(dir, nil).Error != "a folder" {
		t.Fatal("errors")
	}
	s, _ := newTest(t, &fakeClip{})
	raw, err := s.probe(json.RawMessage(`{"paths":["` + js + `"]}`))
	if err != nil || len(raw.(map[string]any)["files"].([]File)) != 1 {
		t.Fatalf("probe: %v", err)
	}
	if _, err := s.probe(json.RawMessage(`{}`)); err == nil {
		t.Fatal("empty probe")
	}
}

func TestStartConvertsNextToSourceWithoutOverwriting(t *testing.T) {
	s, _ := newTest(t, &fakeClip{})
	dir := t.TempDir()
	js := filepath.Join(dir, "cfg.json")
	_ = os.WriteFile(js, []byte(`{"b":1,"a":[1,2]}`), 0o644)
	_ = os.WriteFile(filepath.Join(dir, "cfg.yaml"), []byte("keep"), 0o644)
	jobs, err := s.Start(StartParams{Items: []Item{{Path: js, Target: "yaml"}, {Path: js, Target: "csv"}, {Path: js, Target: "nope"}}})
	if err != nil || len(jobs) != 3 || jobs[2].State != StateFailed {
		t.Fatalf("%v %+v", err, jobs)
	}
	done := waitDone(t, s)
	if done[0].State != StateDone || filepath.Base(done[0].Output) != "cfg (1).yaml" {
		t.Fatalf("yaml job: %+v", done[0])
	}
	if b, _ := os.ReadFile(done[0].Output); string(b) != "b: 1\na:\n  - 1\n  - 2\n" {
		t.Fatalf("yaml: %q", b)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "cfg.yaml")); string(b) != "keep" {
		t.Fatal("overwrote")
	}
	// a single object is one csv row: fine; an error is one short line
	if done[1].State != StateDone {
		t.Fatalf("csv: %+v", done[1])
	}
	// no work directories are left behind
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".") {
			t.Fatalf("left %s", e.Name())
		}
	}
	if _, err := s.clear(nil); err != nil || len(s.Jobs()) != 0 {
		t.Fatal("clear")
	}
}

func TestStartOutDirAndErrors(t *testing.T) {
	s, home := newTest(t, &fakeClip{})
	dir := t.TempDir()
	bad := filepath.Join(dir, "bad.json")
	_ = os.WriteFile(bad, []byte(`{"a":`), 0o644)
	out := filepath.Join(home, "out")
	_ = os.Mkdir(out, 0o755)
	if _, err := s.Start(StartParams{Items: []Item{{Path: bad, Target: "yaml"}}, OutDir: "~/out"}); err != nil {
		t.Fatal(err)
	}
	j := waitDone(t, s)[0]
	if j.State != StateFailed || j.Error != "not valid JSON" || j.Output != "" {
		t.Fatalf("%+v", j)
	}
	if _, err := s.Start(StartParams{Items: []Item{{Path: bad, Target: "yaml"}}, OutDir: "/nonexistent/dir"}); err == nil {
		t.Fatal("missing out dir accepted")
	}
	// a needed tool is missing: the job fails saying which
	flac := filepath.Join(dir, "a.flac")
	_ = os.WriteFile(flac, []byte("fLaC\x00\x00\x00"), 0o644)
	_, _ = s.Start(StartParams{Items: []Item{{Path: flac, Target: "mp3"}}})
	jobs := waitDone(t, s)
	if last := jobs[len(jobs)-1]; last.State != StateFailed || !strings.Contains(last.Error, "needs ffmpeg") {
		t.Fatalf("%+v", last)
	}
}

func TestCancelUnknown(t *testing.T) {
	s, _ := newTest(t, &fakeClip{})
	if _, err := s.cancel(json.RawMessage(`{"id":"c9"}`)); err == nil {
		t.Fatal("unknown job cancelled")
	}
}

func TestPaste(t *testing.T) {
	dir := t.TempDir()
	a := filepath.Join(dir, "a b.png")
	_ = os.WriteFile(a, []byte("x"), 0o644)
	clip := &fakeClip{types: []string{"text/uri-list", "text/plain"}, data: map[string][]byte{
		"text/uri-list": []byte("# comment\r\nfile://" + strings.ReplaceAll(a, " ", "%20") + "\r\nhttps://example.com/x\r\n")}}
	s, home := newTest(t, clip)
	paths, err := s.Paste()
	if err != nil || len(paths) != 1 || paths[0] != a {
		t.Fatalf("uri-list: %v %v", paths, err)
	}
	// image data: saved to a file, its results go to ~/Pictures
	png := "\x89PNG\r\n\x1a\nxxxx"
	clip.types = []string{"image/png"}
	clip.data = map[string][]byte{"image/png": []byte(png)}
	paths, err = s.Paste()
	if err != nil || len(paths) != 1 || !strings.HasSuffix(paths[0], ".png") {
		t.Fatalf("image: %v %v", paths, err)
	}
	_ = os.Mkdir(filepath.Join(home, "Pictures"), 0o755)
	if !s.isPasted(paths[0]) || s.pastedOutDir() != filepath.Join(home, "Pictures") {
		t.Fatal("pasted output dir")
	}
	// plain text paths
	clip.types = []string{"text/plain"}
	clip.data = map[string][]byte{"text/plain": []byte(a + "\n")}
	if paths, _ = s.Paste(); len(paths) != 1 || paths[0] != a {
		t.Fatalf("text paths: %v", paths)
	}
	clip.data = map[string][]byte{"text/plain": []byte("hello")}
	if _, err := s.Paste(); err == nil || err.Error() != "no file on the clipboard" {
		t.Fatalf("plain text: %v", err)
	}
}

func TestCopy(t *testing.T) {
	clip := &fakeClip{}
	s, _ := newTest(t, clip)
	dir := t.TempDir()
	png := filepath.Join(dir, "x.png")
	_ = os.WriteFile(png, []byte("\x89PNG\r\n\x1a\nxxxx"), 0o644)
	doc := filepath.Join(dir, "my doc.pdf")
	_ = os.WriteFile(doc, []byte("%PDF-1.4"), 0o644)
	if err := s.Copy(png); err != nil || string(clip.written["image/png"][:4]) != "\x89PNG" {
		t.Fatalf("png: %v", err)
	}
	if err := s.Copy(doc); err != nil || string(clip.written["text/uri-list"]) != "file://"+strings.ReplaceAll(doc, " ", "%20")+"\r\n" {
		t.Fatalf("pdf: %v %q", err, clip.written["text/uri-list"])
	}
	if s.Copy("relative.png") == nil || s.Copy(filepath.Join(dir, "none")) == nil {
		t.Fatal("bad paths copied")
	}
}
