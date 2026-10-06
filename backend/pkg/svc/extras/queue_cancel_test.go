package extras

import (
	"errors"
	"strings"
	"testing"
)

func TestQueueCancel(t *testing.T) {
	f := &fakeRunner{started: make(chan string, 4), steps: map[string]fakeStep{"slow": {block: true}}}
	q, r := newTestQueue(t, f)
	q.Enqueue([]Job{job("s", KindShell, "slow"), job("n", KindNpm, "npm", "n"), job("m", KindNpm, "npm", "m")})
	<-f.started
	if err := q.Cancel("n"); err != nil { // queued
		t.Fatal(err)
	}
	if err := q.Cancel("s"); err != nil { // running shell job
		t.Fatal(err)
	}
	if err := q.Cancel("zzz"); err != ErrUnknownJob {
		t.Errorf("unknown: %v", err)
	}
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

func TestQueueRunningSystemNotCancellable(t *testing.T) {
	f := &fakeRunner{started: make(chan string, 4), steps: map[string]fakeStep{
		"pkexec y sys install a": {block: true}, "paru -S x": {block: true},
	}}
	q, r := newTestQueue(t, f)
	q.Enqueue([]Job{job("a", KindSystem, "pkexec", "y", "sys", "install", "a"), job("x", KindAUR, "paru", "-S", "x")})
	<-f.started
	if err := q.Cancel("x"); err != nil { // still queued: allowed
		t.Fatal(err)
	}
	if err := q.Cancel("a"); !errors.Is(err, ErrNotCancellable) {
		t.Fatalf("cancel running system job: %v", err)
	}
	if js := q.Jobs(); len(js) != 1 || js[0].Job != "a" || js[0].State != JobRunning {
		t.Errorf("jobs = %+v", js)
	}
	q.mu.Lock()
	q.current.cancel() // test-only: release the blocked fake
	q.mu.Unlock()
	q.Wait()
	if fin := r.final(); fin["x"].State != JobCancelled {
		t.Errorf("x = %+v", fin["x"])
	}
}

func TestQueueCancelledDepCancelsDependent(t *testing.T) {
	f := &fakeRunner{started: make(chan string, 4), steps: map[string]fakeStep{"slow": {block: true}}}
	q, r := newTestQueue(t, f)
	dep := job("dep", KindNpm, "npm", "dep")
	dep.Deps = []string{"base"}
	q.Enqueue([]Job{job("s", KindShell, "slow"), job("base", KindNpm, "npm", "base"), dep})
	<-f.started
	_ = q.Cancel("base")
	_ = q.Cancel("s")
	q.Wait()
	if p := r.final()["dep"]; p.State != JobCancelled || p.Reason != "" {
		t.Errorf("dep = %+v", p)
	}
	q.mu.Lock()
	n := len(q.outcome)
	q.mu.Unlock()
	if n != 0 {
		t.Errorf("outcomes not pruned: %d", n)
	}
}

func TestQueueAURDismissCancelsBatch(t *testing.T) {
	f := &fakeRunner{steps: map[string]fakeStep{"paru -S x": {
		lines: []string{"Error executing command as another user: Request dismissed", "error: failed to install packages"}, code: 1,
	}}}
	q, r := newTestQueue(t, f)
	q.Enqueue([]Job{job("x", KindAUR, "paru", "-S", "x"), job("n", KindNpm, "npm", "n")})
	q.Wait()
	fin := r.final()
	if fin["x"].State != JobCancelled || fin["x"].Reason != ReasonAuthCancelled || fin["n"].State != JobCancelled {
		t.Errorf("final = %+v", fin)
	}
	if len(r.notifs) != 0 {
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
