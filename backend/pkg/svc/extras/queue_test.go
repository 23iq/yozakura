package extras

import (
	"context"
	"fmt"
	"os"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakeStep struct {
	lines []string
	code  int
	block bool // wait for cancel
}

type fakeRunner struct {
	mu      sync.Mutex
	steps   map[string]fakeStep // keyed by argv joined with " "
	calls   []string
	running int
	maxPar  int
	started chan string
}

func (f *fakeRunner) Run(ctx context.Context, argv, env []string, line func(string)) (int, error) {
	key := strings.Join(argv, " ")
	f.mu.Lock()
	f.calls = append(f.calls, key)
	f.running++
	f.maxPar = max(f.maxPar, f.running)
	st := f.steps[key]
	f.mu.Unlock()
	defer func() { f.mu.Lock(); f.running--; f.mu.Unlock() }()
	if f.started != nil {
		f.started <- key
	}
	for _, l := range st.lines {
		line(l)
	}
	if st.block {
		<-ctx.Done()
		return -1, nil
	}
	time.Sleep(time.Millisecond)
	return st.code, nil
}

type recorder struct {
	mu     sync.Mutex
	prog   []Progress
	notifs []string
}

func (r *recorder) emit(p Progress) { r.mu.Lock(); r.prog = append(r.prog, p); r.mu.Unlock() }
func (r *recorder) notify(title, body string) {
	r.mu.Lock()
	r.notifs = append(r.notifs, title)
	r.mu.Unlock()
}

// final returns the last emitted progress of each job.
func (r *recorder) final() map[string]Progress {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := map[string]Progress{}
	for _, p := range r.prog {
		out[p.Job] = p
	}
	return out
}

func newTestQueue(t *testing.T, f *fakeRunner) (*Queue, *recorder) {
	r := &recorder{}
	q := NewQueue(f, r.emit, r.notify)
	q.logDir = t.TempDir()
	return q, r
}

func registerTestPost(t *testing.T, prefix string, fn PostHook) {
	RegisterPost(prefix, fn)
	t.Cleanup(func() {
		postMu.Lock()
		delete(postHooks, prefix)
		postMu.Unlock()
	})
}

func job(id string, k JobKind, argv ...string) Job {
	return Job{ID: id, Kind: k, Entries: []string{id}, Names: []string{strings.ToUpper(id)}, Argv: argv}
}

func TestQueueSerialAndPost(t *testing.T) {
	f := &fakeRunner{steps: map[string]fakeStep{
		"pkexec y sys install a": {lines: []string{"(1/2) installing a", "(2/2) installing a-lib"}},
	}}
	q, r := newTestQueue(t, f)
	var mu sync.Mutex
	var hooked, after []string
	registerTestPost(t, "testhook", func(arg string) error { mu.Lock(); hooked = append(hooked, arg); mu.Unlock(); return nil })
	q.SetPostActions(func(id string) []string {
		if id == "a" {
			return []string{"testhook:a-app", "unknown:x"}
		}
		return nil
	})
	q.SetAfterJob(func(j Job, ok bool) { mu.Lock(); after = append(after, j.ID); mu.Unlock() })
	q.Enqueue([]Job{job("a", KindSystem, "pkexec", "y", "sys", "install", "a"), job("b", KindNpm, "npm", "b")})
	q.Enqueue([]Job{job("c", KindNpm, "npm", "c")})
	q.Wait()

	if got := strings.Join(f.calls, "|"); got != "pkexec y sys install a|npm b|npm c" {
		t.Errorf("calls = %s", got)
	}
	if f.maxPar != 1 {
		t.Errorf("parallel runs = %d", f.maxPar)
	}
	fin := r.final()
	for _, id := range []string{"a", "b", "c"} {
		if fin[id].State != JobDone || fin[id].Percent != 100 {
			t.Errorf("%s final = %+v", id, fin[id])
		}
	}
	if strings.Join(hooked, ",") != "a-app" || strings.Join(after, ",") != "a,b,c" {
		t.Errorf("hooked = %v after = %v", hooked, after)
	}
	if len(r.notifs) != 3 || r.notifs[0] != "A installed" {
		t.Errorf("notifs = %v", r.notifs)
	}
	sawHalf := false
	for _, p := range r.prog {
		sawHalf = sawHalf || (p.Job == "a" && p.Percent == 50 && p.Phase == "installing a")
	}
	if !sawHalf {
		t.Error("no running progress emitted")
	}
	data, err := os.ReadFile(fin["a"].Log)
	if err != nil || !strings.Contains(string(data), "installing a-lib") {
		t.Errorf("log = %q, %v", data, err)
	}
}

func TestQueueFailureReasons(t *testing.T) {
	f := &fakeRunner{steps: map[string]fakeStep{
		"pkexec y sys install st": {lines: []string{"error: target not found: lib32-foo"}, code: 1},
		"flatpak remote-add":      {lines: []string{"error: Could not resolve host: dl.flathub.org"}, code: 1},
	}}
	q, r := newTestQueue(t, f)
	sys := job("st", KindSystem, "pkexec", "y", "sys", "install", "st")
	dep := job("dep", KindNpm, "npm", "dep")
	dep.Deps = []string{"st"}
	fp := job("fp", KindFlatpak, "flatpak", "install")
	fp.Pre = [][]string{{"flatpak", "remote-add"}}
	q.Enqueue([]Job{sys, dep, fp})
	q.Wait()
	fin := r.final()
	if p := fin["st"]; p.State != JobFailed || p.Reason != ReasonNeedsSync {
		t.Errorf("st = %+v", p)
	}
	if p := fin["dep"]; p.State != JobFailed || p.Reason != ReasonDependency {
		t.Errorf("dep = %+v", p)
	}
	if p := fin["fp"]; p.State != JobFailed || p.Reason != ReasonNetwork {
		t.Errorf("fp = %+v", p)
	}
	if strings.Join(f.calls, "|") != "pkexec y sys install st|flatpak remote-add" {
		t.Errorf("calls = %v", f.calls)
	}
	if len(r.notifs) != 3 || r.notifs[0] != "Installing ST failed" {
		t.Errorf("notifs = %v", r.notifs)
	}
}

func TestQueueScriptDownload(t *testing.T) {
	f := &fakeRunner{}
	q, r := newTestQueue(t, f)
	tmp := t.TempDir() + "/inst.sh"
	if err := os.WriteFile(tmp, []byte("echo hi"), 0o600); err != nil {
		t.Fatal(err)
	}
	q.fetch = func(ctx context.Context, url string) (string, error) { return tmp, nil }
	j := job("cli", KindScript, "bash", ScriptFile, "-d", "/x")
	j.ScriptURL = "https://claude.ai/install.sh"
	q.Enqueue([]Job{j})
	q.Wait()
	if len(f.calls) != 1 || f.calls[0] != "bash "+tmp+" -d /x" {
		t.Errorf("calls = %v", f.calls)
	}
	if _, err := os.Stat(tmp); !os.IsNotExist(err) {
		t.Error("downloaded script not removed")
	}
	if r.final()["cli"].State != JobDone {
		t.Errorf("final = %+v", r.final())
	}
}

func TestExecRunnerLinesAndExit(t *testing.T) {
	var got []string
	code, err := ExecRunner{}.Run(context.Background(), []string{"printf", `a\rb\nc`}, nil, func(l string) { got = append(got, l) })
	if err != nil || code != 0 || strings.Join(got, ",") != "a,b,c" {
		t.Errorf("code=%d err=%v lines=%v", code, err, got)
	}
	code, err = ExecRunner{}.Run(context.Background(), []string{"false"}, nil, func(string) {})
	if err != nil || code != 1 {
		t.Errorf("false: %d %v", code, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	go func() { time.Sleep(50 * time.Millisecond); cancel() }()
	start := time.Now()
	code, _ = ExecRunner{}.Run(ctx, []string{"sleep", "30"}, nil, func(string) {})
	if code != 128+15 || time.Since(start) > 5*time.Second {
		t.Errorf("cancel: code=%d after %v", code, time.Since(start))
	}
}

func TestQueueEventOrder(t *testing.T) {
	f := &fakeRunner{started: make(chan string, 8), steps: map[string]fakeStep{"slow": {block: true}}}
	q, r := newTestQueue(t, f)
	q.Enqueue([]Job{job("s", KindShell, "slow")})
	<-f.started
	q.Enqueue([]Job{job("b1", KindNpm, "npm", "b1"), job("b2", KindNpm, "npm", "b2")})
	_ = q.Cancel("s")
	q.Wait()
	first := map[string]string{}
	r.mu.Lock()
	for _, p := range r.prog {
		if _, ok := first[p.Job]; !ok {
			first[p.Job] = p.State
		}
	}
	r.mu.Unlock()
	for id, p := range r.final() {
		if first[id] != JobQueued {
			t.Errorf("%s first event %q", id, first[id])
		}
		if p.State != JobDone && p.State != JobCancelled {
			t.Errorf("%s last event %q", id, p.State)
		}
	}
}

func TestQueueConcurrentEnqueueSerial(t *testing.T) {
	f := &fakeRunner{}
	q, r := newTestQueue(t, f)
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			id := fmt.Sprintf("j%d", i)
			q.Enqueue([]Job{job(id+"a", KindNpm, "npm", id+"a"), job(id+"b", KindNpm, "npm", id+"b")})
		}(i)
	}
	wg.Wait()
	q.Wait()
	if f.maxPar != 1 || len(f.calls) != 16 {
		t.Errorf("maxPar=%d calls=%d", f.maxPar, len(f.calls))
	}
	pos := map[string]int{}
	for i, c := range f.calls {
		pos[strings.TrimPrefix(c, "npm ")] = i
	}
	for i := 0; i < 8; i++ {
		if a, b := pos[fmt.Sprintf("j%da", i)], pos[fmt.Sprintf("j%db", i)]; a > b {
			t.Errorf("batch %d out of order", i)
		}
	}
	if len(r.final()) != 16 {
		t.Errorf("final = %d", len(r.final()))
	}
}

func TestQueuePacmanPipedPercent(t *testing.T) {
	var lines []string
	for _, c := range pacmanPiped {
		lines = append(lines, c.line)
	}
	f := &fakeRunner{steps: map[string]fakeStep{"pkexec y sys install a": {lines: lines}}}
	q, r := newTestQueue(t, f)
	j := job("a", KindSystem, "pkexec", "y", "sys", "install", "a")
	j.Pkgs = []string{"firefox", "telegram-desktop"}
	q.Enqueue([]Job{j})
	q.Wait()
	var pcts []int
	r.mu.Lock()
	for _, p := range r.prog {
		if p.State == JobRunning {
			pcts = append(pcts, p.Percent)
		}
	}
	r.mu.Unlock()
	last := -1
	saw50 := false
	for _, p := range pcts {
		if p < last {
			t.Fatalf("percent went back: %v", pcts)
		}
		last = p
		saw50 = saw50 || p == 50
	}
	if !saw50 {
		t.Errorf("percents = %v", pcts)
	}
}
