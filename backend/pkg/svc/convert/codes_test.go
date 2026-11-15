package convert

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"sync"
	"testing"

	conv "yozakura/backend/pkg/convert"
	"yozakura/backend/pkg/ipc"
	"yozakura/backend/pkg/proc"
	notifysvc "yozakura/backend/pkg/svc/notify"
)

func codeOf(t *testing.T, err error) (string, []string) {
	t.Helper()
	var c ipc.CodedError
	if !errors.As(err, &c) {
		t.Fatalf("uncoded error %v", err)
	}
	return c.ErrorCode(), c.ErrorArgs()
}

// Jobs, probes and calls name their cause with a stable code.
func TestJobAndCallCodes(t *testing.T) {
	s, _ := newTest(t, &fakeClip{})
	dir := t.TempDir()
	flac := filepath.Join(dir, "a.flac")
	_ = os.WriteFile(flac, []byte("fLaC\x00"), 0o644)
	_ = os.Mkdir(filepath.Join(dir, "sub"), 0o755)
	jobs, err := s.Start(StartParams{Items: []Item{
		{Path: filepath.Join(dir, "missing.json"), Target: "yaml"},
		{Path: jsonFile(t, dir, "a.json"), Target: "nope"},
		{Path: flac, Target: "mp3"},
	}})
	if err != nil {
		t.Fatal(err)
	}
	if jobs[0].Code != conv.CodeNotFound || jobs[1].Code != conv.CodeUnknownTarget || !reflect.DeepEqual(jobs[1].ErrorArgs, []string{"nope"}) {
		t.Fatalf("%+v", jobs)
	}
	for _, j := range waitDone(t, s) {
		if j.ID == jobs[2].ID && (j.Code != conv.CodeToolMissing || !reflect.DeepEqual(j.ErrorArgs, []string{"MP3", "ffmpeg"})) {
			t.Fatalf("tool missing: %+v", j)
		}
	}
	if f := Probe(filepath.Join(dir, "sub"), conv.NewTools(nil, nil)); f.Code != conv.CodeFolder {
		t.Fatalf("probe %+v", f)
	}
	if f := Probe(filepath.Join(dir, "x"), conv.NewTools(nil, nil)); f.Code != conv.CodeNotFound {
		t.Fatalf("probe %+v", f)
	}
	_, err = s.start(json.RawMessage(`{"items":[{"path":"/a","target":"png"}],"outDir":"/no/such/dir"}`))
	if c, a := codeOf(t, err); c != conv.CodeOutDir || a[0] != "/no/such/dir" {
		t.Fatalf("out dir: %s %v", c, a)
	}
	_, err = s.cancel(json.RawMessage(`{"id":"c999"}`))
	if c, _ := codeOf(t, err); c != conv.CodeUnknownJob {
		t.Fatal(c)
	}
	if c, _ := codeOf(t, s.Copy(filepath.Join(dir, "gone.png"))); c != conv.CodeNotFound {
		t.Fatal(c)
	}
	// a cancelled job says so
	for i := 0; i < cap(s.sem); i++ {
		s.sem <- struct{}{}
	}
	queued, _ := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "b.json"), Target: "yaml"}}})
	_, _ = s.cancel(json.RawMessage(`{"id":"` + queued[0].ID + `"}`))
	for _, j := range waitDone(t, s) {
		if j.ID == queued[0].ID && (j.State != StateCancelled || j.Code != conv.CodeCancelled) {
			t.Fatalf("%+v", j)
		}
	}
	for i := 0; i < cap(s.sem); i++ {
		<-s.sem
	}
	s.Stop()
	if _, err := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "c.json"), Target: "yaml"}}}); err == nil {
		t.Fatal("started after Stop")
	} else if c, _ := codeOf(t, err); c != conv.CodeStopping {
		t.Fatal(c)
	}
}

// wl-paste missing and an empty clipboard are two causes; a clipboard
// without a file a third.
func TestClipboardCodes(t *testing.T) {
	_, missing := proc.RunWith(context.Background(), proc.Options{}, "wl-paste-not-installed-here")
	if _, err := clipboardTypes(nil, missing); err == nil {
		t.Fatal("no error")
	} else if c, _ := codeOf(t, err); c != conv.CodeClipboardUnavailable {
		t.Fatalf("missing wl-paste: %s (%v)", c, missing)
	}
	if _, err := clipboardTypes(nil, errors.New("exit status 1")); err == nil {
		t.Fatal("no error")
	} else if c, _ := codeOf(t, err); c != conv.CodeClipboardEmpty {
		t.Fatal(c)
	}
	if types, err := clipboardTypes([]byte("text/plain\nimage/png\n"), nil); err != nil || len(types) != 2 {
		t.Fatal(types, err)
	}
	s, _ := newTest(t, &fakeClip{types: []string{"text/html"}})
	if _, err := s.Paste(); err == nil {
		t.Fatal("pasted")
	} else if c, _ := codeOf(t, err); c != conv.CodeClipboardNoFile {
		t.Fatal(c)
	}
}

// A job finishing with no window subscribed is announced; one a window
// watches is not.
func TestUnwatchedJobsNotify(t *testing.T) {
	var mu sync.Mutex
	var got []notifysvc.SendParams
	s := New(Options{Detect: func() *conv.Tools { return conv.NewTools(nil, nil) }, CacheDir: t.TempDir(), Home: t.TempDir(),
		Clipboard: &fakeClip{}, Notify: func(p notifysvc.SendParams) { mu.Lock(); got = append(got, p); mu.Unlock() }})
	dir := t.TempDir()
	flac := filepath.Join(dir, "a.flac")
	_ = os.WriteFile(flac, []byte("fLaC\x00"), 0o644)
	if _, err := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "a.json"), Target: "yaml"}, {Path: flac, Target: "mp3"}}}); err != nil {
		t.Fatal(err)
	}
	waitDone(t, s)
	mu.Lock()
	if len(got) != 2 {
		t.Fatalf("notices %+v", got)
	}
	byKey := map[string]notifysvc.SendParams{}
	for _, p := range got {
		byKey[p.SummaryKey] = p
	}
	done, failed := byKey["notify.convert.done"], byKey["notify.convert.failed"]
	if done.BodyKey != "notify.convert.saved" || !reflect.DeepEqual(done.Args, []any{"a.json", "a.yaml"}) {
		t.Fatalf("done %+v", done)
	}
	reason, _ := failed.Args[1].(notifysvc.Text)
	if failed.Args[0] != "a.flac" || reason.Key != "converter.error.tool_missing" || !reflect.DeepEqual(reason.Args, []any{"MP3", "ffmpeg"}) ||
		reason.Text == "" {
		t.Fatalf("failed %+v", failed)
	}
	got = nil
	mu.Unlock()

	sub := ipc.NewSubscriber(256)
	s.subscribe(sub)
	defer sub.Stop()
	if _, err := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "b.json"), Target: "yaml"}}}); err != nil {
		t.Fatal(err)
	}
	waitDone(t, s)
	mu.Lock()
	defer mu.Unlock()
	if len(got) != 0 {
		t.Fatalf("a watched job notified: %+v", got)
	}
}

// A tool's own words keep their message and get no translation key.
func TestDetailNoticeIsShownAsIs(t *testing.T) {
	p := jobNotice(Job{ID: "c1", Name: "a.mp4", State: StateFailed, Error: "Invalid data found", Code: conv.CodeToolFailed})
	reason := p.Args[1].(notifysvc.Text)
	if reason.Key != "" || reason.Text != "Invalid data found" {
		t.Fatalf("%+v", reason)
	}
}
