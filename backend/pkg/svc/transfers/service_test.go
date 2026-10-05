package transfers

import (
	"context"
	"encoding/json"
	"testing"
	"time"
)

type fakeSource struct {
	items   chan []Transfer
	actions chan string
}

func (f *fakeSource) Run(ctx context.Context, env *Env) {
	for {
		select {
		case <-ctx.Done():
			return
		case it := <-f.items:
			env.Update(it)
		}
	}
}

func (f *fakeSource) Action(key, action string) error {
	f.actions <- key + "/" + action
	return nil
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("condition not met")
}

func snapshot(s *Service) []Transfer {
	s.mu.Lock()
	defer s.mu.Unlock()
	list, _ := s.snapshotLocked()
	return list
}

func TestServiceRunsOnlyEnabledSourcesAndRoutesActions(t *testing.T) {
	fake := &fakeSource{items: make(chan []Transfer, 4), actions: make(chan string, 1)}
	register("fake", func() Source { return fake })
	s := NewService()
	defer s.Stop()

	s.Configure(map[string]bool{"fake": true, "missing": true}, Options{})
	it := Unknown()
	it.Key = "a"
	it.Title = "file.iso"
	fake.items <- []Transfer{it, {Key: ""}}
	waitFor(t, func() bool { return len(snapshot(s)) == 1 })
	got := snapshot(s)[0]
	if got.ID != "fake:a" || got.Source != "fake" || got.Actions == nil {
		t.Fatalf("unexpected item %+v", got)
	}

	raw, _ := json.Marshal(actionParams{ID: "fake:a", Action: ActionCancel})
	if _, err := s.action(raw); err != nil {
		t.Fatal(err)
	}
	if a := <-fake.actions; a != "a/cancel" {
		t.Fatalf("action routed as %q", a)
	}

	s.Configure(map[string]bool{"fake": false}, Options{})
	if n := len(snapshot(s)); n != 0 {
		t.Fatalf("disabled source still reports %d items", n)
	}
}

func TestFinishedItemsLingerThenDrop(t *testing.T) {
	fake := &fakeSource{items: make(chan []Transfer, 4)}
	register("fake2", func() Source { return fake })
	s := NewService()
	defer s.Stop()
	now := time.Unix(1000, 0)
	s.now = func() time.Time { return now }
	s.Configure(map[string]bool{"fake2": true}, Options{})
	it := Unknown()
	it.Key = "x"
	it.State = StateDone
	fake.items <- []Transfer{it}
	waitFor(t, func() bool { return len(snapshot(s)) == 1 })
	now = now.Add(lingerFinished + time.Second)
	if n := len(snapshot(s)); n != 0 {
		t.Fatalf("finished item should be gone, got %d", n)
	}
}

func TestOptionsHelpers(t *testing.T) {
	o := Options{Endpoints: map[string]string{"aria2": "http://h:1"}, Secrets: map[string]string{"aria2": "s"}}
	if o.Endpoint("aria2", "d") != "http://h:1" || o.Endpoint("x", "d") != "d" {
		t.Fatal("Endpoint")
	}
	if o.Secret("aria2", "") != "s" || o.Secret("x", "def") != "def" {
		t.Fatal("Secret")
	}
	if DownloadDir("/tmp/dl") != "/tmp/dl" {
		t.Fatal("DownloadDir override")
	}
}
