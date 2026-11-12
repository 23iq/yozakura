package compositor

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
)

// A producer overflowing a subscriber's queue while its reader drains it
// concurrently must never block (it holds the hub lock and runs on the
// daemon stream's reader goroutine): the overflow drain is non-blocking.
func TestIdleHubOverflowWithConcurrentReader(t *testing.T) {
	for round := 0; round < 200; round++ {
		h := newIdleHub()
		ch, _, cancel := h.subscribe()
		for i := 1; i <= idleSubBuffer; i++ {
			h.change(json.RawMessage(fmt.Sprintf(`{"id":1,"is_idle":%t}`, i%2 == 0)))
		}
		stop := make(chan struct{})
		readerDone := make(chan struct{})
		go func() {
			defer close(readerDone)
			for {
				select {
				case <-ch:
				case <-stop:
					return
				}
			}
		}()
		done := make(chan struct{})
		go func() {
			defer close(done)
			for i := 0; i < 500; i++ {
				h.change(json.RawMessage(`{"id":1,"is_idle":true}`))
			}
		}()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			t.Fatalf("round %d: producer blocked while holding the hub lock", round)
		}
		close(stop)
		<-readerDone
		cancel()
	}
}

// Wire order on a new connection to the same daemon can be [seq 6,
// State.Dump, seq 5] (the daemon writes each broadcast in its own
// goroutine): the dump must not reset the seq bookkeeping, or the stale
// seq 5 would be accepted.
func TestIdleHubDropsStaleFlipAcrossDump(t *testing.T) {
	m := NewManager(tomlPath(t.TempDir() + "/d.toml"))
	ch, _, cancel := m.SubscribeIdle()
	defer cancel()
	m.readSubscribe(strings.NewReader(dumpWithIdleEvents + "\n" + idleLine(1, 4, true)))
	wantStatus(t, ch, true, true, 1)
	wantChange(t, ch, 1, true)
	m.idle.streamDown()
	wantStatus(t, ch, false, false, 1)

	m.readSubscribe(strings.NewReader(strings.Join([]string{
		idleLine(1, 6, false),
		dumpWithIdleEvents,
		idleLine(1, 5, true), // older than seq 6: dropped
	}, "\n")))
	wantChange(t, ch, 1, false)
	wantStatus(t, ch, true, true, 2)
	noUpdate(t, ch)
}

// A restarted daemon numbers flips from 1 again; its stream always follows
// the end of the old one, so its first flips are accepted, even ahead of
// its State.Dump.
func TestIdleHubAcceptsRestartedDaemonSeq(t *testing.T) {
	m := NewManager(tomlPath(t.TempDir() + "/d.toml"))
	ch, _, cancel := m.SubscribeIdle()
	defer cancel()
	m.readSubscribe(strings.NewReader(dumpWithIdleEvents + "\n" + idleLine(3, 10, true)))
	wantStatus(t, ch, true, true, 1)
	wantChange(t, ch, 3, true)
	m.idle.streamDown()
	wantStatus(t, ch, false, false, 1)

	m.readSubscribe(strings.NewReader(idleLine(3, 1, false) + "\n" + dumpWithIdleEvents + "\n" + idleLine(3, 2, true)))
	wantChange(t, ch, 3, false)
	wantStatus(t, ch, true, true, 2)
	wantChange(t, ch, 3, true)
	noUpdate(t, ch)
}

// newTestForwarder returns a forwarder on a connected hub (epoch 1) whose
// IPC subscriber buffer holds one event and is full.
func newTestForwarder(t *testing.T) *idleForwarder {
	t.Helper()
	h := newIdleHub()
	ch, _, cancel := h.subscribe()
	t.Cleanup(cancel)
	h.streamUp([]string{"idle_events"})
	f := &idleForwarder{hub: h, ch: ch, sub: ipc.NewSubscriber(1)}
	f.forward(<-ch) // the status fills the buffer
	if len(f.sub.Events) != 1 || f.resync {
		t.Fatalf("setup: buffer %d, resync %v", len(f.sub.Events), f.resync)
	}
	return f
}

func takeEvent(t *testing.T, sub *ipc.Subscriber) ipc.ServiceEvent {
	t.Helper()
	select {
	case ev := <-sub.Events:
		return ev
	default:
		t.Fatal("no event queued")
	}
	return ipc.ServiceEvent{}
}

// An idlemon.changed the IPC subscriber's full buffer drops is not lost
// silently: the next message delivered is a status with a new epoch (the
// shell re-reads its monitor), and later flips flow again after it.
func TestIdleForwarderResyncsAfterDroppedPush(t *testing.T) {
	f := newTestForwarder(t)
	f.hub.change(json.RawMessage(`{"id":7,"is_idle":true,"seq":1}`))
	f.forward(<-f.ch) // dropped: the buffer is full
	if !f.resync {
		t.Fatal("a dropped push did not request a resync")
	}
	takeEvent(t, f.sub) // the connection writer catches up

	// The next flip is superseded by the resync status.
	f.hub.change(json.RawMessage(`{"id":7,"is_idle":false,"seq":2}`))
	f.forward(<-f.ch)
	ev := takeEvent(t, f.sub)
	if st, ok := ev.Data.(IdleStatus); ev.Service != "idlemon.status" || !ok || st != (IdleStatus{Connected: true, Events: true, Epoch: 2}) {
		t.Fatalf("after a drop got %+v, want a status with epoch 2", ev)
	}
	if f.resync || len(f.sub.Events) != 0 {
		t.Fatalf("resync %v, %d events queued after the resync status", f.resync, len(f.sub.Events))
	}

	f.hub.change(json.RawMessage(`{"id":7,"is_idle":true,"seq":3}`))
	f.forward(<-f.ch)
	if ev := takeEvent(t, f.sub); ev.Service != "idlemon.changed" || ev.Data.(IdleChange) != (IdleChange{ID: 7, IsIdle: true}) {
		t.Fatalf("after the resync got %+v, want the next flip", ev)
	}
}

// A refused resync status stays pending; the retry delivers it once the
// buffer has room, dropping the older updates still queued on the hub.
func TestIdleForwarderRetriesResync(t *testing.T) {
	f := newTestForwarder(t)
	f.hub.change(json.RawMessage(`{"id":7,"is_idle":true,"seq":1}`))
	f.forward(<-f.ch) // dropped
	f.sendResync()    // still full: stays pending
	if !f.resync {
		t.Fatal("a refused resync status was considered delivered")
	}
	f.hub.change(json.RawMessage(`{"id":7,"is_idle":false,"seq":2}`)) // queued on the hub
	takeEvent(t, f.sub)
	f.sendResync()
	ev := takeEvent(t, f.sub)
	if st, ok := ev.Data.(IdleStatus); ev.Service != "idlemon.status" || !ok || st.Epoch != 3 {
		t.Fatalf("retry delivered %+v, want a status with a new epoch", ev)
	}
	if f.resync || len(f.ch) != 0 {
		t.Fatalf("resync %v, %d updates left on the hub", f.resync, len(f.ch))
	}
}

// The forwarding goroutine retries a pending resync on its own when no
// further update comes.
func TestIdleForwarderRunRetriesWithoutUpdates(t *testing.T) {
	f := newTestForwarder(t)
	f.hub.change(json.RawMessage(`{"id":7,"is_idle":true,"seq":1}`))
	f.forward(<-f.ch) // dropped
	takeEvent(t, f.sub)
	go f.run(func() {})
	defer f.sub.Stop()
	select {
	case ev := <-f.sub.Events:
		if st, ok := ev.Data.(IdleStatus); ev.Service != "idlemon.status" || !ok || st.Epoch != 2 {
			t.Fatalf("retry delivered %+v, want a status with epoch 2", ev)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("pending resync was never retried")
	}
}
