package svc

import (
	"encoding/json"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
)

func uiParams(t *testing.T, m map[string]any) RawParams {
	t.Helper()
	b, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func waitSubs(t *testing.T, u *UIService, n int) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for u.Subscribers() != n {
		if time.Now().After(deadline) {
			t.Fatalf("subscribers = %d, want %d", u.Subscribers(), n)
		}
		time.Sleep(time.Millisecond)
	}
}

func nextEvent(t *testing.T, sub *ipc.Subscriber) ipc.ServiceEvent {
	t.Helper()
	select {
	case ev := <-sub.Events:
		return ev
	case <-time.After(2 * time.Second):
		t.Fatal("no event")
	}
	return ipc.ServiceEvent{}
}

// Commands sent while no shell listens (startup, restart after a crash)
// reach the next shell; stale ones are dropped.
func TestUIQueuesUntilAShellSubscribes(t *testing.T) {
	u := NewUIService()
	now := time.Unix(1000, 0)
	u.now = func() time.Time { return now }

	if res, _ := u.run(uiParams(t, map[string]any{"command": "old"})); res != UIQueued {
		t.Fatalf("result %v, want queued", res)
	}
	now = now.Add(UIPendingTTL + time.Second)
	if res, _ := u.toggle(uiParams(t, map[string]any{"command": "bar"})); res != UIQueued {
		t.Fatalf("result %v, want queued", res)
	}

	sub := ipc.NewSubscriber(8)
	go u.subscribe(sub)
	waitSubs(t, u, 1)
	if ev := nextEvent(t, sub); ev.Service != "ui.toggle" || ev.Data != "bar" {
		t.Fatalf("got %+v, want the fresh toggle only", ev)
	}
	if len(sub.Events) != 0 {
		t.Fatalf("stale command delivered")
	}

	if res, _ := u.run(uiParams(t, map[string]any{"command": "launcher"})); res != UIDelivered {
		t.Fatalf("result %v, want delivered", res)
	}
	if ev := nextEvent(t, sub); ev.Data != "launcher" {
		t.Fatalf("got %+v", ev)
	}
}

// A shell that went away no longer counts; noQueue reports it instead of
// queueing, so the CLI can act itself (opening the terminal directly).
func TestUIForgetsStoppedShellAndHonoursNoQueue(t *testing.T) {
	u := NewUIService()
	sub := ipc.NewSubscriber(8)
	go u.subscribe(sub)
	waitSubs(t, u, 1)
	sub.Stop()
	waitSubs(t, u, 0)

	res, err := u.run(uiParams(t, map[string]any{"command": "terminal", "noQueue": true}))
	if err != nil || res != UIUndelivered {
		t.Fatalf("result %v %v, want undelivered", res, err)
	}
	next := ipc.NewSubscriber(8)
	go u.subscribe(next)
	waitSubs(t, u, 1)
	if len(next.Events) != 0 {
		t.Fatalf("a noQueue command was queued")
	}
	next.Stop()
}
