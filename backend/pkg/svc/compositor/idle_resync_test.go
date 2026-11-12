package compositor

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"
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
