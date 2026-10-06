package extras

import (
	"context"
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
	RegisterPost("testhook", func(arg string) error { mu.Lock(); hooked = append(hooked, arg); mu.Unlock(); return nil })
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

func TestQueueCancel(t *testing.T) {
	f := &fakeRunner{started: make(chan string, 4), steps: map[string]fakeStep{"slow": {block: true}}}
	q, r := newTestQueue(t, f)
	q.Enqueue([]Job{job("s", KindShell, "slow"), job("n", KindNpm, "npm", "n"), job("m", KindNpm, "npm", "m")})
	<-f.started
	q.Cancel("n") // queued
	q.Cancel("s") // running
	q.Wait()
	fin := r.final()
	if fin["s"].State != JobCancelled || fin["n"].State != JobCancelled || fin["m"].State != JobDone {
		t.Errorf("final = %+v", fin)
	}
	if strings.Join(f.calls, "|") != "slow|npm m" {
		t.Errorf("calls = %v", f.calls)
	}
	if len(r.notifs) != 1 {
		t.Errorf("notifs = %v", r.notifs)
	}
}

func TestQueueAuthCancelledCancelsBatch(t *testing.T) {
	f := &fakeRunner{steps: map[string]fakeStep{"pkexec y sys install a b": {code: 126}}}
	q, r := newTestQueue(t, f)
	sys := job("sys", KindSystem, "pkexec", "y", "sys", "install", "a", "b")
	sys.Entries = []string{"a", "b"}
	q.Enqueue([]Job{sys, job("n", KindNpm, "npm", "n")})
	q.Enqueue([]Job{job("other", KindNpm, "npm", "o")})
	q.Wait()
	fin := r.final()
	if p := fin["sys"]; p.State != JobCancelled || p.Reason != ReasonAuthCancelled || len(p.Entries) != 2 {
		t.Errorf("sys = %+v", p)
	}
	if p := fin["n"]; p.State != JobCancelled || p.Reason != ReasonAuthCancelled {
		t.Errorf("n = %+v", p)
	}
	if fin["other"].State != JobDone {
		t.Errorf("other batch = %+v", fin["other"])
	}
	if strings.Join(f.calls, "|") != "pkexec y sys install a b|npm o" {
		t.Errorf("calls = %v", f.calls)
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
	if code == 0 || time.Since(start) > 5*time.Second {
		t.Errorf("cancel: code=%d after %v", code, time.Since(start))
	}
}
