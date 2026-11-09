package videoproxy

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

type fake struct {
	mu      sync.Mutex
	runs    [][]string
	fail    bool
	release chan struct{}
	results chan Result
}

func newTestManager(t *testing.T, f *fake, tools ...string) (*Manager, string) {
	t.Helper()
	dir := t.TempDir()
	m := New(context.Background(), filepath.Join(dir, "cache"))
	have := map[string]bool{}
	for _, tool := range tools {
		have[tool] = true
	}
	m.lookPath = func(name string) (string, error) {
		if have[name] {
			return "/bin/" + name, nil
		}
		return "", exec.ErrNotFound
	}
	m.probe = func(context.Context, string) ([]byte, error) {
		return []byte(`{"streams":[{"width":3840,"height":2160,"avg_frame_rate":"60/1"}]}`), nil
	}
	m.run = func(_ context.Context, name string, args ...string) error {
		f.mu.Lock()
		f.runs = append(f.runs, append([]string{name}, args...))
		f.mu.Unlock()
		if f.release != nil {
			<-f.release
		}
		if f.fail {
			return errors.New("boom")
		}
		return os.WriteFile(args[len(args)-1], []byte("mp4"), 0o644)
	}
	f.results = make(chan Result, 4)
	m.Notify = func(r Result) { f.results <- r }
	src := filepath.Join(dir, "wall.mp4")
	must(t, assert.NoError(t, os.WriteFile(src, []byte("video"), 0o644)))
	return m, src
}

func wait(t *testing.T, f *fake) Result {
	t.Helper()
	select {
	case r := <-f.results:
		return r
	case <-time.After(5 * time.Second):
		t.Fatal("no result")
		return Result{}
	}
}

func TestRequestTranscodesOnceThenServesTheCache(t *testing.T) {
	f := &fake{release: make(chan struct{})}
	m, src := newTestManager(t, f, "ffmpeg", "ffprobe", "nice")
	req := Request{Path: src, Width: 1920, Height: 1080}

	assert.Equal(t, StatePending, m.Request(req).State)
	assert.Equal(t, StatePending, m.Request(req).State, "a second request joins the running job")
	close(f.release)

	done := wait(t, f)
	assert.Equal(t, StateReady, done.State)
	assert.Equal(t, src, done.Source)
	assert.FileExists(t, done.Path)
	assert.NoFileExists(t, done.Path+".part")
	must(t, assert.Len(t, f.runs, 1, "one transcode"))
	assert.Equal(t, []string{"nice", "-n", "19", "ffmpeg"}, f.runs[0][:4], "runs at low priority")
	assert.Contains(t, f.runs[0], "scale=1920:1080:flags=lanczos,fps=30")

	again := m.Request(req)
	assert.Equal(t, StateReady, again.State)
	assert.Equal(t, done.Path, again.Path)

	// A changed source is a new proxy.
	later := time.Now().Add(time.Minute)
	must(t, assert.NoError(t, os.Chtimes(src, later, later)))
	f.release = nil
	assert.Equal(t, StatePending, m.Request(req).State)
	assert.NotEqual(t, done.Path, wait(t, f).Path)
}

func TestRequestPlaysTheOriginal(t *testing.T) {
	f := &fake{}
	m, src := newTestManager(t, f, "ffmpeg", "ffprobe")
	assert.Equal(t, StateOriginal, m.Request(Request{Path: "rel.mp4", Width: 1920, Height: 1080}).State, "relative path")
	assert.Equal(t, StateOriginal, m.Request(Request{Path: src}).State, "no screen size")
	assert.Equal(t, StateOriginal, m.Request(Request{Path: src + ".missing", Width: 1920, Height: 1080}).State)
	m.probe = func(context.Context, string) ([]byte, error) {
		return []byte(`{"streams":[{"width":1920,"height":1080,"avg_frame_rate":"30/1"}]}`), nil
	}
	assert.Equal(t, StateOriginal, m.Request(Request{Path: src, Width: 2560, Height: 1440}).State, "smaller than the screen")

	none, src2 := newTestManager(t, &fake{}, "ffmpeg")
	assert.Equal(t, StateOriginal, none.Request(Request{Path: src2, Width: 1920, Height: 1080}).State, "no ffprobe")
	assert.Empty(t, f.runs)
}

func TestFailedTranscodeIsNotRetried(t *testing.T) {
	f := &fake{fail: true}
	m, src := newTestManager(t, f, "ffmpeg", "ffprobe")
	req := Request{Path: src, Width: 1920, Height: 1080}
	assert.Equal(t, StatePending, m.Request(req).State)
	res := wait(t, f)
	assert.Equal(t, StateOriginal, res.State)
	assert.Empty(t, res.Path)
	assert.Equal(t, StateOriginal, m.Request(req).State)
	assert.Len(t, f.runs, 1)
	assert.Equal(t, "ffmpeg", f.runs[0][0], "no nice: ffmpeg directly")
	entries, _ := os.ReadDir(m.Dir)
	assert.Empty(t, entries, "no partial file left")
}

func TestPruneKeepsTheMostRecent(t *testing.T) {
	dir := t.TempDir()
	m := New(context.Background(), dir)
	base := time.Now().Add(-time.Hour)
	var paths []string
	for i := range Keep + 3 {
		p := filepath.Join(dir, string(rune('a'+i))+".mp4")
		must(t, assert.NoError(t, os.WriteFile(p, nil, 0o644)))
		ts := base.Add(time.Duration(i) * time.Minute)
		must(t, assert.NoError(t, os.Chtimes(p, ts, ts)))
		paths = append(paths, p)
	}
	must(t, assert.NoError(t, os.WriteFile(filepath.Join(dir, "note.txt"), nil, 0o644)))
	// The oldest is the one just made (clock skew): still kept.
	m.prune(paths[0])
	entries, _ := os.ReadDir(dir)
	assert.Len(t, entries, Keep+1, "Keep proxies + the non-mp4 file")
	assert.FileExists(t, paths[0])
	assert.FileExists(t, paths[len(paths)-1])
	assert.NoFileExists(t, paths[1])
}

func TestPartialFilesArePerProcessAndStaleOnesRemoved(t *testing.T) {
	f := &fake{}
	m, src := newTestManager(t, f, "ffmpeg", "ffprobe")
	must(t, assert.NoError(t, os.MkdirAll(m.Dir, 0o755)))
	stale := filepath.Join(m.Dir, "old.mp4.1.part")
	fresh := filepath.Join(m.Dir, "running.mp4.2.part")
	for _, p := range []string{stale, fresh} {
		must(t, assert.NoError(t, os.WriteFile(p, nil, 0o644)))
	}
	old := time.Now().Add(-2 * transcodeTimeout)
	must(t, assert.NoError(t, os.Chtimes(stale, old, old)))

	assert.Equal(t, StatePending, m.Request(Request{Path: src, Width: 1920, Height: 1080}).State)
	assert.Equal(t, StateReady, wait(t, f).State)
	must(t, assert.Len(t, f.runs, 1))
	out := f.runs[0][len(f.runs[0])-1]
	assert.True(t, strings.HasSuffix(out, fmt.Sprintf(".%d.part", os.Getpid())), out)
	assert.NoFileExists(t, stale, "left by a dead daemon")
	assert.FileExists(t, fresh, "may belong to a running encoder")
}

func TestRunTranscodeReportsStderr(t *testing.T) {
	err := runTranscode(context.Background(), "sh", "-c", "echo bad input >&2; exit 3")
	if assert.Error(t, err) {
		assert.Contains(t, err.Error(), "bad input")
	}
	assert.NoError(t, runTranscode(context.Background(), "true"))
}
