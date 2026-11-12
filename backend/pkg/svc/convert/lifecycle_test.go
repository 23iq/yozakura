package convert

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	conv "yozakura/backend/pkg/convert"
	"yozakura/backend/pkg/proc"
)

// A FIFO handed to probe or start never blocks the service.
func TestSpecialFilesNeverBlockTheService(t *testing.T) {
	s, _ := newTest(t, &fakeClip{})
	dir := t.TempDir()
	fifo := filepath.Join(dir, "pipe.json")
	if err := syscall.Mkfifo(fifo, 0o644); err != nil {
		t.Skip(err)
	}
	done := make(chan []Job, 1)
	go func() {
		if f := Probe(fifo, conv.NewTools(nil, nil)); f.Error != "not a regular file" {
			t.Errorf("probe: %+v", f)
		}
		jobs, _ := s.Start(StartParams{Items: []Item{{Path: fifo, Target: "yaml"}}})
		done <- jobs
	}()
	select {
	case jobs := <-done:
		if len(jobs) != 1 || jobs[0].State != StateFailed || jobs[0].Error != "not a regular file" {
			t.Fatalf("%+v", jobs)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("the service blocked on a FIFO")
	}
	// the lock is free: another call answers
	if len(s.Jobs()) != 1 {
		t.Fatal("jobs")
	}
}

func jsonFile(t *testing.T, dir, name string) string {
	t.Helper()
	p := filepath.Join(dir, name)
	_ = os.WriteFile(p, []byte(`{"a": 1}`), 0o644)
	return p
}

// A cancel sent right after start (before the job ran) is not lost.
func TestCancelBeforeTheJobRuns(t *testing.T) {
	s, _ := newTest(t, &fakeClip{})
	for i := 0; i < cap(s.sem); i++ {
		s.sem <- struct{}{} // every worker busy
	}
	src := jsonFile(t, t.TempDir(), "a.json")
	jobs, _ := s.Start(StartParams{Items: []Item{{Path: src, Target: "yaml"}}})
	if _, err := s.cancel(json.RawMessage(`{"id":"` + jobs[0].ID + `"}`)); err != nil {
		t.Fatal(err)
	}
	if j := waitDone(t, s)[0]; j.State != StateCancelled {
		t.Fatalf("%+v", j)
	}
}

// A cancel racing with the end of a job never reports "cancelled" while
// leaving a result on disk, nor "done" without one.
func TestLateCancelIsConsistent(t *testing.T) {
	s, _ := newTest(t, &fakeClip{})
	for i := 0; i < 30; i++ {
		dir := t.TempDir()
		src := jsonFile(t, dir, "a.json")
		jobs, _ := s.Start(StartParams{Items: []Item{{Path: src, Target: "yaml"}}})
		time.Sleep(time.Duration(i%5) * 200 * time.Microsecond)
		_, _ = s.cancel(json.RawMessage(`{"id":"` + jobs[0].ID + `"}`))
		var j Job
		for _, x := range waitDone(t, s) {
			if x.ID == jobs[0].ID {
				j = x
			}
		}
		_, err := os.Stat(filepath.Join(dir, "a.yaml"))
		switch j.State {
		case StateDone:
			if err != nil || j.Output == "" {
				t.Fatalf("done without a result: %+v", j)
			}
		case StateCancelled:
			if err == nil {
				t.Fatalf("cancelled but a.yaml was written")
			}
		default:
			t.Fatalf("%+v", j)
		}
	}
}

// Stop cancels and waits; later starts are refused; work dirs live under
// the cache (nothing in the user's folder), stale ones are swept.
func TestStopAndWorkDirs(t *testing.T) {
	cache := t.TempDir()
	stale := filepath.Join(cache, "work", "999999-abc")
	_ = os.MkdirAll(stale, 0o700)
	staleProfile := filepath.Join(cache, "office-profile-999999")
	_ = os.MkdirAll(staleProfile, 0o700)
	s := New(Options{Detect: func() *conv.Tools { return conv.NewTools(nil, nil) }, CacheDir: cache, Home: t.TempDir(), Clipboard: &fakeClip{}})
	for _, p := range []string{stale, staleProfile} {
		if _, err := os.Stat(p); err == nil {
			t.Fatalf("%s not swept", p)
		}
	}
	if !strings.Contains(s.officeProfile(), "office-profile-"+strconv.Itoa(os.Getpid())) {
		t.Fatalf("profile %s is not per process", s.officeProfile())
	}
	dir := t.TempDir()
	if _, err := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "a.json"), Target: "yaml"}}}); err != nil {
		t.Fatal(err)
	}
	waitDone(t, s)
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".") {
			t.Fatalf("work dir %s left in the user's folder", e.Name())
		}
	}
	for i := 0; i < cap(s.sem); i++ {
		s.sem <- struct{}{}
	}
	jobs, _ := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "b.json"), Target: "yaml"}}})
	start := time.Now()
	s.Stop()
	if time.Since(start) > 5*time.Second {
		t.Fatal("Stop did not cancel the waiting job")
	}
	for _, j := range s.Jobs() {
		if j.ID == jobs[0].ID && j.State != StateCancelled {
			t.Fatalf("%+v", j)
		}
	}
	if _, err := s.Start(StartParams{Items: []Item{{Path: jsonFile(t, dir, "c.json"), Target: "yaml"}}}); err == nil {
		t.Fatal("start after Stop accepted")
	}
}

// Two processes converting with LibreOffice at once (the daemon and a
// `convert` CLI) used one profile and one of them failed.
func TestTwoProcessesConvertWithLibreOffice(t *testing.T) {
	if os.Getenv("CONVERT_HELPER_SRC") != "" {
		return // the helper branch runs in TestMain-less mode below
	}
	tools := conv.DetectTools(nil)
	if !tools.Has(conv.EngineSoffice) {
		t.Skip("LibreOffice not installed")
	}
	cache := t.TempDir()
	var wg sync.WaitGroup
	errs := make([]string, 2)
	for i := 0; i < 2; i++ {
		dir := t.TempDir()
		src := filepath.Join(dir, "doc.txt")
		_ = os.WriteFile(src, []byte("hello "+strconv.Itoa(i)+"\n"), 0o644)
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			cmd := proc.Command(context.Background(), os.Args[0], "-test.run=TestConvertHelperProcess", "-test.count=1")
			cmd.Env = append(os.Environ(), "CONVERT_HELPER_SRC="+src, "CONVERT_HELPER_CACHE="+cache)
			out, err := cmd.CombinedOutput()
			if err != nil {
				errs[i] = string(out)
			}
		}(i)
	}
	wg.Wait()
	for i, e := range errs {
		if e != "" {
			t.Errorf("process %d: %s", i, e)
		}
	}
}

// TestConvertHelperProcess is one converting process of the test above.
func TestConvertHelperProcess(t *testing.T) {
	src := os.Getenv("CONVERT_HELPER_SRC")
	if src == "" {
		t.Skip("helper")
	}
	s := New(Options{Detect: func() *conv.Tools { return conv.DetectTools(nil) }, CacheDir: os.Getenv("CONVERT_HELPER_CACHE"), Home: t.TempDir()})
	defer s.Stop()
	if _, err := s.Start(StartParams{Items: []Item{{Path: src, Target: "pdf"}}}); err != nil {
		t.Fatal(err)
	}
	j := waitDoneFor(t, s, 3*time.Minute)[0]
	if j.State != StateDone {
		t.Fatalf("%+v", j)
	}
}

func waitDoneFor(t *testing.T, s *Service, d time.Duration) []Job {
	t.Helper()
	deadline := time.Now().Add(d)
	for time.Now().Before(deadline) {
		busy := false
		for _, j := range s.Jobs() {
			busy = busy || !j.finished()
		}
		if !busy {
			return s.Jobs()
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatal("timeout")
	return nil
}

