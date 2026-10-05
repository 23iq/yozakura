package agents

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// recSink records adapter output; decide answers permission requests.
type recSink struct {
	mu      sync.Mutex
	events  []Event
	perms   []PermissionRequest
	agentID string
	exited  bool
	decide  func(PermissionRequest) string
}

func (r *recSink) Emit(ev Event) {
	r.mu.Lock()
	r.events = append(r.events, ev)
	r.mu.Unlock()
}

func (r *recSink) SetAgentSessionID(id string) {
	r.mu.Lock()
	r.agentID = id
	r.mu.Unlock()
}

func (r *recSink) Permission(req PermissionRequest, reply func(string)) {
	r.mu.Lock()
	r.perms = append(r.perms, req)
	d := DecisionAllow
	if r.decide != nil {
		d = r.decide(req)
	}
	r.mu.Unlock()
	reply(d)
}

func (r *recSink) Exited(error, string) {
	r.mu.Lock()
	r.exited = true
	r.mu.Unlock()
}

func (r *recSink) snapshot() ([]Event, []PermissionRequest, string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]Event(nil), r.events...), append([]PermissionRequest(nil), r.perms...), r.agentID
}

func (r *recSink) count(kind string) int {
	evs, _, _ := r.snapshot()
	n := 0
	for _, e := range evs {
		if e.Kind == kind {
			n++
		}
	}
	return n
}

func (r *recSink) find(kind string, pred func(Event) bool) *Event {
	evs, _, _ := r.snapshot()
	for i := range evs {
		if evs[i].Kind == kind && (pred == nil || pred(evs[i])) {
			return &evs[i]
		}
	}
	return nil
}

func (r *recSink) text(kind string) string {
	evs, _, _ := r.snapshot()
	var sb strings.Builder
	for _, e := range evs {
		if e.Kind == kind {
			sb.WriteString(e.Text)
		}
	}
	return sb.String()
}

func waitFor(t *testing.T, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

type fake struct {
	dir      string
	stdinLog string
	argsLog  string
	env      []string
	bin      string
}

func newFake(t *testing.T, fixture string) *fake {
	t.Helper()
	dir := t.TempDir()
	bin, err := filepath.Abs("testdata/fakecli.sh")
	if err != nil {
		t.Fatal(err)
	}
	fx, _ := filepath.Abs(filepath.Join("testdata", fixture))
	f := &fake{dir: dir, stdinLog: filepath.Join(dir, "stdin.log"), argsLog: filepath.Join(dir, "args.log"), bin: bin}
	f.env = []string{"FAKECLI_FIXTURE=" + fx, "FAKECLI_STDIN_LOG=" + f.stdinLog, "FAKECLI_ARGS_LOG=" + f.argsLog}
	return f
}

func (f *fake) stdin() string { b, _ := os.ReadFile(f.stdinLog); return string(b) }
func (f *fake) args() []string {
	b, _ := os.ReadFile(f.argsLog)
	return strings.Split(strings.TrimSuffix(string(b), "\n"), "\n")
}

// startFake runs adapter id against a fixture.
func startFake(t *testing.T, id, fixture string, opts StartOptions, sink *recSink) (Conn, *fake) {
	t.Helper()
	f := newFake(t, fixture)
	opts.Binary = f.bin
	opts.Env = append(opts.Env, f.env...)
	if opts.Cwd == "" {
		opts.Cwd = f.dir
	}
	c, err := Lookup(id).Start(context.Background(), opts, sink)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = c.Close() })
	return c, f
}

func writeFile(path, content string) error { return os.WriteFile(path, []byte(content), 0o644) }
