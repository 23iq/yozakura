package compositor

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/ipc"
)

const (
	dumpWithIdleEvents = `{"jsonrpc":"2.0","method":"State.Dump","state":{},"features":["idle_events"]}`
	dumpWithoutFeature = `{"jsonrpc":"2.0","method":"State.Dump","state":{}}`
)

func idleLine(id, seq int, idle bool) string {
	seqField := ""
	if seq > 0 {
		seqField = fmt.Sprintf(`,"seq":%d`, seq)
	}
	return fmt.Sprintf(`{"jsonrpc":"2.0","method":"Event.IdleMonitorChanged","params":{"id":%d,"is_idle":%t%s},"state":{}}`, id, idle, seqField)
}

func nextUpdate(t *testing.T, ch <-chan IdleUpdate) IdleUpdate {
	t.Helper()
	select {
	case u := <-ch:
		return u
	case <-time.After(2 * time.Second):
		t.Fatal("no idle update")
	}
	return IdleUpdate{}
}

func noUpdate(t *testing.T, ch <-chan IdleUpdate) {
	t.Helper()
	select {
	case u := <-ch:
		t.Fatalf("unexpected update %+v %+v", u.Status, u.Change)
	default:
	}
}

func wantChange(t *testing.T, ch <-chan IdleUpdate, id uint32, idle bool) {
	t.Helper()
	u := nextUpdate(t, ch)
	if u.Change == nil || u.Change.ID != id || u.Change.IsIdle != idle {
		t.Fatalf("update = %+v %+v, want change %d/%v", u.Status, u.Change, id, idle)
	}
}

func wantStatus(t *testing.T, ch <-chan IdleUpdate, connected, events bool, epoch uint64) {
	t.Helper()
	u := nextUpdate(t, ch)
	if u.Status == nil || *u.Status != (IdleStatus{Connected: connected, Events: events, Epoch: epoch}) {
		t.Fatalf("update = %+v %+v, want status %v/%v/%d", u.Status, u.Change, connected, events, epoch)
	}
}

// Both flips of a monitor are forwarded, every monitor's flips carry their
// own id, a stale (lower seq) flip is dropped, and the end of a stream
// resets the seq bookkeeping (a restarted daemon counts from 1 again); the
// next stream has a new epoch.
func TestIdleHubForwardsFlipsInSeqOrder(t *testing.T) {
	m := NewManager(tomlPath(t.TempDir() + "/d.toml"))
	ch, st, cancel := m.SubscribeIdle()
	defer cancel()
	if st != (IdleStatus{}) {
		t.Fatalf("initial status = %+v", st)
	}

	m.readSubscribe(strings.NewReader(strings.Join([]string{
		dumpWithIdleEvents,
		`{"id":1,"result":"subscribed"}`,
		idleLine(3, 1, true),
		idleLine(3, 3, false),
		idleLine(3, 2, true), // overtaken by seq 3: dropped
		idleLine(9, 4, true), // another monitor
	}, "\n")))
	wantStatus(t, ch, true, true, 1)
	wantChange(t, ch, 3, true)
	wantChange(t, ch, 3, false)
	wantChange(t, ch, 9, true)
	noUpdate(t, ch)

	m.idle.streamDown()
	wantStatus(t, ch, false, false, 1)
	m.idle.streamDown() // already down
	noUpdate(t, ch)

	m.readSubscribe(strings.NewReader(dumpWithIdleEvents + "\n" + idleLine(1, 1, true)))
	wantStatus(t, ch, true, true, 2)
	wantChange(t, ch, 1, true)
}

// A daemon that does not advertise idle events reports events=false (the
// shell keeps polling); flips it sends without seq go through in order.
func TestIdleHubOldDaemon(t *testing.T) {
	m := NewManager(tomlPath(t.TempDir() + "/d.toml"))
	ch, _, cancel := m.SubscribeIdle()
	defer cancel()
	m.readSubscribe(strings.NewReader(dumpWithoutFeature + "\n" + idleLine(2, 0, true) + "\n" + idleLine(2, 0, false) + "\n{garbage\n"))
	wantStatus(t, ch, true, false, 1)
	wantChange(t, ch, 2, true)
	wantChange(t, ch, 2, false)
	noUpdate(t, ch)
}

// A subscriber that stops reading loses its queue but gets a status with a
// new epoch, so the shell re-reads its monitor once instead of missing a flip.
func TestIdleHubOverflowBumpsEpoch(t *testing.T) {
	m := NewManager(tomlPath(t.TempDir() + "/d.toml"))
	ch, _, cancel := m.SubscribeIdle()
	defer cancel()
	m.readSubscribe(strings.NewReader(dumpWithIdleEvents))
	// The status fills one slot: flip number idleSubBuffer overflows, the
	// next one is queued after the resync status.
	for i := 1; i <= idleSubBuffer+1; i++ {
		m.readSubscribe(strings.NewReader(idleLine(1, i, i%2 == 1)))
	}
	wantStatus(t, ch, true, true, 2)
	wantChange(t, ch, 1, true)
	noUpdate(t, ch)
}

// The idlemon IPC subscription starts with the current status and then
// forwards the hub's updates; it ends with the subscriber.
func TestIdlemonSubscription(t *testing.T) {
	s := NewService(tomlPath(t.TempDir() + "/d.toml"))
	sub := ipc.NewSubscriber(16)
	s.subscribeIdle(sub)
	next := func() ipc.ServiceEvent {
		t.Helper()
		select {
		case ev := <-sub.Events:
			return ev
		case <-time.After(2 * time.Second):
			t.Fatal("no idlemon event")
		}
		return ipc.ServiceEvent{}
	}
	if ev := next(); ev.Service != "idlemon.status" || ev.Data.(IdleStatus) != (IdleStatus{}) {
		t.Fatalf("first event = %+v", ev)
	}
	s.mgr.readSubscribe(strings.NewReader(dumpWithIdleEvents + "\n" + idleLine(5, 1, true)))
	if ev := next(); ev.Service != "idlemon.status" || !ev.Data.(IdleStatus).Events {
		t.Fatalf("status event = %+v", ev)
	}
	if ev := next(); ev.Service != "idlemon.changed" || ev.Data.(IdleChange) != (IdleChange{ID: 5, IsIdle: true}) {
		t.Fatalf("change event = %+v", ev)
	}
	sub.Stop()
	waitFor(t, "idle subscription removed", func() bool {
		s.mgr.idle.mu.Lock()
		defer s.mgr.idle.mu.Unlock()
		return len(s.mgr.idle.subs) == 0
	})
}

// The live stream: connected on the daemon's State.Dump, disconnected when
// the daemon drops the connection, a new epoch once it is back.
func TestManagerIdleStatusFollowsStream(t *testing.T) {
	toml, ln := fakeDaemonSocket(t)
	m := NewManager(tomlPath(toml))
	ch, _, cancel := m.SubscribeIdle()
	defer cancel()
	if err := m.Start(); err != nil {
		t.Fatal(err)
	}
	defer m.Close()

	conn1, _ := acceptSubscriber(t, ln)
	if _, err := conn1.Write([]byte(dumpWithIdleEvents + "\n" + idleLine(1, 1, true) + "\n")); err != nil {
		t.Fatal(err)
	}
	wantStatus(t, ch, true, true, 1)
	wantChange(t, ch, 1, true)

	_ = conn1.Close()
	wantStatus(t, ch, false, false, 1)

	conn2, _ := acceptSubscriber(t, ln)
	defer conn2.Close()
	if _, err := conn2.Write([]byte(dumpWithIdleEvents + "\n")); err != nil {
		t.Fatal(err)
	}
	wantStatus(t, ch, true, true, 2)
}
